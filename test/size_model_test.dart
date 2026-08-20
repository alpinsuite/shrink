import 'package:flutter_test/flutter_test.dart';
import 'package:shrink/model/output_format.dart';
import 'package:shrink/model/pixel_size.dart';
import 'package:shrink/model/resize_target.dart';
import 'package:shrink/ops/size_model.dart';

void main() {
  SizeSample jpeg(int pixels, int quality, int bytes) => SizeSample(
    format: OutputFormat.jpeg,
    pixels: pixels,
    quality: quality,
    bytes: bytes,
  );

  group('the seed curve', () {
    test('is monotonic in quality', () {
      final model = SizeModel();
      var previous = 0.0;
      for (var quality = 1; quality <= 100; quality++) {
        final bytes = model.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: quality,
        );
        expect(bytes, greaterThan(previous));
        previous = bytes;
      }
    });

    test('is in the right order of magnitude for a photograph', () {
      final model = SizeModel();
      // A 12 MP JPEG at quality 90 is a few megabytes, not a few kilobytes and
      // not a few hundred. Being wrong here is cheap, but being wrong by three
      // orders of magnitude would make the first frame's number absurd.
      final bytes = model.predictBytes(
        format: OutputFormat.jpeg,
        pixels: 12000000,
        quality: 90,
      );
      expect(bytes, greaterThan(2 * 1000 * 1000));
      expect(bytes, lessThan(12 * 1000 * 1000));
    });

    test('scales linearly with pixel count', () {
      final model = SizeModel();
      final small = model.predictBytes(
        format: OutputFormat.jpeg,
        pixels: 1000000,
        quality: 80,
      );
      final large = model.predictBytes(
        format: OutputFormat.jpeg,
        pixels: 4000000,
        quality: 80,
      );
      expect(large / small, closeTo(4, 0.001));
    });
  });

  group('measurement', () {
    test('a measured point is reported back exactly', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 250000));
      expect(
        model.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: 80,
        ),
        closeTo(250000, 1),
      );
    });

    test('a single measurement rescales the whole curve', () {
      final plain = SizeModel();
      final measured = SizeModel()..record(jpeg(1000000, 80, 250000));

      final before = plain.predictBytes(
        format: OutputFormat.jpeg,
        pixels: 1000000,
        quality: 80,
      );
      // The measurement says this image is far more compressible than the seed
      // curve assumed; every other quality should move with it.
      expect(before, isNot(closeTo(250000, 1000)));
      expect(
        measured.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: 60,
        ),
        lessThan(250000),
      );
    });

    test('two measurements are interpolated between', () {
      final model = SizeModel()
        ..record(jpeg(1000000, 40, 100000))
        ..record(jpeg(1000000, 90, 900000));

      final middle = model.predictBytes(
        format: OutputFormat.jpeg,
        pixels: 1000000,
        quality: 65,
      );
      expect(middle, greaterThan(100000));
      expect(middle, lessThan(900000));
    });

    test('re-measuring at the same quality replaces the old point', () {
      final model = SizeModel()
        ..record(jpeg(1000000, 80, 250000))
        ..record(jpeg(1000000, 80, 400000));
      expect(
        model.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: 80,
        ),
        closeTo(400000, 1),
      );
    });

    test('a lossless format averages its samples rather than curving', () {
      final model = SizeModel()
        ..record(
          const SizeSample(
            format: OutputFormat.png,
            pixels: 1000000,
            quality: 100,
            bytes: 1000000,
          ),
        )
        ..record(
          const SizeSample(
            format: OutputFormat.png,
            pixels: 1000000,
            quality: 100,
            bytes: 1000000,
          ),
        );
      // Quality is meaningless here; asking at 30 must give the same answer.
      expect(
        model.predictBytes(
          format: OutputFormat.png,
          pixels: 1000000,
          quality: 30,
        ),
        closeTo(1000000, 1),
      );
    });

    test('models are kept apart by format', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 250000));
      expect(model.hasSamplesFor(OutputFormat.jpeg), isTrue);
      expect(model.hasSamplesFor(OutputFormat.png), isFalse);
    });
  });

  group('recommendQuality', () {
    test('finds the highest quality that fits the budget', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 500000));
      final quality = model.recommendQuality(
        format: OutputFormat.jpeg,
        pixels: 1000000,
        budget: 250000,
      );
      expect(quality, isNotNull);
      expect(quality, lessThan(80));
      // The answer has to actually fit, and one step up has to not.
      expect(
        model.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: quality!,
        ),
        lessThanOrEqualTo(250000),
      );
      expect(
        model.predictBytes(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          quality: quality + 1,
        ),
        greaterThan(250000),
      );
    });

    test('gives up when even quality 1 would not fit', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 500000));
      expect(
        model.recommendQuality(
          format: OutputFormat.jpeg,
          pixels: 1000000,
          budget: 100,
        ),
        isNull,
      );
    });

    test('has nothing to say about a format without a quality knob', () {
      expect(
        SizeModel().recommendQuality(
          format: OutputFormat.png,
          pixels: 1000000,
          budget: 500000,
        ),
        isNull,
      );
    });
  });

  group('recommendMaxEdge', () {
    test('finds an edge whose pixel count fits the budget', () {
      final model = SizeModel()..record(jpeg(4000000, 80, 1000000));
      final edge = model.recommendMaxEdge(
        format: OutputFormat.jpeg,
        source: const PixelSize(2000, 2000),
        quality: 80,
        budget: 250000,
      );
      expect(edge, isNotNull);
      // A quarter of the bytes is a quarter of the pixels, which is half the
      // edge.
      expect(edge, closeTo(1000, 30));
    });

    test('never recommends an upscale', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 10000));
      expect(
        model.recommendMaxEdge(
          format: OutputFormat.jpeg,
          source: const PixelSize(1000, 1000),
          quality: 80,
          budget: 50 * 1000 * 1000,
        ),
        lessThanOrEqualTo(1000),
      );
    });

    test('gives up when the budget is unreachable at any size', () {
      final model = SizeModel()..record(jpeg(1000000, 80, 5000000));
      expect(
        model.recommendMaxEdge(
          format: OutputFormat.jpeg,
          source: const PixelSize(1000, 1000),
          quality: 80,
          budget: 10,
        ),
        isNull,
      );
    });
  });

  group('estimate', () {
    test('reports a size that was really encoded as measured', () {
      final model = SizeModel()..record(jpeg(1600 * 1200, 85, 300000));
      final estimate = model.estimate(
        source: const PixelSize(4000, 3000),
        target: const ResizeTarget(maxEdge: 1600, quality: 85),
        format: OutputFormat.jpeg,
      );
      expect(estimate.measured, isTrue);
      expect(estimate.bytes, 300000);
      expect(estimate.size, const PixelSize(1600, 1200));
    });

    test('marks anything else as modelled', () {
      final estimate = SizeModel().estimate(
        source: const PixelSize(4000, 3000),
        target: const ResizeTarget(maxEdge: 1600, quality: 85),
        format: OutputFormat.jpeg,
      );
      expect(estimate.measured, isFalse);
      expect(estimate.bytes, greaterThan(0));
    });
  });
}
