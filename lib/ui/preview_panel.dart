import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/estimate_controller.dart';
import '../controller/queue_controller.dart';
import '../controller/target_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/batch_item.dart';
import 'preview_comparison.dart';
import 'preview_overlay.dart';

/// The selected file, before and after.
///
/// This panel is not decoration. It is where the *measurement* behind every
/// recommendation happens: what it draws is the real encoded output at the
/// current settings, and the size beneath it is that file's actual byte count.
/// Everything the target panel suggests is derived from encodes performed to
/// put a picture here.
///
/// It is deliberately modest in size — the queue is what gets used most — and
/// enlarges on demand, because judging whether a quality setting has gone too
/// far needs the picture bigger than a panel this shape can be.
class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final estimates = context.watch<EstimateController>();
    final item = context.watch<QueueController>().selected;
    final target = context.watch<TargetController>().target;

    final showable =
        item != null &&
        item.status != BatchItemStatus.unreadable &&
        target.format.resolve(item.path) != null;

    final Widget body;
    if (item == null) {
      body = _Message(text: l10n.previewNoSelection);
    } else if (item.status == BatchItemStatus.unreadable) {
      body = _Message(text: l10n.failureUnreadable);
    } else if (!showable) {
      // Readable but not writable — a WebP or a PSD under "same as source".
      body = _Message(text: l10n.previewUnwritable);
    } else {
      body = PreviewComparison(
        item: item,
        estimates: estimates,
        onTapPane: () => showPreviewOverlay(context),
      );
    }

    return SlateSidePanel(
      title: l10n.panelPreview,
      actions: <Widget>[
        if (estimates.isMeasuring)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(l10n.previewMeasuring, style: theme.dimTextStyle),
          ),
        SlateIconButton(
          icon: SlateIcons.fitScreen,
          tooltip: l10n.actionEnlargePreview,
          size: 22,
          onPressed: showable ? () => showPreviewOverlay(context) : null,
        ),
      ],
      child: Padding(padding: EdgeInsets.all(theme.metrics.pad), child: body),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return Center(child: Text(text, style: theme.dimTextStyle));
  }
}
