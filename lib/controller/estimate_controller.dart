import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/batch_item.dart';
import '../model/output_format.dart';
import '../model/pixel_size.dart';
import '../model/resize_target.dart';
import '../ops/preview_worker.dart';
import '../ops/resize_ops.dart';
import '../ops/size_model.dart';
import 'queue_controller.dart';
import 'target_controller.dart';

/// A suggested value for a control the user is not currently touching.
@immutable
class Recommendation {
  const Recommendation({required this.value, required this.reason});

  /// The value to apply — a quality, or a longest edge in pixels. Which one is
  /// implied by the field it appears in.
  final int value;

  final RecommendationReason reason;
}

/// Why a recommendation is being made, so the interface can phrase it.
///
/// An enum rather than a sentence: a translated string built in the controller
/// layer is exactly what `tools/check_hardcoded_strings.sh` exists to stop.
enum RecommendationReason {
  /// This quality would bring the file inside the size budget.
  qualityForBudget,

  /// These dimensions would bring the file inside the size budget.
  edgeForBudget,

  /// The budget cannot be met by quality alone; dimensions have to give too.
  edgeBecauseQualityExhausted,

  /// A size budget that this format and these dimensions comfortably meet, so
  /// the user can see what they are actually getting.
  budgetForCurrentSettings,
}

/// Everything the target panel displays that is not a control's own value.
@immutable
class TargetEstimate {
  const TargetEstimate({
    this.outputSize,
    this.outputBytes,
    this.measured = false,
    this.budgetMet = true,
    this.keptOriginal = false,
    this.quality,
    this.qualityApplies = false,
    this.qualityRecommendation,
    this.edgeRecommendation,
    this.budgetRecommendation,
  });

  /// The dimensions the selected file would be written at.
  final PixelSize? outputSize;

  /// Its size, measured where possible and modelled where not.
  final int? outputBytes;

  /// True when [outputBytes] came from an encode that really happened at these
  /// exact settings. The interface drops its `≈` when it does.
  final bool measured;

  /// False when the byte budget could not be met at all.
  final bool budgetMet;

  /// True when these settings leave the selected file as it is, because
  /// encoding it again would make it no smaller. The quality shown would then
  /// describe an encode that was thrown away, so the caption drops it.
  final bool keptOriginal;

  /// The quality the pipeline settled on, which is below the requested one when
  /// the budget forced it down.
  final int? quality;

  /// Whether [quality] means anything for *this file*.
  ///
  /// Distinct from the target's own `qualityApplies`, which answers for the
  /// whole batch: "same as source" keeps the slider live because the queue
  /// probably contains JPEGs, but the selected file may well be a PNG, and
  /// captioning its preview "quality 75" would be inventing a setting.
  final bool qualityApplies;

  final Recommendation? qualityRecommendation;
  final Recommendation? edgeRecommendation;
  final Recommendation? budgetRecommendation;

  bool get isEmpty => outputSize == null && outputBytes == null;
}

/// Turns the target into numbers, and the numbers into recommendations.
///
/// This is the feature that makes the application worth using rather than a
/// dialog with four fields: move one control and the others say what they would
/// have to be. It works because the estimates are *measured*. A worker isolate
/// holds the selected image decoded and re-encodes it whenever the controls
/// settle; each measurement goes into a [SizeModel] for that file, and the
/// model is what answers the inverse questions ("what quality fits 500 KB?")
/// instantly, without another encode.
///
/// Before the first measurement lands the model falls back to a seed curve, and
/// the interface marks the number as an estimate. Once it has measured, it
/// stops guessing.
class EstimateController extends ChangeNotifier {
  EstimateController({required this.queue, required this.target}) {
    queue.addListener(_onQueueChanged);
    target.addListener(_onTargetChanged);
    _sync();
  }

  /// How long the controls must be still before a real encode is started.
  ///
  /// Long enough that dragging a slider across its range starts one encode
  /// rather than forty; short enough that it feels like a consequence of
  /// letting go rather than a separate step.
  static const Duration _settleDelay = Duration(milliseconds: 280);

  final QueueController queue;
  final TargetController target;

  /// One model per source file. Compressibility is a property of the picture,
  /// so a model learnt from a photograph must never be applied to a screenshot.
  final Map<String, SizeModel> _models = <String, SizeModel>{};

  PreviewWorker? _worker;
  Future<PreviewWorker>? _spawning;

  String? _loadedPath;
  PixelSize? _loadedSize;

  Timer? _settle;
  int _generation = 0;
  bool _measuring = false;
  bool _disposed = false;

  Uint8List? _previewData;
  TargetEstimate _estimate = const TargetEstimate();

  /// The encoded output of the selected file, for the preview to draw. Null
  /// while nothing has been measured, or when the result is too large to be
  /// worth shipping out of the worker.
  Uint8List? get previewData => _previewData;

  TargetEstimate get estimate => _estimate;

  /// True while a real encode is in flight, so the panel can say so instead of
  /// looking frozen on a stale number.
  bool get isMeasuring => _measuring;

  /// The file the estimate describes.
  BatchItem? get subject => queue.selected;

  void _onQueueChanged() => _sync();

  void _onTargetChanged() {
    _recompute();
    _scheduleMeasurement();
  }

  /// Reacts to a change of selection: a different file needs a different model,
  /// a different preview, and a fresh decode in the worker.
  void _sync() {
    final item = queue.selected;
    final path = item?.path;
    if (path == _loadedPath) {
      _recompute();
      return;
    }

    _loadedPath = path;
    _loadedSize = null;
    _previewData = null;
    _estimate = const TargetEstimate();
    // Busy from the moment the selection changes: decoding a 12 MP source is
    // the slowest step of all, and it happens before any encode is scheduled.
    _measuring = path != null;
    notifyListeners();

    if (path == null) return;
    _load(path);
  }

  /// Hands the newly selected file to the worker to decode and hold.
  ///
  /// [_generation] is what makes a fast click through the queue safe: every
  /// reply carries the generation it was asked under, and a reply for a file
  /// the user has already moved past is dropped rather than applied to whatever
  /// is selected now.
  void _load(String path) {
    final generation = ++_generation;
    unawaited(() async {
      final worker = await _ensureWorker();
      if (_disposed || generation != _generation) return;
      final source = await worker.load(path);
      if (_disposed || generation != _generation) return;
      _loadedSize = source?.size;
      _recompute();
      _scheduleMeasurement();
    }());
  }

  Future<PreviewWorker> _ensureWorker() {
    final existing = _worker;
    if (existing != null) return Future<PreviewWorker>.value(existing);
    return _spawning ??= PreviewWorker.spawn().then((worker) {
      // Losing the race against dispose() would otherwise leak an isolate that
      // nothing holds a reference to.
      if (_disposed) {
        worker.dispose();
        return worker;
      }
      _worker = worker;
      return worker;
    });
  }

  void _scheduleMeasurement() {
    _settle?.cancel();
    if (_loadedPath == null) return;
    // Busy for the settle delay as well as the encode. Otherwise the panel
    // spends the first third of a second showing the *previous* answer with
    // nothing to say it is out of date, which is exactly the window in which
    // someone is looking to see whether their slider did anything.
    _measuring = true;
    notifyListeners();
    _settle = Timer(_settleDelay, _measure);
  }

  Future<void> _measure() async {
    final path = _loadedPath;
    final item = queue.selected;
    final format = path == null ? null : target.target.format.resolve(path);

    // Nothing to measure: no selection, or a source this application can read
    // but not write. Either way the panel must stop saying it is working.
    if (path == null || item == null || format == null) {
      _measuring = false;
      notifyListeners();
      return;
    }

    final generation = _generation;

    final worker = await _ensureWorker();
    if (_disposed) return;
    if (generation != _generation) {
      _measuring = false;
      return;
    }

    final measurement = await worker.measure(
      target: target.target,
      format: format,
      wantImage: true,
    );
    if (_disposed) return;

    _measuring = false;
    if (generation != _generation) return;
    if (measurement == null) {
      notifyListeners();
      return;
    }

    // Every encode the search performed is a free data point, including the
    // ones that missed — those are the most informative.
    final model = _modelFor(path);
    for (final sample in measurement.samples) {
      model.record(sample);
    }
    if (measurement.data != null) _previewData = measurement.data;

    _recompute(measurement: measurement);
  }

  SizeModel _modelFor(String path) =>
      _models.putIfAbsent(path, () => SizeModel());

  /// Rebuilds the estimate and the recommendations from what is currently
  /// known. Cheap: no encoding, only the model.
  void _recompute({PreviewMeasurement? measurement}) {
    final item = queue.selected;
    final path = _loadedPath;
    final source = _loadedSize ?? item?.size;

    if (item == null || path == null || source == null) {
      _estimate = const TargetEstimate();
      notifyListeners();
      return;
    }

    // Named `resize` rather than `target`, which is the controller this one
    // reads from — two different things one word away from each other.
    final resize = target.target;
    final format = resize.format.resolve(path);
    if (format == null) {
      _estimate = const TargetEstimate();
      notifyListeners();
      return;
    }

    final model = _modelFor(path);
    final projected = model.estimate(
      source: source,
      target: resize,
      format: format,
    );

    // A measurement that has just landed outranks the model: it describes these
    // exact settings, including any dimension reduction the budget forced.
    final size = measurement?.size ?? projected.size;
    final bytes = measurement?.bytes ?? projected.bytes;
    final measured = measurement != null || projected.measured;

    _estimate = TargetEstimate(
      outputSize: size,
      outputBytes: bytes,
      measured: measured,
      budgetMet: measurement?.budgetMet ?? true,
      keptOriginal: measurement?.keptOriginal ?? false,
      quality: measurement?.quality ?? resize.quality,
      qualityApplies: format.hasQuality,
      qualityRecommendation: _recommendQuality(model, format, resize, size),
      edgeRecommendation: _recommendEdge(model, format, resize, source),
      budgetRecommendation: _recommendBudget(resize, bytes),
    );
    notifyListeners();
  }

  /// The quality that would bring the file inside the budget.
  ///
  /// Shown only when a budget is set, the format has a quality knob, and the
  /// answer differs from what the user already chose — a hint that repeats the
  /// current value back is noise.
  Recommendation? _recommendQuality(
    SizeModel model,
    OutputFormat format,
    ResizeTarget resize,
    PixelSize size,
  ) {
    final budget = resize.maxBytes;
    if (budget == null || !format.hasQuality) return null;

    final quality = model.recommendQuality(
      format: format,
      pixels: size.pixels,
      budget: budget,
    );
    if (quality == null || quality >= resize.quality) return null;
    return Recommendation(
      value: quality,
      reason: RecommendationReason.qualityForBudget,
    );
  }

  /// The longest edge that would bring the file inside the budget.
  ///
  /// The reason differs depending on whether quality could have done the job:
  /// when it could not, this is the only lever left and the interface says so.
  Recommendation? _recommendEdge(
    SizeModel model,
    OutputFormat format,
    ResizeTarget resize,
    PixelSize source,
  ) {
    final budget = resize.maxBytes;
    if (budget == null) return null;

    final currentSize = ResizeOps.targetSize(source, resize.maxEdge);
    final viableQuality = format.hasQuality
        ? model.recommendQuality(
            format: format,
            pixels: currentSize.pixels,
            budget: budget,
          )
        : null;

    // Quality alone reaches the budget without dropping below the floor, so
    // recommending a smaller image as well would be over-eager.
    if (viableQuality != null &&
        viableQuality >= ResizeTarget.recommendedQualityFloor) {
      return null;
    }

    final edge = model.recommendMaxEdge(
      format: format,
      source: source,
      quality: format.hasQuality
          ? ResizeTarget.recommendedQualityFloor
          : resize.quality,
      budget: budget,
    );
    if (edge == null) return null;
    // Nothing to suggest if the cap is already at or below the answer.
    final current = resize.maxEdge ?? source.longestEdge;
    if (edge >= current) return null;

    return Recommendation(
      value: edge,
      reason: format.hasQuality
          ? RecommendationReason.edgeBecauseQualityExhausted
          : RecommendationReason.edgeForBudget,
    );
  }

  /// The budget the current settings actually produce.
  ///
  /// This is the hint that answers "I moved quality — what does that cost me?".
  /// Offered only when no budget is set: once there is one, the budget field is
  /// the thing being satisfied, not the thing being suggested.
  Recommendation? _recommendBudget(ResizeTarget resize, int bytes) {
    if (resize.maxBytes != null || bytes <= 0) return null;
    // Rounded up to something a person would have typed, and with a little room
    // so applying it does not immediately force a re-encode to meet it.
    final rounded = _roundBudget((bytes * 1.1).round());
    if (rounded < ResizeTarget.minBudget || rounded > ResizeTarget.maxBudget) {
      return null;
    }
    return Recommendation(
      value: rounded,
      reason: RecommendationReason.budgetForCurrentSettings,
    );
  }

  /// Rounds to one or two significant figures, the way a person states a size.
  static int _roundBudget(int bytes) {
    if (bytes < 100 * 1000) {
      return (bytes / (10 * 1000)).ceil() * 10 * 1000;
    }
    if (bytes < 1000 * 1000) {
      return (bytes / (50 * 1000)).ceil() * 50 * 1000;
    }
    return (bytes / (100 * 1000)).ceil() * 100 * 1000;
  }

  @override
  void dispose() {
    _disposed = true;
    _settle?.cancel();
    queue.removeListener(_onQueueChanged);
    target.removeListener(_onTargetChanged);
    _worker?.dispose();
    super.dispose();
  }
}
