import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../io/output_naming.dart';
import '../model/batch_item.dart';
import '../model/output_options.dart';
import '../model/resize_target.dart';
import '../ops/encode_ops.dart';
import 'queue_controller.dart';
import 'target_controller.dart';

/// What the batch is doing.
enum BatchState { idle, running, cancelling, finished }

/// How the last run ended, for the status bar to report.
@immutable
class BatchSummary {
  const BatchSummary({
    this.written = 0,
    this.skipped = 0,
    this.failed = 0,
    this.missedBudget = 0,
    this.inputBytes = 0,
    this.outputBytes = 0,
    this.cancelled = false,
  });

  final int written;
  final int skipped;
  final int failed;

  /// Written, but larger than the budget asked for. Counted separately because
  /// it is neither a success worth ignoring nor a failure worth alarming about.
  final int missedBudget;

  final int inputBytes;
  final int outputBytes;
  final bool cancelled;

  int get total => written + skipped + failed;

  double? get savedFraction =>
      inputBytes <= 0 ? null : 1 - (outputBytes / inputBytes);
}

/// Runs the queue.
///
/// Each file is a separate [Isolate.run]: `package:image` is pure Dart, so the
/// encoding is genuine CPU work and doing it on the platform thread would lock
/// the window for the length of the batch. Several run at once, capped well
/// below the core count — the encoders allocate freely, and eight camera-sized
/// images decoded simultaneously is gigabytes.
class BatchController extends ChangeNotifier {
  BatchController({required this.queue, required this.target});

  /// Files in flight at once.
  ///
  /// Four is the point where wall-clock stops improving much on the machines
  /// this runs on, and it keeps peak memory to something a laptop survives.
  static int get concurrency {
    final cores = Platform.numberOfProcessors;
    return cores < 2 ? 1 : (cores > 4 ? 4 : cores);
  }

  final QueueController queue;
  final TargetController target;

  BatchState _state = BatchState.idle;
  BatchSummary _summary = const BatchSummary();
  int _completed = 0;
  int _total = 0;

  BatchState get state => _state;
  BatchSummary get summary => _summary;

  bool get isRunning =>
      _state == BatchState.running || _state == BatchState.cancelling;

  /// 0–1, or null when nothing is running.
  double? get progress =>
      _total == 0 || !isRunning ? null : _completed / _total;

  int get completed => _completed;
  int get total => _total;

  /// Starts the batch. Does nothing if one is already running.
  Future<void> start() async {
    if (isRunning) return;

    final items = queue.processable.toList();
    if (items.isEmpty) return;

    final resize = target.target;
    final options = target.output;
    // Every source in the queue, so an output can never land on one — see the
    // rule at the top of `OutputNaming`.
    final protected = queue.sourcePaths;

    _state = BatchState.running;
    _summary = const BatchSummary();
    _completed = 0;
    _total = items.length;
    notifyListeners();

    var written = 0;
    var skipped = 0;
    var failed = 0;
    var missedBudget = 0;
    var inputBytes = 0;
    var outputBytes = 0;

    // A simple sliding window rather than a pool: the work is uniform enough
    // that keeping N in flight is all the scheduling this needs.
    final active = <Future<void>>[];
    var next = 0;

    Future<void> startOne(BatchItem item) async {
      final index = queue.indexOf(item.path);
      if (index >= 0) {
        queue.replace(index, item.copyWith(status: BatchItemStatus.running));
      }

      final outcome = await _process(item, resize, options, protected);

      inputBytes += item.sourceBytes;
      switch (outcome.status) {
        case BatchItemStatus.done:
          written++;
          outputBytes += outcome.outputBytes ?? 0;
          if (!outcome.budgetMet) missedBudget++;
        case BatchItemStatus.skipped:
          skipped++;
          // A skipped file keeps its original, so it contributes its own size
          // to the total rather than looking like a saving nobody made.
          outputBytes += item.sourceBytes;
        default:
          failed++;
          outputBytes += item.sourceBytes;
      }

      final finalIndex = queue.indexOf(item.path);
      if (finalIndex >= 0) queue.replace(finalIndex, outcome);

      _completed++;
      notifyListeners();
    }

    while (next < items.length || active.isNotEmpty) {
      while (active.length < concurrency &&
          next < items.length &&
          _state == BatchState.running) {
        final future = startOne(items[next++]);
        active.add(future);
        // Removing itself is what keeps the window sliding rather than
        // draining to empty between groups.
        unawaited(future.whenComplete(() => active.remove(future)));
      }
      if (active.isEmpty) break;
      await Future.any(active);
      // `Future.any` completes on the first one, but `whenComplete` above runs
      // in a microtask; yielding lets the removal land before the next check.
      await Future<void>.delayed(Duration.zero);
    }

    _summary = BatchSummary(
      written: written,
      skipped: skipped,
      failed: failed,
      missedBudget: missedBudget,
      inputBytes: inputBytes,
      outputBytes: outputBytes,
      cancelled: _state == BatchState.cancelling,
    );
    _state = BatchState.finished;
    notifyListeners();
  }

  /// Asks the batch to stop after the files already in flight.
  ///
  /// An `Isolate.run` that is halfway through an encode cannot be killed
  /// without leaving a half-written file behind, so cancelling means "start no
  /// more", not "stop now". With four files in flight that is a second or two,
  /// and the alternative is a corrupt image on disk.
  void cancel() {
    if (_state != BatchState.running) return;
    _state = BatchState.cancelling;
    notifyListeners();
  }

  Future<BatchItem> _process(
    BatchItem item,
    ResizeTarget target,
    OutputOptions options,
    Set<String> protected,
  ) async {
    final format = target.format.resolve(item.path);
    if (format == null) {
      // `sameAsSource` over a WebP or a PSD. Writing it as a PNG instead would
      // be a format change the user never asked for.
      return item.copyWith(
        status: BatchItemStatus.failed,
        failure: BatchItemFailure.noEncoder,
      );
    }

    final plan = OutputNaming.resolve(
      candidate: OutputNaming.destinationFor(
        sourcePath: item.path,
        format: format,
        options: options,
      ),
      options: options,
      protected: protected,
    );
    if (plan.skipped) return item.copyWith(status: BatchItemStatus.skipped);

    try {
      final result = await Isolate.run(
        () => EncodeOps.run(
          EncodeRequest(
            sourcePath: item.path,
            format: format,
            quality: target.quality,
            maxEdge: target.maxEdge,
            maxBytes: target.maxBytes,
            outputPath: plan.path,
          ),
        ),
      );
      return item.copyWith(
        status: BatchItemStatus.done,
        outputSize: result.size,
        outputBytes: result.bytes,
        outputPath: result.outputPath,
        outputQuality: result.quality,
        budgetMet: result.budgetMet,
      );
    } on DecodeFailure {
      return item.copyWith(
        status: BatchItemStatus.failed,
        failure: BatchItemFailure.unreadable,
      );
    } catch (_) {
      // A full disk, a folder that vanished, a permission denied. All of them
      // are the same thing to the user: this file did not get written.
      return item.copyWith(
        status: BatchItemStatus.failed,
        failure: BatchItemFailure.io,
      );
    }
  }
}
