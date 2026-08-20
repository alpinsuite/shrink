/// The formats the batch can write, and the ones it can read.
///
/// Shaped after paint's `ImageFormatInfo`: what a format *can do* is data on
/// the format itself, so the interface can disable a quality slider or warn
/// about a lost alpha channel without a switch statement in a widget.
library;

import 'package:path/path.dart' as p;

/// A target format for the batch.
///
/// [sameAsSource] is not a format — it defers to whatever each file already is,
/// which is what someone resizing a mixed folder almost always wants.
enum OutputFormat {
  /// Each file keeps its own format. A file in a format that cannot be written
  /// (WebP, PSD) fails with a message rather than being written as something
  /// else behind the user's back.
  sameAsSource(label: '', extension: '', hasQuality: true, supportsAlpha: true),

  /// The only format here with a real quality knob, and the reason the byte
  /// budget can usually be met without touching dimensions.
  jpeg(label: 'JPEG', extension: 'jpg', hasQuality: true, supportsAlpha: false),

  png(label: 'PNG', extension: 'png', hasQuality: false, supportsAlpha: true),

  tiff(label: 'TIFF', extension: 'tif', hasQuality: false, supportsAlpha: true),

  bmp(label: 'BMP', extension: 'bmp', hasQuality: false, supportsAlpha: false),

  tga(label: 'TGA', extension: 'tga', hasQuality: false, supportsAlpha: true),

  /// Palettised to 256 colours. No quality knob, and photographic input comes
  /// out visibly banded — offered because a resizer that cannot produce a GIF
  /// is missing a format people still ask for.
  gif(label: 'GIF', extension: 'gif', hasQuality: false, supportsAlpha: true);

  const OutputFormat({
    required this.label,
    required this.extension,
    required this.hasQuality,
    required this.supportsAlpha,
  });

  /// The name as it appears in the format list. Empty for [sameAsSource],
  /// whose label is a translated phrase rather than a proper noun and so is
  /// supplied by the interface.
  final String label;

  /// Written without a leading dot. Empty for [sameAsSource].
  final String extension;

  /// Whether the quality control does anything. False for every lossless
  /// format, and for GIF, which quantises instead.
  final bool hasQuality;

  /// False means transparent pixels have to be composited onto a background
  /// before encoding, or they come out black.
  final bool supportsAlpha;

  /// The formats offered as a target, [sameAsSource] first.
  ///
  /// WebP is deliberately absent. `package:image` can only encode it losslessly
  /// — its `WebPEncoder` takes no quality argument at all — so offering it
  /// would mean offering a format that silently ignores the quality slider and,
  /// on photographs, usually produces a *larger* file than the JPEG it
  /// replaced. It stays a format this application reads.
  static const List<OutputFormat> targets = OutputFormat.values;

  /// True when the batch can write this format for a source at [sourcePath].
  bool canWrite(String sourcePath) => resolve(sourcePath) != null;

  /// The concrete format to encode a file at [sourcePath] as.
  ///
  /// Null only when this is [sameAsSource] and the source is in a format with
  /// no encoder — WebP and PSD, which this application reads but cannot write.
  OutputFormat? resolve(String sourcePath) {
    if (this != sameAsSource) return this;
    return forExtension(p.extension(sourcePath));
  }

  /// The writable format an extension names, or null.
  static OutputFormat? forExtension(String extension) {
    final normalised = extension.toLowerCase().replaceFirst('.', '');
    return switch (normalised) {
      'jpg' || 'jpeg' || 'jpe' => jpeg,
      'png' => png,
      'tif' || 'tiff' => tiff,
      'bmp' => bmp,
      'tga' => tga,
      'gif' => gif,
      _ => null,
    };
  }

  /// Every extension the batch can decode, for the open dialog's filter and for
  /// deciding what a dropped folder contains.
  ///
  /// Wider than the writable set: WebP, PSD and the Netpbm family read fine.
  static const List<String> readableExtensions = <String>[
    'jpg',
    'jpeg',
    'jpe',
    'png',
    'webp',
    'gif',
    'bmp',
    'tif',
    'tiff',
    'tga',
    'ico',
    'psd',
    'pnm',
    'pbm',
    'pgm',
    'ppm',
    'exr',
  ];

  static bool isReadable(String path) => readableExtensions.contains(
    p.extension(path).toLowerCase().replaceFirst('.', ''),
  );
}
