/// Turning byte counts into text a person reads, and back again.
///
/// The file-size field is the one control in this application that a user types
/// a *unit* into — "800 KB", "1.5 MB" — so the parse has to be as forgiving as
/// the format is tidy. Both live here, together, because a format the parser
/// cannot read back is the bug this pairing exists to prevent.
///
/// Units are the decimal ones (1 KB = 1000 bytes), matching what every file
/// manager on both target platforms reports and, more to the point, what the
/// services people are trying to squeeze under actually mean by "2 MB".
library;

abstract final class ByteFormat {
  static const int kb = 1000;
  static const int mb = 1000 * kb;
  static const int gb = 1000 * mb;

  /// `1400000` → `'1.4 MB'`.
  ///
  /// The precision shrinks as the number grows: three significant figures are
  /// noise on a file size, and a queue column full of `1.437 MB` is a column
  /// nobody can scan.
  static String format(int bytes) {
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${_round(bytes / kb)} KB';
    if (bytes < gb) return '${_round(bytes / mb)} MB';
    return '${_round(bytes / gb)} GB';
  }

  /// One decimal place below 10, none above — `9.4 MB`, but `14 MB`.
  static String _round(double value) {
    if (value < 10) {
      final text = value.toStringAsFixed(1);
      // 9.0 reads as a measurement that happened to land on a round number;
      // 9 reads as the number it is.
      return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
    }
    return value.round().toString();
  }

  /// `'800 kb'`, `'1.5 MB'`, `'2m'`, `'512000'` → bytes, or null.
  ///
  /// A bare number is read as **kilobytes**, not bytes. Nobody types a file
  /// size budget in bytes, and reading `500` as half a kilobyte would produce a
  /// target no image can meet, silently.
  static int? parse(String text) {
    final trimmed = text.trim().toLowerCase().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'^([0-9]*\.?[0-9]+)\s*([a-z]*)$').firstMatch(trimmed);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null || value < 0) return null;

    final multiplier = switch (match.group(2)!) {
      '' || 'k' || 'kb' || 'kib' => kb,
      'b' => 1,
      'm' || 'mb' || 'mib' => mb,
      'g' || 'gb' || 'gib' => gb,
      _ => null,
    };
    if (multiplier == null) return null;

    return (value * multiplier).round();
  }
}
