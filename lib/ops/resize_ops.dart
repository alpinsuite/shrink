/// The size arithmetic, on its own so it can be asserted without an image.
///
/// Pure functions over [PixelSize] — no decoding, no widgets, no I/O. Every
/// dimension the interface displays and every dimension the encoder is handed
/// comes from here, so a preview that disagrees with the file on disk is not a
/// failure mode this application has.
library;

import '../model/pixel_size.dart';

abstract final class ResizeOps {
  /// The smallest and largest longest-edge the interface offers.
  ///
  /// The floor is a thumbnail, the ceiling is above any consumer camera's long
  /// edge — past that, capping the edge is not what the user is doing.
  static const int minEdge = 16;
  static const int maxEdge = 12000;

  /// [source] scaled to fit inside a [longestEdge] box, preserving aspect.
  ///
  /// **Never upscales.** A source already inside the box comes back untouched.
  /// This application reduces; enlarging a 400 px image to 1600 because a cap
  /// was set at 1600 would be inventing detail nobody asked for, and it would
  /// make "max edge" mean something other than a maximum.
  static PixelSize fitWithin(PixelSize source, int longestEdge) {
    if (source.longestEdge <= longestEdge) return source;
    return scaleBy(source, longestEdge / source.longestEdge);
  }

  /// [source] scaled by [factor], clamped so neither edge disappears.
  ///
  /// A wide panorama scaled hard enough rounds its short edge to zero, and a
  /// zero-pixel image is a crash inside the encoder rather than a small file.
  static PixelSize scaleBy(PixelSize source, double factor) {
    final width = (source.width * factor).round();
    final height = (source.height * factor).round();
    return PixelSize(width < 1 ? 1 : width, height < 1 ? 1 : height);
  }

  /// The size a file will actually be written at, given an optional cap.
  ///
  /// Null [longestEdge] means no cap, which is the common case when the user is
  /// only converting format or only chasing a file size.
  static PixelSize targetSize(PixelSize source, int? longestEdge) {
    if (longestEdge == null) return source;
    return fitWithin(source, longestEdge.clamp(minEdge, maxEdge));
  }
}
