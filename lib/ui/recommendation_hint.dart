import 'package:flutter/material.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/estimate_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'labels.dart';

/// The line beneath a control that says what it *could* be.
///
/// Deliberately not a control that changes itself. A slider that moved because
/// another slider moved would leave nobody able to say what they had actually
/// asked for; this states the consequence and offers to act on it, and the
/// decision stays with the user.
///
/// Quiet at rest — dim text, no border, no background — and the accent only
/// arrives on the word that does something.
class RecommendationHint extends StatelessWidget {
  const RecommendationHint({
    required this.recommendation,
    required this.onApply,
    super.key,
  });

  final Recommendation? recommendation;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    final recommendation = this.recommendation;
    // Collapses to nothing rather than reserving a blank line: an empty row
    // under every control is what makes a dense panel look padded.
    if (recommendation == null) return const SizedBox.shrink();

    final theme = context.slate;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              recommendation.labelFor(l10n),
              style: theme.dimTextStyle,
            ),
          ),
          const SizedBox(width: 6),
          _ApplyLink(
            label: l10n.actionApply,
            onPressed: () => onApply(recommendation.value),
          ),
        ],
      ),
    );
  }
}

/// A word that acts, rather than a button.
///
/// A [SlateButton] here would be a third heavy shape in a row that already has
/// a slider and a field, and this is a suggestion, not a command — it should
/// read as part of the sentence it follows.
class _ApplyLink extends StatefulWidget {
  const _ApplyLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_ApplyLink> createState() => _ApplyLinkState();
}

class _ApplyLinkState extends State<_ApplyLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Text(
          widget.label,
          style: theme.dimTextStyle.copyWith(
            color: theme.palette.accent,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: theme.palette.accent,
          ),
        ),
      ),
    );
  }
}
