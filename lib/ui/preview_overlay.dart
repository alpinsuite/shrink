import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/estimate_controller.dart';
import '../controller/queue_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'preview_comparison.dart';

/// The before-and-after, filling the window.
///
/// The panel version is big enough to see *that* something changed; judging
/// whether a quality setting has gone too far needs the picture at a size worth
/// looking at. This is that size, and it can put either half across the full
/// width for the cases where side-by-side halves are still too small.
///
/// A route rather than a resizable panel: it is a thing you open, look at, and
/// close, and giving it a persistent place in the layout would cost the queue
/// the space it needs the rest of the time.
Future<void> showPreviewOverlay(BuildContext context) {
  return showDialog<void>(
    context: context,
    // The picture is the point; the dimmed window behind it is not.
    barrierColor: const Color(0x99000000),
    builder: (context) => const _PreviewOverlay(),
  );
}

class _PreviewOverlay extends StatefulWidget {
  const _PreviewOverlay();

  @override
  State<_PreviewOverlay> createState() => _PreviewOverlayState();
}

class _PreviewOverlayState extends State<_PreviewOverlay> {
  PreviewMode _mode = PreviewMode.both;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final estimates = context.watch<EstimateController>();
    final item = context.watch<QueueController>().selected;

    // The selection can be cleared while this is open — the file was removed,
    // or the list was cleared from the menu behind it.
    if (item == null) return const SizedBox.shrink();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: const Color(0x00000000),
          elevation: 0,
          // Nearly the whole window: anything smaller and this is not doing the
          // one thing it exists for.
          insetPadding: const EdgeInsets.all(28),
          child: Container(
            decoration: theme.popoverDecoration,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  name: item.name,
                  mode: _mode,
                  measuring: estimates.isMeasuring,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                ),
                const SlateSeparator(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(theme.metrics.pad + 2),
                    child: PreviewComparison(
                      item: item,
                      estimates: estimates,
                      mode: _mode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.mode,
    required this.measuring,
    required this.onModeChanged,
  });

  final String name;
  final PreviewMode mode;
  final bool measuring;
  final ValueChanged<PreviewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    return Container(
      height: theme.metrics.barHeight + 4,
      color: theme.palette.panel,
      padding: EdgeInsets.symmetric(horizontal: theme.metrics.pad),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.titleStyle,
            ),
          ),
          if (measuring) ...<Widget>[
            Text(l10n.previewMeasuring, style: theme.dimTextStyle),
            const SizedBox(width: 10),
          ],
          SlateSegmented<PreviewMode>(
            value: mode,
            values: PreviewMode.values,
            labelOf: (mode) => switch (mode) {
              PreviewMode.both => l10n.previewShowBoth,
              PreviewMode.original => l10n.previewOriginal,
              PreviewMode.result => l10n.previewResult,
            },
            onChanged: onModeChanged,
          ),
          const SizedBox(width: 10),
          SlateIconButton(
            icon: SlateIcons.close,
            tooltip: l10n.buttonClose,
            size: 24,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
