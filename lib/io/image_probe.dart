/// Reading an image's dimensions and size without decoding its pixels.
///
/// A dropped folder can be hundreds of files, and fully decoding every one of
/// them to fill in a queue column would take minutes and a great deal of memory
/// for information that lives in the first few hundred bytes of each file.
/// `startDecode` reads the header and stops.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../model/pixel_size.dart';

/// What a source file turned out to be.
@immutable
class ProbeResult {
  const ProbeResult({required this.size, required this.bytes});

  final PixelSize size;
  final int bytes;
}

abstract final class ImageProbe {
  /// Dimensions and byte length for the file at [path], or null when it is not
  /// an image this application can read.
  ///
  /// Runs the header parse on a worker isolate: for a few hundred files the
  /// parsing itself is trivial but the file reads are not, and doing them on
  /// the platform thread is how a drag-and-drop of a photo folder freezes the
  /// window for several seconds.
  static Future<ProbeResult?> probe(String path) => compute(_probe, path);

  static ProbeResult? _probe(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;

    final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      return null;
    }

    final decoder =
        img.findDecoderForNamedImage(path) ?? img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width < 1 || info.height < 1) return null;

    // EXIF orientation is applied before anything is written, so a portrait
    // photograph stored as landscape has to be reported the way it will come
    // out. Without this the queue shows 4000×3000 for a file the batch writes
    // as 3000×4000.
    final swapped = _hasSwappedAxes(bytes);
    return ProbeResult(
      size: swapped
          ? PixelSize(info.height, info.width)
          : PixelSize(info.width, info.height),
      bytes: bytes.length,
    );
  }

  /// True when the EXIF orientation tag rotates the image by a quarter turn.
  ///
  /// Values 5 to 8 are the transposed ones. Only JPEG and TIFF carry the tag,
  /// and `decodeJpgExif` reads the header segments rather than the image.
  static bool _hasSwappedAxes(Uint8List bytes) {
    try {
      final exif = img.decodeJpgExif(bytes);
      if (exif == null || !exif.imageIfd.hasOrientation) return false;
      final orientation = exif.imageIfd.orientation ?? 1;
      return orientation >= 5 && orientation <= 8;
    } catch (_) {
      // A malformed EXIF block is not a reason to refuse the file — the
      // dimensions read fine without it.
      return false;
    }
  }
}
