import 'package:flutter_test/flutter_test.dart';
import 'package:shrink/core/byte_format.dart';

void main() {
  group('format', () {
    test('uses the largest unit the value fits into', () {
      expect(ByteFormat.format(512), '512 B');
      expect(ByteFormat.format(1500), '1.5 KB');
      expect(ByteFormat.format(1400000), '1.4 MB');
      expect(ByteFormat.format(2500000000), '2.5 GB');
    });

    test('drops a trailing .0 rather than showing a false precision', () {
      expect(ByteFormat.format(2000), '2 KB');
      expect(ByteFormat.format(9000000), '9 MB');
    });

    test('stops showing decimals above ten', () {
      expect(ByteFormat.format(9400000), '9.4 MB');
      expect(ByteFormat.format(14300000), '14 MB');
    });
  });

  group('parse', () {
    test('reads a bare number as kilobytes', () {
      // Reading it as bytes would produce a budget no image could meet, and
      // would do so silently.
      expect(ByteFormat.parse('500'), 500 * ByteFormat.kb);
    });

    test('reads every unit spelling people actually type', () {
      expect(ByteFormat.parse('800 KB'), 800 * ByteFormat.kb);
      expect(ByteFormat.parse('800kb'), 800 * ByteFormat.kb);
      expect(ByteFormat.parse('800k'), 800 * ByteFormat.kb);
      expect(ByteFormat.parse('1.5 MB'), 1500000);
      expect(ByteFormat.parse('2m'), 2 * ByteFormat.mb);
      expect(ByteFormat.parse('900 b'), 900);
    });

    test('accepts a comma as a decimal separator', () {
      expect(ByteFormat.parse('1,5 MB'), 1500000);
    });

    test('rejects what it cannot understand', () {
      expect(ByteFormat.parse(''), isNull);
      expect(ByteFormat.parse('lots'), isNull);
      expect(ByteFormat.parse('12 furlongs'), isNull);
      expect(ByteFormat.parse('-3 MB'), isNull);
    });

    test('round-trips everything format produces', () {
      // The pairing is the point: a format the parser cannot read back is the
      // bug these two functions live in the same file to prevent.
      for (final bytes in <int>[
        512,
        1500,
        25000,
        800000,
        1400000,
        9400000,
        14000000,
      ]) {
        final text = ByteFormat.format(bytes);
        expect(
          ByteFormat.parse(text),
          isNotNull,
          reason: 'could not parse back "$text"',
        );
      }
    });
  });
}
