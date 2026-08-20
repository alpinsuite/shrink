import 'package:flutter/foundation.dart';

/// Where the resized files go.
enum OutputDestination {
  /// Beside each source file. The suffix is what stops the output landing on
  /// top of the input.
  sameFolder,

  /// All of them into one chosen folder, keeping their own names.
  chosenFolder,
}

/// What to do when the output name is already taken.
enum CollisionPolicy {
  /// Append ` (2)`, ` (3)` … until the name is free. The safe default: nothing
  /// is lost, and a second run over the same folder is survivable.
  rename,

  /// Replace it. Never applied to a source file in the current batch.
  overwrite,

  /// Leave the existing file alone and report the source as skipped.
  skip,
}

/// Everything about *where* the batch writes, as opposed to *what* it writes.
@immutable
class OutputOptions {
  const OutputOptions({
    this.destination = OutputDestination.sameFolder,
    this.folder,
    this.suffix = defaultSuffix,
    this.collision = CollisionPolicy.rename,
  });

  /// Appended to the file stem when writing beside the source.
  static const String defaultSuffix = '-small';

  final OutputDestination destination;

  /// The chosen folder. Null until one is picked, which is why
  /// [OutputDestination.sameFolder] is the default — it needs no setup.
  final String? folder;

  final String suffix;

  final CollisionPolicy collision;

  /// True when the batch has everything it needs to start writing.
  bool get isReady =>
      destination == OutputDestination.sameFolder || folder != null;

  OutputOptions copyWith({
    OutputDestination? destination,
    String? folder,
    String? suffix,
    CollisionPolicy? collision,
  }) {
    return OutputOptions(
      destination: destination ?? this.destination,
      folder: folder ?? this.folder,
      suffix: suffix ?? this.suffix,
      collision: collision ?? this.collision,
    );
  }
}
