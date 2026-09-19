import 'package:flutter/foundation.dart';

/// A whole number of pixels in each direction.
///
/// Not `dart:ui`'s `Size`: that is a pair of doubles, and every place this
/// application uses a size it means an exact pixel count. Rounding at the point
/// of use rather than at the point of calculation is how an image ends up one
/// pixel narrower than the number displayed next to it.
@immutable
class PixelSize {
  const PixelSize(this.width, this.height)
    : assert(width > 0, 'width must be positive'),
      assert(height > 0, 'height must be positive');

  final int width;
  final int height;

  int get longestEdge => width > height ? width : height;

  int get pixels => width * height;

  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      other is PixelSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}
