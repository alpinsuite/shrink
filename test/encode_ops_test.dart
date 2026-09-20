import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shrink/model/output_format.dart';
import 'package:shrink/model/resize_target.dart';
import 'package:shrink/ops/encode_ops.dart';

void main() {
  /// A photograph-like image: enough structure that JPEG cannot compress it to
  /// nothing, which is what makes the budget search actually have to work.
  img.Image photo({int width = 600, int height = 400}) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    final random = math.Random(7);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(
          x,
          y,
          (x * 3 + random.nextInt(90)) & 0xff,
          (y * 5 + random.nextInt(90)) & 0xff,
          ((x + y) * 2 + random.nextInt(90)) & 0xff,
        );
      }
    }
    return image;
  }

  /// A half-transparent square, for the alpha-flattening case.
  img.Image transparent() {
    final image = img.Image(width: 40, height: 40, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 19,
      y2: 39,
      color: img.ColorRgba8(255, 0, 0, 255),
    );
    return image;
  }

  group('encodeImage', () {
    test('writes every offered format', () {
      final source = photo(width: 80, height: 60);
      for (final format in OutputFormat.values) {
        if (format == OutputFormat.sameAsSource) continue;
        final result = EncodeOps.encodeImage(
          source: source,
          format: format,
          quality: 80,
        );
        expect(result.bytes, greaterThan(0), reason: format.name);
        expect(
          img.decodeImage(result.data!),
          isNotNull,
          reason: '${format.name} produced bytes nothing can decode',
        );
      }
    });

    test('resizes to the cap without upscaling', () {
      final result = EncodeOps.encodeImage(
        source: photo(width: 600, height: 400),
        format: OutputFormat.jpeg,
        quality: 80,
        maxEdge: 300,
      );
      expect(result.size.width, 300);
      expect(result.size.height, 200);

      final untouched = EncodeOps.encodeImage(
        source: photo(width: 100, height: 80),
        format: OutputFormat.jpeg,
        quality: 80,
        maxEdge: 4000,
      );
      expect(untouched.size.width, 100);
    });

    test('flattens transparency for a format that has no alpha', () {
      final result = EncodeOps.encodeImage(
        source: transparent(),
        format: OutputFormat.jpeg,
        quality: 95,
      );
      final decoded = img.decodeImage(result.data!)!;
      // The transparent half must come out white, not black — the classic
      // "why is my logo on a black square" bug.
      final pixel = decoded.getPixel(35, 20);
      expect(pixel.r, greaterThan(200));
      expect(pixel.g, greaterThan(200));
      expect(pixel.b, greaterThan(200));
    });

    test('keeps transparency for a format that has it', () {
      final result = EncodeOps.encodeImage(
        source: transparent(),
        format: OutputFormat.png,
        quality: 100,
      );
      final decoded = img.decodeImage(result.data!)!;
      expect(decoded.getPixel(35, 20).a, 0);
    });

    test('reports every encode it performed', () {
      final result = EncodeOps.encodeImage(
        source: photo(width: 80, height: 60),
        format: OutputFormat.jpeg,
        quality: 80,
      );
      expect(result.samples, hasLength(1));
      expect(result.samples.single.bytes, result.bytes);
    });
  });

  // Decoding a JPEG and encoding it again at a sensible quality routinely
  // produces more bytes than the file had. An application called Shrink must
  // not hand that back.
  group('never larger than the source', () {
    /// A JPEG saved small, which is what re-encoding at 85 will inflate.
    SourceFile lowQualityJpeg(img.Image image) =>
        SourceFile.sniff(img.encodeJpg(image, quality: 30));

    test('a re-encode that gains nothing hands back the original', () {
      final image = photo();
      final original = lowQualityJpeg(image);

      final result = EncodeOps.encodeImage(
        source: image,
        original: original,
        format: OutputFormat.jpeg,
        quality: 85,
      );

      expect(result.keptOriginal, isTrue);
      expect(result.bytes, original.bytes.length);
      expect(result.data, same(original.bytes), reason: 'byte for byte');
      expect(result.budgetMet, isTrue);
    });

    test('the encode it threw away is still a measurement', () {
      final image = photo();
      final result = EncodeOps.encodeImage(
        source: image,
        original: lowQualityJpeg(image),
        format: OutputFormat.jpeg,
        quality: 85,
      );
      expect(result.samples, isNotEmpty);
      expect(result.samples.single.bytes, greaterThan(result.bytes));
    });

    test('an encode that does come out smaller is used', () {
      final image = photo();
      final original = SourceFile.sniff(img.encodeJpg(image, quality: 98));

      final result = EncodeOps.encodeImage(
        source: image,
        original: original,
        format: OutputFormat.jpeg,
        quality: 60,
      );

      expect(result.keptOriginal, isFalse);
      expect(result.bytes, lessThan(original.bytes.length));
    });

    test('a resize is always honoured, whatever it weighs', () {
      // Asked for 300 pixels, the answer is 300 pixels. The original is not a
      // substitute for an image of a different size.
      final image = photo();
      final result = EncodeOps.encodeImage(
        source: image,
        original: lowQualityJpeg(image),
        format: OutputFormat.jpeg,
        quality: 100,
        maxEdge: 300,
      );
      expect(result.keptOriginal, isFalse);
      expect(result.size.longestEdge, 300);
    });

    test('a change of format is always honoured', () {
      final image = photo(width: 120, height: 80);
      final result = EncodeOps.encodeImage(
        source: image,
        original: lowQualityJpeg(image),
        format: OutputFormat.png,
        quality: 85,
      );
      expect(result.keptOriginal, isFalse);
      expect(img.findFormatForData(result.data!), img.ImageFormat.png);
    });

    test('the format is read from the bytes, not from the name', () {
      // A PNG called .jpg: the caller resolves the target to JPEG from the
      // extension, and the file must not be passed off as one.
      final image = photo(width: 120, height: 80);
      final original = SourceFile.sniff(img.encodePng(image));
      expect(original.format, OutputFormat.png);

      final result = EncodeOps.encodeImage(
        source: image,
        original: original,
        format: OutputFormat.jpeg,
        quality: 100,
      );
      expect(result.keptOriginal, isFalse);
      expect(img.findFormatForData(result.data!), img.ImageFormat.jpg);
    });

    test('an original over the budget is not an answer to it', () {
      final image = photo();
      final original = lowQualityJpeg(image);
      final budget = original.bytes.length ~/ 2;

      final result = EncodeOps.encodeImage(
        source: image,
        original: original,
        format: OutputFormat.jpeg,
        quality: 85,
        maxBytes: budget,
      );

      expect(result.keptOriginal, isFalse);
      expect(result.bytes, lessThanOrEqualTo(budget));
    });

    test('an original already inside the budget is kept', () {
      final image = photo();
      final original = lowQualityJpeg(image);

      final result = EncodeOps.encodeImage(
        source: image,
        original: original,
        format: OutputFormat.jpeg,
        quality: 30,
        maxBytes: original.bytes.length * 4,
      );

      // Quality 30 again over a quality-30 file does not come out smaller.
      expect(result.bytes, lessThanOrEqualTo(original.bytes.length));
      expect(result.budgetMet, isTrue);
    });

    test('without the original, nothing changes', () {
      final image = photo();
      final result = EncodeOps.encodeImage(
        source: image,
        format: OutputFormat.jpeg,
        quality: 85,
      );
      expect(result.keptOriginal, isFalse);
    });
  });

  group('the byte budget', () {
    test('lowers quality until the file fits', () {
      final source = photo();
      final unconstrained = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.jpeg,
        quality: 95,
      );
      final budget = (unconstrained.bytes * 0.4).round();

      final result = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.jpeg,
        quality: 95,
        maxBytes: budget,
      );
      expect(result.budgetMet, isTrue);
      expect(result.bytes, lessThanOrEqualTo(budget));
      expect(result.quality, lessThan(95));
      // Dimensions should not have been touched: quality alone was enough.
      expect(result.size, unconstrained.size);
    });

    test('treats the requested quality as a ceiling, not a goal', () {
      // A generous budget must not entitle the search to encode at a higher
      // quality than the user asked for.
      final result = EncodeOps.encodeImage(
        source: photo(),
        format: OutputFormat.jpeg,
        quality: 60,
        maxBytes: 50 * 1000 * 1000,
      );
      expect(result.quality, 60);
      expect(result.samples, hasLength(1));
    });

    test('reduces dimensions once quality is exhausted', () {
      final source = photo();
      final floor = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.jpeg,
        quality: ResizeTarget.minQuality,
      );

      final result = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.jpeg,
        quality: 90,
        maxBytes: (floor.bytes * 0.5).round(),
      );
      expect(result.budgetMet, isTrue);
      expect(
        result.size.longestEdge,
        lessThan(source.width),
        reason: 'quality alone could not have fitted this',
      );
    });

    test('reaches a budget for a lossless format by shrinking', () {
      final source = photo(width: 400, height: 300);
      final full = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.png,
        quality: 100,
      );

      final result = EncodeOps.encodeImage(
        source: source,
        format: OutputFormat.png,
        quality: 100,
        maxBytes: (full.bytes * 0.3).round(),
      );
      expect(result.budgetMet, isTrue);
      expect(result.size.longestEdge, lessThan(400));
    });

    test('says so plainly when the budget cannot be met', () {
      final result = EncodeOps.encodeImage(
        source: photo(),
        format: OutputFormat.jpeg,
        quality: 90,
        maxBytes: 200,
      );
      expect(result.budgetMet, isFalse);
      // It still hands back the smallest thing it managed, rather than the
      // largest failure.
      expect(result.bytes, lessThan(20000));
    });

    test('stays inside its encode allowance', () {
      final result = EncodeOps.encodeImage(
        source: photo(),
        format: OutputFormat.jpeg,
        quality: 95,
        maxBytes: 3000,
      );
      expect(
        result.samples.length,
        lessThanOrEqualTo(EncodeOps.maxEncodeAttempts),
      );
    });
  });

  group('nextQuality', () {
    test('stays inside the bracket', () {
      final next = EncodeOps.nextQuality(
        bytes: 900000,
        budget: 100000,
        current: 90,
        ceiling: 90,
        highestFit: 40,
        lowestMiss: 90,
      );
      expect(next, greaterThan(40));
      expect(next, lessThan(90));
    });

    test('never exceeds the ceiling', () {
      final next = EncodeOps.nextQuality(
        bytes: 1000,
        budget: 5000000,
        current: 50,
        ceiling: 60,
        highestFit: 50,
        lowestMiss: null,
      );
      expect(next, lessThanOrEqualTo(60));
    });

    test('gives up when the bracket has closed', () {
      expect(
        EncodeOps.nextQuality(
          bytes: 900000,
          budget: 100000,
          current: 41,
          ceiling: 90,
          highestFit: 40,
          lowestMiss: 41,
        ),
        isNull,
      );
    });
  });
}
