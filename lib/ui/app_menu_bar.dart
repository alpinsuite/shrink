import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../controller/batch_controller.dart';
import '../controller/queue_controller.dart';
import '../core/fire_and_forget.dart';
import '../core/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_actions.dart';
import 'app_shortcuts.dart';
import 'shortcut_label.dart';

/// The application menu, drawn in-app rather than by the platform.
///
/// Flutter's `PlatformMenuBar` has no Linux backend, and an in-app menu keeps
/// one theme across the whole window on both targets.
///
/// The panels are built lazily by [SlateMenuButton], so the enabled state of
/// every command is read when the menu opens rather than captured when the bar
/// was last laid out.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // No height or background of its own: it is embedded in WindowBar, which
    // supplies both so the menus and the window buttons read as one bar.
    return SlateMenuBar(
      children: <Widget>[
        SlateMenuButton(label: l10n.menuFile, items: _fileMenu),
        SlateMenuButton(label: l10n.menuEdit, items: _editMenu),
        SlateMenuButton(label: l10n.menuView, items: _viewMenu),
        SlateMenuButton(label: l10n.menuHelp, items: _helpMenu),
      ],
    );
  }

  static List<Widget> _fileMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final batch = context.watch<BatchController>();
    final queue = context.watch<QueueController>();

    return <Widget>[
      SlateMenuItem(
        label: l10n.actionAddFiles,
        shortcut: shortcutLabel(l10n, AppShortcuts.addFiles),
        onPressed: () => fireAndForget(actions.addFiles()),
      ),
      SlateMenuItem(
        label: l10n.actionAddFolder,
        shortcut: shortcutLabel(l10n, AppShortcuts.addFolder),
        onPressed: () => fireAndForget(actions.addFolder()),
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(
        label: batch.isRunning ? l10n.actionCancel : l10n.actionStart,
        shortcut: shortcutLabel(l10n, AppShortcuts.startOrCancel),
        onPressed: batch.isRunning || actions.canStart
            ? actions.startOrCancel
            : null,
      ),
      SlateMenuItem(
        label: l10n.actionChooseOutputFolder,
        onPressed: () => fireAndForget(actions.chooseOutputFolder()),
      ),
      SlateMenuItem(
        label: l10n.actionRevealOutput,
        onPressed: queue.isEmpty
            ? null
            : () => fireAndForget(actions.revealOutput()),
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(
        label: l10n.actionQuit,
        shortcut: shortcutLabel(l10n, AppShortcuts.quit),
        onPressed: () => fireAndForget(windowManager.close()),
      ),
    ];
  }

  static List<Widget> _editMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final queue = context.watch<QueueController>();
    final batch = context.watch<BatchController>();

    return <Widget>[
      SlateMenuItem(
        label: l10n.actionRemoveSelected,
        shortcut: shortcutLabel(l10n, AppShortcuts.removeSelected),
        onPressed: queue.selectedIndex < 0 || batch.isRunning
            ? null
            : actions.removeSelected,
      ),
      SlateMenuItem(
        label: l10n.actionClearQueue,
        onPressed: queue.isEmpty || batch.isRunning ? null : actions.clearQueue,
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(
        label: l10n.actionResetTarget,
        onPressed: actions.resetTarget,
      ),
    ];
  }

  static List<Widget> _viewMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final mode = context.watch<SettingsController>().themeMode;

    return <Widget>[
      SlateSubmenu(
        label: l10n.menuTheme,
        items: (context) => <Widget>[
          for (final entry in <(ThemeMode, String)>[
            (ThemeMode.system, l10n.themeSystem),
            (ThemeMode.light, l10n.themeLight),
            (ThemeMode.dark, l10n.themeDark),
          ])
            SlateMenuItem(
              label: entry.$2,
              checked: mode == entry.$1,
              onPressed: () => fireAndForget(actions.setThemeMode(entry.$1)),
            ),
        ],
      ),
    ];
  }

  static List<Widget> _helpMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    return <Widget>[
      SlateMenuItem(label: l10n.actionAbout, onPressed: actions.showAbout),
    ];
  }
}
