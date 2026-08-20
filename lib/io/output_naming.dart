/// Deciding what each output file is called and where it lands.
///
/// Pure path arithmetic plus one existence check, kept away from the batch so
/// the rules can be asserted without writing anything to a disk.
///
/// One rule outranks every setting here: **a source file in the batch is never
/// overwritten.** Not by its own output, not by another file's. Someone
/// resizing a folder of photographs in place, with the originals as the only
/// copy, must not be able to destroy them by leaving a suffix field empty.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/output_format.dart';
import '../model/output_options.dart';

/// Where a file is going, or why it is not.
class OutputPlan {
  const OutputPlan.write(this.path) : skipped = false;

  const OutputPlan.skip() : path = null, skipped = true;

  /// Null only when [skipped].
  final String? path;

  /// The name was taken and the policy said to leave it alone.
  final bool skipped;
}

abstract final class OutputNaming {
  /// Characters Windows refuses in a filename. Linux only objects to `/` and
  /// NUL, but a suffix that works on one platform and silently fails on the
  /// other is worse than one rule applied everywhere.
  static final RegExp _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  /// Strips what a filesystem will not accept from a user-typed suffix.
  static String sanitiseSuffix(String suffix) =>
      suffix.replaceAll(_illegal, '').trim();

  /// The path [sourcePath] would be written to, before any collision check.
  ///
  /// [format] must already be resolved: the extension is half the answer.
  static String destinationFor({
    required String sourcePath,
    required OutputFormat format,
    required OutputOptions options,
  }) {
    final stem = p.basenameWithoutExtension(sourcePath);
    final suffix = sanitiseSuffix(options.suffix);
    final directory = switch (options.destination) {
      OutputDestination.sameFolder => p.dirname(sourcePath),
      OutputDestination.chosenFolder => options.folder ?? p.dirname(sourcePath),
    };
    return p.join(directory, '$stem$suffix.${format.extension}');
  }

  /// The final path, with the collision policy applied.
  ///
  /// [protected] is every source path in the batch. A candidate that collides
  /// with one of them is renamed regardless of the policy — see the rule at the
  /// top of this file.
  static OutputPlan resolve({
    required String candidate,
    required OutputOptions options,
    required Set<String> protected,
    bool Function(String path)? exists,
  }) {
    final onDisk = exists ?? (path) => File(path).existsSync();
    final isSource = _contains(protected, candidate);

    if (!onDisk(candidate) && !isSource) return OutputPlan.write(candidate);

    if (!isSource) {
      switch (options.collision) {
        case CollisionPolicy.overwrite:
          return OutputPlan.write(candidate);
        case CollisionPolicy.skip:
          return const OutputPlan.skip();
        case CollisionPolicy.rename:
          break;
      }
    }

    final directory = p.dirname(candidate);
    final stem = p.basenameWithoutExtension(candidate);
    final extension = p.extension(candidate);
    // Two is where a person starts counting copies, and the cap is high enough
    // that reaching it means something is wrong rather than that the folder is
    // busy.
    for (var index = 2; index < 1000; index++) {
      final attempt = p.join(directory, '$stem ($index)$extension');
      if (!onDisk(attempt) && !_contains(protected, attempt)) {
        return OutputPlan.write(attempt);
      }
    }
    return const OutputPlan.skip();
  }

  /// Path comparison that matches how the host filesystem actually behaves.
  ///
  /// Windows paths are case-insensitive, so `Photo.JPG` and `photo.jpg` are the
  /// same file there and two different files on Linux. Comparing them the same
  /// way on both would either let Windows overwrite a source or make Linux
  /// rename a file it did not need to.
  static bool _contains(Set<String> paths, String candidate) {
    final normalised = p.normalize(p.absolute(candidate));
    for (final path in paths) {
      if (p.equals(path, normalised)) return true;
    }
    return false;
  }
}
