/// Decode, resize, encode — the whole pixel pipeline, in one place, off the UI
/// thread.
///
/// [EncodeOps.run] is an isolate entry point. Everything it touches has to
/// survive being sent across that boundary, which is why the request and the
/// result are plain value classes and why nothing here reaches for a widget, a
/// `ui.Image` or a `BuildContext`.
///
/// It is used for two different jobs that are really the same job: producing
/// the file the batch writes, and producing the preview the interface shows.
/// One implementation, so a preview that disagrees with the output on disk is
/// not a state this application can get into.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../model/output_format.dart';
import '../model/pixel_size.dart';
import '../model/resize_target.dart';
import 'resize_ops.dart';
import 'size_model.dart';

/// One file's worth of work.
@immutable
class EncodeRequest {
  const EncodeRequest({
    required this.sourcePath,
    required this.format,
    required this.quality,
    this.maxEdge,
    this.maxBytes,
    this.outputPath,
    this.wantBytes = false,
  });

  final String sourcePath;

  /// Already resolved — [OutputFormat.sameAsSource] never reaches here, because
  /// "the same as what?" is a question the caller can answer and an isolate
  /// cannot.
  final OutputFormat format;

  final int quality;
  final int? maxEdge;

  /// The file size ceiling, or null. When set, the pipeline keeps encoding
  /// until it is met or it runs out of levers — it never returns an oversized
  /// file and calls it success.
  final int? maxBytes;

  /// Where to write. Null means the caller only wants numbers, which is what
  /// the preview and the estimate refresh ask for.
  final String? outputPath;

  /// Whether the encoded bytes come back in the result. The preview needs them
  /// to draw; the batch does not, and a 12 MP image crossing the isolate
  /// boundary for no reason is a copy nobody asked for.
  final bool wantBytes;
}

/// What came out, including every measurement made along the way.
@immutable
class EncodeResult {
  const EncodeResult({
    required this.sourceSize,
    required this.size,
    required this.bytes,
    required this.quality,
    required this.budgetMet,
    required this.samples,
    this.keptOriginal = false,
    this.data,
    this.outputPath,
  });

  final PixelSize sourceSize;

  /// The size actually written, which may be smaller than the requested cap if
  /// meeting a byte budget needed dimensions as well as quality.
  final PixelSize size;

  final int bytes;

  /// The quality actually used. Below the requested one when the budget search
  /// had to bring it down.
  final int quality;

  /// False when even the last resort was not enough. The file is still the best
  /// attempt, and the queue row says so rather than pretending.
  final bool budgetMet;

  /// Every encode performed, for the estimator to learn from. The failed
  /// attempts are the most informative ones and are deliberately included.
  final List<SizeSample> samples;

  /// True when [data] is the source file, byte for byte, because encoding it
  /// again produced nothing smaller. See [EncodeOps.encodeImage].
  final bool keptOriginal;

  final Uint8List? data;
  final String? outputPath;
}

/// The file an image was decoded from, for the one decision that needs it.
///
/// [format] is what the bytes *are*, sniffed from their header, and not what
/// the file is called: a PNG named `.jpg` must not be passed off as a JPEG
/// because its name and the target agree.
@immutable
class SourceFile {
  const SourceFile({required this.bytes, required this.format});

  /// Reads the header of [bytes]. [format] is null for a format this
  /// application can read but not write, which can therefore never be "the
  /// same format as the output".
  factory SourceFile.sniff(Uint8List bytes) => SourceFile(
    bytes: bytes,
    format: switch (img.findFormatForData(bytes)) {
      img.ImageFormat.jpg => OutputFormat.jpeg,
      img.ImageFormat.png => OutputFormat.png,
      img.ImageFormat.tiff => OutputFormat.tiff,
      img.ImageFormat.bmp => OutputFormat.bmp,
      img.ImageFormat.tga => OutputFormat.tga,
      img.ImageFormat.gif => OutputFormat.gif,
      _ => null,
    },
  );

  final Uint8List bytes;
  final OutputFormat? format;
}

/// The source could not be read as an image.
class DecodeFailure implements Exception {
  const DecodeFailure(this.path);

  final String path;

  @override
  String toString() => 'Could not decode image: $path';
}

abstract final class EncodeOps {
  /// How many encodes the byte-budget search may perform per file.
  ///
  /// `package:image` is pure Dart, so a 12 MP JPEG encode is measured in
  /// seconds, not milliseconds. A textbook binary search over 1–100 would take
  /// seven of them per dimension attempt; the search below uses the *shape* of
  /// the quality/size curve to jump straight to a candidate instead, and lands
  /// inside the budget in two or three.
  static const int maxEncodeAttempts = 6;

  /// How many times the search may reduce dimensions once quality is exhausted.
  static const int maxDimensionAttempts = 3;

  /// How close under the budget counts as done.
  ///
  /// Without this the search spends its last attempts chasing the final two
  /// percent of a budget that was a round number somebody typed.
  static const double _closeEnough = 0.93;

  /// The isolate entry point for the batch. One file in, one file out.
  static Future<EncodeResult> run(EncodeRequest request) async {
    final bytes = await File(request.sourcePath).readAsBytes();
    final image = decode(bytes, request.sourcePath);
    if (image == null) throw DecodeFailure(request.sourcePath);

    final result = encodeImage(
      source: image,
      original: SourceFile.sniff(bytes),
      format: request.format,
      quality: request.quality,
      maxEdge: request.maxEdge,
      maxBytes: request.maxBytes,
    );

    final outputPath = request.outputPath;
    if (outputPath != null) {
      await File(outputPath).writeAsBytes(result.data!, flush: true);
    }

    return EncodeResult(
      sourceSize: result.sourceSize,
      size: result.size,
      bytes: result.bytes,
      quality: result.quality,
      budgetMet: result.budgetMet,
      samples: result.samples,
      keptOriginal: result.keptOriginal,
      outputPath: outputPath,
      // Dropped unless asked for, now that it has been written.
      data: request.wantBytes || outputPath == null ? result.data : null,
    );
  }

  /// Decodes [bytes], with EXIF orientation already applied.
  ///
  /// The filename picks the decoder, and the bytes are sniffed as a fallback: a
  /// file whose extension lies about its contents is common enough — a PNG
  /// named `.jpg` comes out of every second content management system — that
  /// the second attempt earns its keep.
  ///
  /// Orientation is baked here rather than left to `copyResize`, which does it
  /// only when it actually resizes. A portrait photograph written out landscape
  /// because no resize happened would be the most visible bug this pipeline
  /// could have.
  static img.Image? decode(Uint8List bytes, String path) {
    final decoded = img.decodeNamedImage(path, bytes) ?? img.decodeImage(bytes);
    if (decoded == null) return null;
    if (decoded.exif.imageIfd.hasOrientation &&
        decoded.exif.imageIfd.orientation != 1) {
      return img.bakeOrientation(decoded);
    }
    return decoded;
  }

  /// Resizes and encodes an already-decoded image, meeting a byte budget if one
  /// is set.
  ///
  /// This is the whole pipeline, and it is the *only* one. The batch reaches it
  /// through [run], which decodes from a path; the preview reaches it directly,
  /// with an image it is holding resident so that dragging a slider does not
  /// re-decode a 12 MP photograph on every frame. A preview computed by a
  /// second implementation would eventually disagree with the file on disk, and
  /// then every number in the interface would be worthless.
  ///
  /// **The output is never larger than the file it came from.** Decoding a
  /// JPEG and encoding it again at quality 85 routinely produces *more* bytes
  /// than the original had, and an application called Shrink that hands back a
  /// bigger file has done the opposite of its job. So when [original] is given,
  /// nothing was resized, the format has not changed, and the encode gained
  /// nothing, the result is the original file, byte for byte — which is also
  /// lossless, where the re-encode would have been a generation of damage for
  /// no benefit. Both callers pass [original], so the preview shows this too.
  static EncodeResult encodeImage({
    required img.Image source,
    required OutputFormat format,
    required int quality,
    SourceFile? original,
    int? maxEdge,
    int? maxBytes,
  }) {
    final result = _encodeImage(
      source: source,
      format: format,
      quality: quality,
      maxEdge: maxEdge,
      maxBytes: maxBytes,
    );
    if (original == null ||
        original.format != format ||
        result.size != result.sourceSize ||
        result.bytes < original.bytes.length) {
      return result;
    }
    // Over a budget the original is not an answer, however the search fared:
    // the smallest attempt is still the closest anyone got.
    if (maxBytes != null && original.bytes.length > maxBytes) return result;

    return EncodeResult(
      sourceSize: result.sourceSize,
      size: result.size,
      bytes: original.bytes.length,
      quality: result.quality,
      budgetMet: true,
      // Kept: they are real measurements of this image, and the estimator
      // learns from them whether or not their output was used.
      samples: result.samples,
      keptOriginal: true,
      data: original.bytes,
    );
  }

  static EncodeResult _encodeImage({
    required img.Image source,
    required OutputFormat format,
    required int quality,
    int? maxEdge,
    int? maxBytes,
  }) {
    final sourceSize = PixelSize(source.width, source.height);
    final samples = <SizeSample>[];
    final size = ResizeOps.targetSize(sourceSize, maxEdge);

    if (maxBytes == null) {
      final prepared = _prepare(_resize(source, size), format);
      final data = _encode(prepared, format, quality);
      _sample(samples, format, size, quality, data.length);
      return _resultOf(
        _Attempt(size: size, quality: quality, data: data),
        sourceSize,
        samples,
        true,
      );
    }

    return _searchForBudget(
      source: source,
      format: format,
      ceiling: quality,
      initialSize: size,
      sourceSize: sourceSize,
      budget: maxBytes,
      samples: samples,
    );
  }

  /// The byte-budget search.
  ///
  /// Quality is bracketed rather than binary-searched: the size of a JPEG is
  /// roughly geometric in quality, so one measurement is enough to *predict*
  /// the quality that hits the budget and jump there. The bracket — the highest
  /// quality known to fit and the lowest known to miss — keeps each prediction
  /// honest and guarantees the search terminates. It usually lands in two
  /// encodes, which matters because `package:image` is pure Dart and a 12 MP
  /// encode is measured in seconds.
  static EncodeResult _searchForBudget({
    required img.Image source,
    required OutputFormat format,
    required int ceiling,
    required PixelSize initialSize,
    required PixelSize sourceSize,
    required int budget,
    required List<SizeSample> samples,
  }) {
    var size = initialSize;
    var attempts = 0;

    // The largest attempt that fits — the highest quality the budget allows —
    // and the smallest attempt overall, which is what gets written if nothing
    // ever fits. Handing back the *largest* failure would be perverse: the user
    // asked for small.
    _Attempt? fitting;
    _Attempt? smallest;

    for (var step = 0; step <= maxDimensionAttempts; step++) {
      final prepared = _prepare(_resize(source, size), format);

      var quality = ceiling;
      int? highestFit;
      int? lowestMiss;

      while (attempts < maxEncodeAttempts) {
        attempts++;
        final data = _encode(prepared, format, quality);
        final attempt = _Attempt(size: size, quality: quality, data: data);
        _sample(samples, format, size, quality, data.length);
        if (smallest == null || data.length < smallest.data.length) {
          smallest = attempt;
        }

        if (data.length <= budget) {
          if (fitting == null || data.length > fitting.data.length) {
            fitting = attempt;
          }
          highestFit = quality;
          // Either close enough to the budget that another encode buys nothing,
          // or already at the quality the user asked for and simply under it.
          if (data.length >= budget * _closeEnough || quality >= ceiling) {
            return _resultOf(fitting, sourceSize, samples, true);
          }
        } else {
          lowestMiss = quality;
          // A format with no quality knob has exactly one thing to try at this
          // size, and it did not fit.
          if (!format.hasQuality) break;
        }

        final next = nextQuality(
          bytes: data.length,
          budget: budget,
          current: quality,
          ceiling: ceiling,
          highestFit: highestFit,
          lowestMiss: lowestMiss,
        );
        if (next == null) break;
        quality = next;
      }

      if (fitting != null) return _resultOf(fitting, sourceSize, samples, true);
      if (attempts >= maxEncodeAttempts) break;

      // Quality is spent. Bytes are linear in pixel count, so the scale that
      // would have fitted is the square root of how far over it went. The
      // margin covers the approximation; the clamp stops a wild ratio either
      // stalling the search or collapsing the image in one step.
      final overshoot = smallest!.data.length / budget;
      final scale = (math.sqrt(1 / overshoot) * 0.95).clamp(0.35, 0.9);
      final reduced = ResizeOps.scaleBy(size, scale);
      if (reduced == size || reduced.longestEdge < ResizeOps.minEdge) break;
      size = reduced;
    }

    // Nothing met the budget. The smallest attempt is the closest anyone got,
    // and the result says plainly that it did not fit.
    return _resultOf(smallest!, sourceSize, samples, false);
  }

  /// The quality to try next, or null when quality has nothing left to give.
  ///
  /// [ceiling] is the quality the user asked for and is never exceeded.
  /// [highestFit] and [lowestMiss] bracket the answer; a prediction that lands
  /// outside the bracket is pulled back inside it, which is what makes this
  /// terminate rather than oscillate.
  @visibleForTesting
  static int? nextQuality({
    required int bytes,
    required int budget,
    required int current,
    required int ceiling,
    required int? highestFit,
    required int? lowestMiss,
  }) {
    // `bytes ≈ k·e^(0.0299·q)`, so the quality that would land exactly on the
    // budget is this far from the one just measured.
    final predicted = (current + math.log(budget / bytes) / 0.0299).round();

    var low = ResizeTarget.minQuality;
    var high = ceiling;
    if (highestFit != null) low = highestFit + 1;
    if (lowestMiss != null) high = lowestMiss - 1;
    if (low > high) return null;

    final next = predicted.clamp(low, high);
    return next == current ? null : next;
  }

  static void _sample(
    List<SizeSample> samples,
    OutputFormat format,
    PixelSize size,
    int quality,
    int bytes,
  ) {
    samples.add(
      SizeSample(
        format: format,
        pixels: size.pixels,
        // A format with no quality knob has all its samples land on one point,
        // so they average together instead of pretending to describe a curve.
        quality: format.hasQuality ? quality : ResizeTarget.maxQuality,
        bytes: bytes,
      ),
    );
  }

  static EncodeResult _resultOf(
    _Attempt attempt,
    PixelSize sourceSize,
    List<SizeSample> samples,
    bool budgetMet,
  ) {
    return EncodeResult(
      sourceSize: sourceSize,
      size: attempt.size,
      bytes: attempt.data.length,
      quality: attempt.quality,
      budgetMet: budgetMet,
      samples: samples,
      data: attempt.data,
    );
  }

  static img.Image _resize(img.Image source, PixelSize size) {
    if (source.width == size.width && source.height == size.height) {
      return source;
    }
    final scale = size.longestEdge / math.max(source.width, source.height);
    return img.copyResize(
      source,
      width: size.width,
      height: size.height,
      // Averaging is a box filter: for a real reduction it is both faster than
      // cubic and visibly cleaner, because it looks at every source pixel
      // rather than sampling a neighbourhood. Cubic wins only when barely
      // scaling at all, where there is nothing to average over.
      interpolation: scale < 0.75
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
  }

  /// Flattens transparency for formats that cannot carry it.
  ///
  /// Without this every transparent pixel encodes as black, which is the
  /// classic "why is my logo on a black square" bug.
  static img.Image _prepare(img.Image image, OutputFormat format) {
    if (format.supportsAlpha || image.numChannels < 4) return image;
    final flattened = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
    return img.compositeImage(flattened, image);
  }

  static Uint8List _encode(img.Image image, OutputFormat format, int quality) {
    return switch (format) {
      OutputFormat.jpeg => img.encodeJpg(image, quality: quality),
      OutputFormat.png => img.encodePng(image),
      OutputFormat.tiff => img.encodeTiff(image),
      OutputFormat.bmp => img.encodeBmp(image),
      OutputFormat.tga => img.encodeTga(image),
      OutputFormat.gif => img.encodeGif(image),
      // Resolved by the caller; reaching here would be a programming error.
      OutputFormat.sameAsSource => throw ArgumentError(
        'sameAsSource must be resolved before encoding',
      ),
    };
  }
}

/// One encode that happened, kept so the search can hand back the best one.
class _Attempt {
  const _Attempt({
    required this.size,
    required this.quality,
    required this.data,
  });

  final PixelSize size;
  final int quality;
  final Uint8List data;
}
