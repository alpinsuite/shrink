import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/batch_controller.dart';
import '../controller/queue_controller.dart';
import '../core/byte_format.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_actions.dart';

/// The bottom edge: what is in the queue, what the last run did, and Start.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final queue = context.watch<QueueController>();
    final batch = context.watch<BatchController>();
    final actions = AppActions(context);

    return Container(
      height: theme.metrics.barHeight,
      color: theme.palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: <Widget>[
          Text(l10n.queueCount(queue.length), style: theme.dimTextStyle),
          if (queue.totalSourceBytes > 0) ...<Widget>[
            const SizedBox(width: 8),
            const SlateSeparator(vertical: true, inset: 7),
            const SizedBox(width: 8),
            Text(
              ByteFormat.format(queue.totalSourceBytes),
              style: theme.dimTextStyle,
            ),
          ],
          const Spacer(),
          const _Outcome(),
          const SizedBox(width: 10),
          if (batch.isRunning) ...<Widget>[
            SizedBox(width: 120, child: _Progress(value: batch.progress ?? 0)),
            const SizedBox(width: 8),
            Text(
              l10n.batchProgress(batch.completed, batch.total),
              style: theme.dimTextStyle,
            ),
            const SizedBox(width: 10),
          ],
          SlateButton(
            kind: batch.isRunning
                ? SlateButtonKind.secondary
                : SlateButtonKind.primary,
            icon: batch.isRunning ? SlateIcons.pause : SlateIcons.play,
            label: batch.isRunning ? l10n.actionCancel : l10n.actionStart,
            // Cancelling twice does nothing, so the button stops offering it.
            onPressed:
                batch.state == BatchState.cancelling ||
                    (!batch.isRunning && !actions.canStart)
                ? null
                : actions.startOrCancel,
          ),
        ],
      ),
    );
  }
}

/// What the last run did, once it is over.
///
/// Reads as a sentence rather than a table — "14 written · 2 skipped ·
/// 18.2 MB saved" — because it is glanced at, not studied.
class _Outcome extends StatelessWidget {
  const _Outcome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final batch = context.watch<BatchController>();
    if (batch.state != BatchState.finished) return const SizedBox.shrink();

    final summary = batch.summary;
    final saved = summary.savedFraction;
    final savedBytes = summary.inputBytes - summary.outputBytes;

    final parts = <String>[
      if (summary.cancelled) l10n.summaryCancelled,
      l10n.summaryWritten(summary.written),
      if (summary.skipped > 0) l10n.summarySkipped(summary.skipped),
      if (summary.failed > 0) l10n.summaryFailed(summary.failed),
      if (summary.missedBudget > 0)
        l10n.summaryOverBudget(summary.missedBudget),
      if (saved != null && savedBytes > 0)
        l10n.summarySaved(ByteFormat.format(savedBytes))
      else if (summary.written > 0)
        l10n.summaryNoChange,
    ];

    final failed = summary.failed > 0 || summary.missedBudget > 0;
    return Text(
      parts.join('  ·  '),
      style: theme.dimTextStyle.copyWith(
        color: failed ? theme.palette.danger : theme.palette.inkDim,
      ),
    );
  }
}

/// A flat progress bar in the kit's colours.
///
/// Not a `LinearProgressIndicator`: Material's animates its own indeterminate
/// state and carries a rounded track that reads as a different piece of
/// software next to a hairline-ruled status bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return SizedBox(
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: <Widget>[
            Container(color: theme.palette.field),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(color: theme.palette.accent),
            ),
          ],
        ),
      ),
    );
  }
}
