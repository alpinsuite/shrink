import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/batch_controller.dart';
import '../controller/queue_controller.dart';
import '../core/fire_and_forget.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_actions.dart';
import 'app_shortcuts.dart';
import 'output_panel.dart';
import 'preview_panel.dart';
import 'queue_panel.dart';
import 'status_bar.dart';
import 'target_panel.dart';
import 'window_bar.dart';

/// The window: title bar, queue, preview, target and output, status bar.
///
/// The split is horizontal at the top level — the work on the left, the
/// decisions on the right — and vertical within the left, so the preview gets
/// real width. A preview squeezed into a 300-pixel side column would be too
/// small to judge compression by, which is the one thing it is for.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _dragging = false;

  /// Width of the settings column.
  ///
  /// Fixed rather than fractional: the controls in it have a natural width, and
  /// letting them stretch with the window puts a 700-pixel slider next to a
  /// two-word label.
  static const double _settingsWidth = 306;

  @override
  Widget build(BuildContext context) {
    return _ShortcutScope(
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                const WindowBar(),
                const SlateSeparator(),
                Expanded(
                  child: Row(
                    // Stretch, or the settings column sizes itself to its
                    // controls and floats in the vertical middle instead of
                    // filling the height.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _DropTarget(
                          dragging: _dragging,
                          onDraggingChanged: (value) =>
                              setState(() => _dragging = value),
                        ),
                      ),
                      const SlateSeparator(vertical: true),
                      const SizedBox(
                        width: _settingsWidth,
                        child: _SettingsColumn(),
                      ),
                    ],
                  ),
                ),
                const SlateSeparator(),
                const StatusBar(),
              ],
            ),
            // Above the content so the grips stay reachable where a panel
            // reaches the window edge.
            const WindowResizeEdges(),
          ],
        ),
      ),
    );
  }
}

/// The queue above, the preview below, with a draggable divider.
class _WorkArea extends StatelessWidget {
  const _WorkArea();

  @override
  Widget build(BuildContext context) {
    return const SlateSplitView(
      axis: Axis.vertical,
      // The queue is what gets scanned and the preview is what gets glanced
      // at, so the queue takes the larger share by default.
      initialFraction: 0.58,
      minStartExtent: 120,
      minEndExtent: 140,
      start: QueuePanel(),
      end: PreviewPanel(),
    );
  }
}

/// Target above, output below, scrollable so a short window still reaches both.
class _SettingsColumn extends StatelessWidget {
  const _SettingsColumn();

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return ColoredBox(
      color: theme.palette.panel,
      child: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[TargetPanel(), SlateSeparator(), OutputPanel()],
        ),
      ),
    );
  }
}

/// Wraps the work area so files dropped anywhere over it are added.
class _DropTarget extends StatelessWidget {
  const _DropTarget({required this.dragging, required this.onDraggingChanged});

  final bool dragging;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    return DropTarget(
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: (details) async {
        onDraggingChanged(false);
        final paths = details.files.map((file) => file.path).toList();
        if (paths.isEmpty) return;
        // Folders are walked and non-images filtered out by the queue, so
        // everything dropped can be handed over as-is.
        if (context.mounted) await AppActions(context).addDropped(paths);
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _WorkArea(),
          if (dragging)
            IgnorePointer(
              child: Container(
                color: theme.palette.accent.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: theme.popoverDecoration,
                  child: Text(l10n.dropHint, style: theme.textStyle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Application-wide keyboard shortcuts.
///
/// Registered above everything rather than on the queue, so they work whichever
/// panel has focus. Delete is withdrawn while a text field has focus — handling
/// it here would stop it reaching the field, and deleting the selected file
/// because someone was editing a suffix would be a genuinely bad surprise.
class _ShortcutScope extends StatelessWidget {
  const _ShortcutScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actions = AppActions(context);
    final running = context.watch<BatchController>().isRunning;
    final hasSelection = context.watch<QueueController>().selectedIndex >= 0;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        AppShortcuts.addFiles: () => fireAndForget(actions.addFiles()),
        AppShortcuts.addFolder: () => fireAndForget(actions.addFolder()),
        AppShortcuts.startOrCancel: actions.startOrCancel,
        if (hasSelection && !running)
          AppShortcuts.removeSelected: () {
            if (_isEditingText()) return;
            actions.removeSelected();
          },
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  /// True when a text field currently has focus.
  ///
  /// This scope sits *below* `WidgetsApp`, which is where Flutter installs the
  /// default text-editing shortcuts, so a binding here is nearer to the focused
  /// node and wins the key. Without this guard, pressing Delete while editing
  /// the suffix field would remove the selected file instead of a character —
  /// which is the sort of surprise that loses somebody's work.
  static bool _isEditingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
