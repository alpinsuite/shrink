/// Predicting how large an encode will come out, and inverting that prediction
/// to answer "what would I have to change to hit this budget?".
///
/// This is what makes the interface able to say, the moment a slider moves,
/// what the *other* controls should read. It is deliberately a model and not a
/// guess dressed up as one:
///
/// ```
/// bytes = complexity × pixels × bitsPerPixel(format, quality)
/// ```
///
/// `bitsPerPixel` is a seed curve fitted to typical photographic content.
/// `complexity` is a per-image multiplier **learnt from real encodes** — every
/// time the preview or the batch actually encodes something, the measurement
/// comes back here and the model stops guessing about that image. With two or
/// more measurements at different qualities it abandons the seed curve entirely
/// and interpolates between what it measured.
///
/// Nothing here decides what gets written. The batch always encodes for real
/// and verifies the result against the budget; this only decides what number to
/// show a user while they are still choosing. Pure Dart, no I/O, no widgets.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/output_format.dart';
import '../model/pixel_size.dart';
import '../model/resize_target.dart';
import 'resize_ops.dart';

/// One real encode that happened: this many pixels, at this quality, in this
/// format, came out this many bytes.
@immutable
class SizeSample {
  const SizeSample({
    required this.format,
    required this.pixels,
    required this.quality,
    required this.bytes,
  });

  final OutputFormat format;
  final int pixels;

  /// The quality it was encoded at. Meaningless for a format without one, and
  /// normalised to [ResizeTarget.maxQuality] on the way in so that lossless
  /// samples all land on the same point.
  final int quality;

  final int bytes;

  double get bytesPerPixel => bytes / pixels;
}

/// The predictions the interface shows next to the controls.
@immutable
class SizeEstimate {
  const SizeEstimate({
    required this.bytes,
    required this.measured,
    required this.size,
  });

  final int bytes;

  /// True when this came from an encode that really happened at exactly these
  /// settings, rather than from the model. The interface drops the `≈` and
  /// stops hedging when it is.
  final bool measured;

  final PixelSize size;
}

/// A model of one image's compressibility, refined by measurement.
///
/// One instance per source image. Samples for different formats are kept apart:
/// a photograph's PNG size tells you almost nothing about its JPEG size.
class SizeModel {
  SizeModel();

  /// Measurements, newest last, keyed by format.
  final Map<OutputFormat, List<SizeSample>> _samples =
      <OutputFormat, List<SizeSample>>{};

  /// How many measurements to keep per format.
  ///
  /// Enough to bracket any quality the user lands on; few enough that a stale
  /// early measurement cannot outvote several recent ones.
  static const int _maxSamplesPerFormat = 6;

  /// The seed bytes-per-pixel curve for JPEG.
  ///
  /// Fitted through three points that hold for typical photographic content:
  /// 0.07 B/px at q30, 0.13 at q50, 0.42 at q90. The exponential shape is the
  /// important part — JPEG's size is roughly geometric in quality, so a linear
  /// seed would be wrong by a factor of three at both ends.
  ///
  /// Being wrong here is cheap: the first real measurement replaces it.
  static double _jpegBytesPerPixel(int quality) =>
      0.0286 * math.exp(0.0299 * quality.clamp(1, 100));

  /// Seed bytes-per-pixel for the formats with no quality knob.
  ///
  /// These vary far more with content than with anything the user can set —
  /// a flat-colour PNG and a photograph differ by twenty times — so the seeds
  /// are only ever a first frame's worth of placeholder before a measurement
  /// arrives.
  static double _losslessBytesPerPixel(OutputFormat format) => switch (format) {
    OutputFormat.png => 1.6,
    OutputFormat.tiff => 3.2,
    OutputFormat.bmp => 3.0,
    OutputFormat.tga => 3.0,
    OutputFormat.gif => 0.7,
    // Reached only for sameAsSource, which the caller resolves first.
    _ => 1.6,
  };

  static double _seedBytesPerPixel(OutputFormat format, int quality) =>
      format.hasQuality
      ? _jpegBytesPerPixel(quality)
      : _losslessBytesPerPixel(format);

  /// Feeds a real encode back into the model.
  void record(SizeSample sample) {
    final list = _samples.putIfAbsent(sample.format, () => <SizeSample>[]);
    // A repeat measurement at the same quality replaces the old one rather than
    // crowding the window: the newer encode was at the size the user cares
    // about now.
    list.removeWhere((existing) => existing.quality == sample.quality);
    list.add(sample);
    if (list.length > _maxSamplesPerFormat) list.removeAt(0);
  }

  /// True once anything at all has been measured for [format].
  bool hasSamplesFor(OutputFormat format) =>
      (_samples[format]?.isNotEmpty ?? false);

  /// An exact match, if this precise encode has already been performed.
  SizeSample? exactSample(OutputFormat format, int pixels, int quality) {
    final effective = format.hasQuality ? quality : ResizeTarget.maxQuality;
    for (final sample in _samples[format] ?? const <SizeSample>[]) {
      if (sample.pixels == pixels && sample.quality == effective) return sample;
    }
    return null;
  }

  /// Predicted bytes for [pixels] pixels of this image at [quality].
  ///
  /// Bytes scale linearly in pixel count, which is close enough over the range
  /// a resizer works in. The quality axis is where the modelling happens.
  double predictBytes({
    required OutputFormat format,
    required int pixels,
    required int quality,
  }) {
    return pixels * _bytesPerPixel(format, quality);
  }

  /// Bytes per pixel at [quality], from measurements where there are any.
  ///
  /// Interpolation is in log space on both axes because the underlying
  /// relationship is geometric: a straight line between 0.07 and 0.42 badly
  /// underestimates the middle, and a straight line in logs does not.
  double _bytesPerPixel(OutputFormat format, int quality) {
    final effective = format.hasQuality
        ? quality.clamp(ResizeTarget.minQuality, ResizeTarget.maxQuality)
        : ResizeTarget.maxQuality;
    final samples = _samples[format] ?? const <SizeSample>[];

    if (samples.isEmpty) return _seedBytesPerPixel(format, effective);

    // Without a quality axis there is nothing to interpolate along: the mean of
    // what was measured is the whole model.
    if (!format.hasQuality) {
      final total = samples.fold<double>(
        0,
        (sum, sample) => sum + sample.bytesPerPixel,
      );
      return total / samples.length;
    }

    final sorted = samples.toList()
      ..sort((a, b) => a.quality.compareTo(b.quality));

    for (final sample in sorted) {
      if (sample.quality == effective) return sample.bytesPerPixel;
    }

    // Bracketed: interpolate between the two neighbours.
    for (var i = 0; i < sorted.length - 1; i++) {
      final low = sorted[i];
      final high = sorted[i + 1];
      if (low.quality < effective && effective < high.quality) {
        final t = (effective - low.quality) / (high.quality - low.quality);
        return math.exp(
          _lerp(math.log(low.bytesPerPixel), math.log(high.bytesPerPixel), t),
        );
      }
    }

    // Outside the measured range: keep the seed curve's *shape* and anchor it
    // to the nearest measurement. Extrapolating the measured slope instead runs
    // away badly from a single sample, and the seed curve is at least the right
    // shape everywhere.
    final anchor = effective < sorted.first.quality
        ? sorted.first
        : sorted.last;
    final ratio =
        _seedBytesPerPixel(format, effective) /
        _seedBytesPerPixel(format, anchor.quality);
    return anchor.bytesPerPixel * ratio;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// What the file at [source] would come out as under [target].
  ///
  /// [format] must already be resolved — [OutputFormat.sameAsSource] has no
  /// compressibility of its own.
  SizeEstimate estimate({
    required PixelSize source,
    required ResizeTarget target,
    required OutputFormat format,
  }) {
    final size = ResizeOps.targetSize(source, target.maxEdge);
    final exact = exactSample(format, size.pixels, target.quality);
    if (exact != null) {
      return SizeEstimate(bytes: exact.bytes, measured: true, size: size);
    }
    return SizeEstimate(
      bytes: predictBytes(
        format: format,
        pixels: size.pixels,
        quality: target.quality,
      ).round(),
      measured: false,
      size: size,
    );
  }

  /// The highest quality that would fit [budget] bytes at [pixels] pixels.
  ///
  /// Null when the format has no quality knob, or when even
  /// [ResizeTarget.minQuality] would not fit — in which case dimensions are the
  /// only lever left and [recommendMaxEdge] is the question to ask instead.
  int? recommendQuality({
    required OutputFormat format,
    required int pixels,
    required int budget,
  }) {
    if (!format.hasQuality) return null;

    // Monotonic in quality, so a plain binary search over the integer range is
    // both exact and cheaper than inverting the interpolation by hand.
    var low = ResizeTarget.minQuality;
    var high = ResizeTarget.maxQuality;
    if (predictBytes(format: format, pixels: pixels, quality: low) > budget) {
      return null;
    }
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final bytes = predictBytes(format: format, pixels: pixels, quality: mid);
      if (bytes <= budget) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// The largest longest-edge that would fit [budget] bytes at [quality].
  ///
  /// Solved directly rather than searched: bytes are linear in pixel count and
  /// pixel count is quadratic in the edge, so the answer is a square root.
  /// Null when even [ResizeOps.minEdge] would not fit, which means the budget
  /// is unreachable in this format at this quality by any means.
  int? recommendMaxEdge({
    required OutputFormat format,
    required PixelSize source,
    required int quality,
    required int budget,
  }) {
    final perPixel = _bytesPerPixel(format, quality);
    if (perPixel <= 0) return null;

    final allowedPixels = budget / perPixel;
    final scale = math.sqrt(allowedPixels / source.pixels);
    // Never recommends an upscale: capping the edge above what the source
    // already is would be a recommendation that changes nothing.
    final edge = (source.longestEdge * math.min(scale, 1.0)).floor();

    if (edge < ResizeOps.minEdge) return null;
    return edge;
  }
}
