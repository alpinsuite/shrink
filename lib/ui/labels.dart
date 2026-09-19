/// Turning the model's enums into text.
///
/// The model layer deliberately holds no user-facing strings — a status is a
/// value, not a sentence — so every enum needs exactly one place that phrases
/// it. Collecting those here keeps the switch statements out of the widgets and
/// guarantees a status reads the same in the queue as it does in the status bar.
library;

import '../controller/estimate_controller.dart';
import '../core/byte_format.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/batch_item.dart';
import '../model/output_format.dart';
import '../model/output_options.dart';

extension FormatLabel on OutputFormat {
  /// The name for the format list. Every format but one is a proper noun and
  /// needs no translation; "same as source" is a phrase and does.
  String labelFor(AppLocalizations l10n) =>
      this == OutputFormat.sameAsSource ? l10n.formatSameAsSource : label;
}

extension BatchItemStatusLabel on BatchItemStatus {
  String labelFor(AppLocalizations l10n) => switch (this) {
    BatchItemStatus.probing => l10n.statusProbing,
    BatchItemStatus.ready => l10n.statusReady,
    BatchItemStatus.unreadable => l10n.statusUnreadable,
    BatchItemStatus.running => l10n.statusRunning,
    BatchItemStatus.done => l10n.statusDone,
    BatchItemStatus.skipped => l10n.statusSkipped,
    BatchItemStatus.failed => l10n.statusFailed,
  };
}

extension BatchItemFailureLabel on BatchItemFailure {
  String labelFor(AppLocalizations l10n) => switch (this) {
    BatchItemFailure.unreadable => l10n.failureUnreadable,
    BatchItemFailure.noEncoder => l10n.failureNoEncoder,
    BatchItemFailure.io => l10n.failureIo,
  };
}

extension OutputDestinationLabel on OutputDestination {
  String labelFor(AppLocalizations l10n) => switch (this) {
    OutputDestination.sameFolder => l10n.outputSameFolder,
    OutputDestination.chosenFolder => l10n.outputChosenFolder,
  };
}

extension CollisionPolicyLabel on CollisionPolicy {
  String labelFor(AppLocalizations l10n) => switch (this) {
    CollisionPolicy.rename => l10n.collisionRename,
    CollisionPolicy.overwrite => l10n.collisionOverwrite,
    CollisionPolicy.skip => l10n.collisionSkip,
  };
}

extension RecommendationLabel on Recommendation {
  /// The sentence shown beneath the control being recommended for.
  ///
  /// The reason decides the phrasing, because "quality 62 would fit" and
  /// "quality alone will not fit it" are different pieces of news even though
  /// both arrive as a number.
  String labelFor(AppLocalizations l10n) => switch (reason) {
    RecommendationReason.qualityForBudget => l10n.recommendQualityForBudget(
      value,
    ),
    RecommendationReason.edgeForBudget => l10n.recommendEdgeForBudget(value),
    RecommendationReason.edgeBecauseQualityExhausted =>
      l10n.recommendEdgeQualityExhausted(value),
    RecommendationReason.budgetForCurrentSettings => l10n.recommendBudget(
      ByteFormat.format(value),
    ),
  };
}
