import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import 'core/settings_controller.dart';
import 'core/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/app_shell.dart';

/// Root widget: theme, localisation and the window shell.
class ShrinkApp extends StatelessWidget {
  const ShrinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Installed here rather than around the MaterialApp because the
      // brightness that decides the palette is only known once themeMode and
      // the platform have been resolved, which happens inside it.
      builder: (context, child) => SlateTheme(
        data: AppTheme.slateFor(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
