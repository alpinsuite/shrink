import 'package:flutter/foundation.dart';

import '../core/byte_format.dart';
import '../ops/resize_ops.dart';
import 'output_format.dart';

/// What the user is asking for, as four independent constraints.
///
/// The whole application is a machine for satisfying this object. Each of the
/// three optional constraints can be switched off — a null [maxEdge] means "do
/// not cap the dimensions", not "cap them at zero" — and [quality] only matters
/// for a format that has one.
///
/// Immutable, so a target can be handed to an isolate, compared for equality to
/// decide whether an estimate is stale, and stored in preferences without any
/// of the three having to agree about who owns it.
@immutable
class ResizeTarget {
  const ResizeTarget({
    this.format = OutputFormat.sameAsSource,
    this.maxEdge,
    this.quality = defaultQuality,
    this.maxBytes,
  });

  /// A visually near-lossless JPEG for most content, and the value most tools
  /// settle on. High enough that the first thing a user does is not "turn it
  /// back up".
  static const int defaultQuality = 85;

  /// The longest edge a first launch starts with, switched on.
  ///
  /// With every constraint off, Start re-encodes each file at the size it
  /// already is, which makes nothing meaningfully smaller: the one thing the
  /// application is opened for would not happen until a box was ticked. 1600
  /// pixels is comfortably more than a screen shows and a fraction of what a
  /// camera produces. It applies once — after the first change to the target,
  /// what was saved is what is used, including an edge deliberately turned off.
  static const int firstLaunchMaxEdge = 1600;

  static const int minQuality = 1;
  static const int maxQuality = 100;

  /// The lowest quality a *recommendation* will suggest.
  ///
  /// Below this JPEG artefacts stop being a trade-off and start being the
  /// subject of the picture, so the recommender switches to reducing dimensions
  /// instead — which is almost always what a person would have chosen. The
  /// batch itself may still go lower, but only after dimensions have been tried.
  static const int recommendedQualityFloor = 40;

  /// Bounds for the file-size budget control. The floor is a small thumbnail;
  /// the ceiling is past the point where anyone is still trying to fit under
  /// an upload limit.
  static const int minBudget = 10 * ByteFormat.kb;
  static const int maxBudget = 50 * ByteFormat.mb;

  final OutputFormat format;

  /// Longest edge in pixels, or null for no dimension cap.
  final int? maxEdge;

  /// 1–100. Ignored by formats where [OutputFormat.hasQuality] is false.
  final int quality;

  /// File size ceiling in bytes, or null for no size budget.
  final int? maxBytes;

  /// Whether the quality control does anything for the chosen format.
  ///
  /// [OutputFormat.sameAsSource] answers true: a mixed batch may well contain
  /// JPEGs, and greying the slider out because the *first* file is a PNG would
  /// be wrong for every other file in the queue.
  bool get qualityApplies => format.hasQuality;

  /// True when nothing has been asked for and the batch would be a copy.
  bool get isNoOp =>
      format == OutputFormat.sameAsSource &&
      maxEdge == null &&
      maxBytes == null;

  ResizeTarget copyWith({OutputFormat? format, int? quality}) {
    return ResizeTarget(
      format: format ?? this.format,
      maxEdge: maxEdge,
      quality: (quality ?? this.quality).clamp(minQuality, maxQuality),
      maxBytes: maxBytes,
    );
  }

  /// Separate from [copyWith] on purpose: for a nullable field, "not passed"
  /// and "passed null" are different intentions, and a single `copyWith` cannot
  /// tell them apart without a sentinel that reads worse than this does.
  ResizeTarget withMaxEdge(int? value) {
    return ResizeTarget(
      format: format,
      maxEdge: value?.clamp(ResizeOps.minEdge, ResizeOps.maxEdge),
      quality: quality,
      maxBytes: maxBytes,
    );
  }

  ResizeTarget withMaxBytes(int? value) {
    return ResizeTarget(
      format: format,
      maxEdge: maxEdge,
      quality: quality,
      maxBytes: value?.clamp(minBudget, maxBudget),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ResizeTarget &&
      other.format == format &&
      other.maxEdge == maxEdge &&
      other.quality == quality &&
      other.maxBytes == maxBytes;

  @override
  int get hashCode => Object.hash(format, maxEdge, quality, maxBytes);

  @override
  String toString() =>
      'ResizeTarget(${format.name}, edge: $maxEdge, q: $quality, '
      'bytes: $maxBytes)';
}
