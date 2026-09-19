import 'package:flutter/material.dart';
import 'package:slate_ui/slate_ui.dart';

import '../core/app_version.dart';
import '../l10n/generated/app_localizations.dart';

/// What the application is and which version of it this is.
Future<void> showAboutShrinkDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    return SlateDialog(
      title: l10n.actionAbout,
      width: 380,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.appTagline, style: theme.textStyle),
          const SizedBox(height: 2),
          Text(l10n.aboutVersion(appVersion), style: theme.dimTextStyle),
          const SizedBox(height: 12),
          Text(l10n.aboutDescription, style: theme.textStyle),
          const SizedBox(height: 12),
          Text(l10n.aboutBuiltWith, style: theme.dimTextStyle),
        ],
      ),
      actions: <Widget>[
        SlateButton(
          kind: SlateButtonKind.primary,
          label: l10n.buttonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
