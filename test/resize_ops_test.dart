import 'package:flutter_test/flutter_test.dart';
import 'package:shrink/model/pixel_size.dart';
import 'package:shrink/ops/resize_ops.dart';

void main() {
  group('fitWithin', () {
    test('scales the longest edge down to the cap', () {
      expect(
        ResizeOps.fitWithin(const PixelSize(4000, 3000), 1600),
        const PixelSize(1600, 1200),
      );
    });

    test('uses the height when the image is portrait', () {
      expect(
        ResizeOps.fitWithin(const PixelSize(3000, 4000), 1600),
        const PixelSize(1200, 1600),
      );
    });

    test('never upscales', () {
      // "Maximum edge" has to mean a maximum. Enlarging a small image to meet
      // the cap would be inventing detail nobody asked for.
      const small = PixelSize(400, 300);
      expect(ResizeOps.fitWithin(small, 1600), small);
      expect(ResizeOps.fitWithin(small, 400), small);
    });

    test('preserves aspect ratio to within a pixel', () {
      final result = ResizeOps.fitWithin(const PixelSize(4032, 3024), 1000);
      expect(result.longestEdge, 1000);
      expect(result.aspectRatio, closeTo(4032 / 3024, 0.002));
    });
  });

  group('scaleBy', () {
    test('never lets an edge round away to nothing', () {
      // A panorama scaled hard enough rounds its short edge to zero, and a
      // zero-pixel image is a crash inside the encoder rather than a small file.
      final result = ResizeOps.scaleBy(const PixelSize(10000, 20), 0.001);
      expect(result.width, greaterThanOrEqualTo(1));
      expect(result.height, greaterThanOrEqualTo(1));
    });

    test('rounds rather than truncates', () {
      expect(ResizeOps.scaleBy(const PixelSize(101, 101), 0.5).width, 51);
    });
  });

  group('targetSize', () {
    test('a null cap leaves the source alone', () {
      const source = PixelSize(4000, 3000);
      expect(ResizeOps.targetSize(source, null), source);
    });

    test('clamps a cap outside the offered range', () {
      final tiny = ResizeOps.targetSize(const PixelSize(4000, 3000), 1);
      expect(tiny.longestEdge, ResizeOps.minEdge);
    });

    test('a one-pixel image survives every cap', () {
      const pixel = PixelSize(1, 1);
      expect(ResizeOps.targetSize(pixel, ResizeOps.minEdge), pixel);
    });
  });
}
