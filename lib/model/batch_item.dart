import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'pixel_size.dart';

/// Where one file has got to.
enum BatchItemStatus {
  /// Added, dimensions not read yet.
  probing,

  /// Probed and waiting for the batch to start.
  ready,

  /// Not an image, or an image nothing here can decode. It stays in the queue
  /// so the user can see *which* file was the problem instead of wondering why
  /// the count went down.
  unreadable,

  running,

  done,

  /// The output already existed and the collision policy said to leave it.
  skipped,

  failed,
}

/// Why a file failed, as a value the interface can translate.
///
/// A message baked in here would be an English string in the model layer, which
/// is exactly what `tools/check_hardcoded_strings.sh` exists to prevent.
enum BatchItemFailure {
  /// The file could not be decoded.
  unreadable,

  /// [OutputFormat.sameAsSource] over a format with no encoder — WebP or PSD.
  /// Writing it as something else would be a silent format change.
  noEncoder,

  /// Reading or writing failed at the filesystem.
  io,
}

/// One file in the queue, and everything known about it.
///
/// Immutable: the controller replaces items rather than mutating them, so a
/// row being rebuilt while the batch writes to it is not a race anyone has to
/// think about.
@immutable
class BatchItem {
  const BatchItem({
    required this.path,
    this.status = BatchItemStatus.probing,
    this.size,
    this.sourceBytes = 0,
    this.outputSize,
    this.outputBytes,
    this.outputPath,
    this.outputQuality,
    this.budgetMet = true,
    this.keptOriginal = false,
    this.failure,
  });

  final String path;
  final BatchItemStatus status;

  /// Null until probed, and for anything unreadable.
  final PixelSize? size;
  final int sourceBytes;

  /// Filled in once the file has actually been written.
  final PixelSize? outputSize;
  final int? outputBytes;
  final String? outputPath;
  final int? outputQuality;

  /// False when the byte budget could not be met even after every lever was
  /// pulled. The file is still written — it is the smallest this application
  /// could make it — and the row says so.
  final bool budgetMet;

  /// True when the file written is the source, byte for byte: nothing was
  /// resized, the format did not change, and encoding it again would only have
  /// made it bigger. The row says so rather than claiming a saving of zero.
  final bool keptOriginal;

  final BatchItemFailure? failure;

  String get name => p.basename(path);

  bool get isReady => status == BatchItemStatus.ready;

  /// True for anything the batch would attempt.
  bool get isProcessable =>
      status != BatchItemStatus.unreadable && size != null;

  /// How much smaller the output came out, as a fraction saved. Null until it
  /// has been written.
  double? get savedFraction {
    final out = outputBytes;
    if (out == null || sourceBytes <= 0) return null;
    return 1 - (out / sourceBytes);
  }

  BatchItem copyWith({
    BatchItemStatus? status,
    PixelSize? size,
    int? sourceBytes,
    PixelSize? outputSize,
    int? outputBytes,
    String? outputPath,
    int? outputQuality,
    bool? budgetMet,
    bool? keptOriginal,
    BatchItemFailure? failure,
  }) {
    return BatchItem(
      path: path,
      status: status ?? this.status,
      size: size ?? this.size,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      outputSize: outputSize ?? this.outputSize,
      outputBytes: outputBytes ?? this.outputBytes,
      outputPath: outputPath ?? this.outputPath,
      outputQuality: outputQuality ?? this.outputQuality,
      budgetMet: budgetMet ?? this.budgetMet,
      keptOriginal: keptOriginal ?? this.keptOriginal,
      failure: failure ?? this.failure,
    );
  }

  /// Back to the state it was in before the batch ran, keeping what was probed.
  ///
  /// Used when the target changes: last run's output size is no longer the
  /// answer to a question anyone is asking.
  BatchItem reset() {
    return BatchItem(
      path: path,
      status: status == BatchItemStatus.unreadable
          ? BatchItemStatus.unreadable
          : BatchItemStatus.ready,
      size: size,
      sourceBytes: sourceBytes,
    );
  }
}
