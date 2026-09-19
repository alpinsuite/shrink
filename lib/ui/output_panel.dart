import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/target_controller.dart';
import '../core/fire_and_forget.dart';
import '../io/output_naming.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/output_options.dart';
import 'app_actions.dart';
import 'labels.dart';

/// Where the resized files go, and what they are called.
class OutputPanel extends StatelessWidget {
  const OutputPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final controller = context.watch<TargetController>();
    final actions = AppActions(context);
    final options = controller.output;

    return SlateSidePanel(
      title: l10n.panelOutput,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.metrics.pad,
          theme.metrics.pad,
          theme.metrics.pad,
          theme.metrics.pad + 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SlateSegmented<OutputDestination>(
              value: options.destination,
              values: OutputDestination.values,
              labelOf: (destination) => destination.labelFor(l10n),
              onChanged: (destination) => controller.output = options.copyWith(
                destination: destination,
              ),
            ),
            const SizedBox(height: 12),
            if (options.destination == OutputDestination.chosenFolder)
              SlateLabeledField(
                label: l10n.fieldFolder,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Tooltip(
                        message: options.folder ?? l10n.outputNoFolder,
                        child: Text(
                          options.folder ?? l10n.outputNoFolder,
                          overflow: TextOverflow.ellipsis,
                          // Reversed so a long path elides at the *front* and
                          // the folder's own name — the part anyone is looking
                          // for — stays visible.
                          textDirection: TextDirection.rtl,
                          style: options.folder == null
                              ? theme.dimTextStyle.copyWith(
                                  color: theme.palette.danger,
                                )
                              : theme.dimTextStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SlateButton(
                      label: l10n.actionBrowse,
                      onPressed: () =>
                          fireAndForget(actions.chooseOutputFolder()),
                    ),
                  ],
                ),
              )
            else
              _SuffixField(controller: controller),
            const SizedBox(height: 12),
            SlateLabeledField(
              label: l10n.fieldCollision,
              child: SlateSelect<CollisionPolicy>(
                value: options.collision,
                values: CollisionPolicy.values,
                labelOf: (policy) => policy.labelFor(l10n),
                onChanged: (policy) =>
                    controller.output = options.copyWith(collision: policy),
              ),
            ),
            const SizedBox(height: 8),
            // Worth stating outright, because "Replace it" reads as though it
            // might. It cannot: `OutputNaming` renames around any path that is
            // a source in the current batch.
            Text(l10n.outputNeverOverwritesSource, style: theme.dimTextStyle),
          ],
        ),
      ),
    );
  }
}

/// The text appended to each file's name when writing beside the originals.
class _SuffixField extends StatefulWidget {
  const _SuffixField({required this.controller});

  final TargetController controller;

  @override
  State<_SuffixField> createState() => _SuffixFieldState();
}

class _SuffixFieldState extends State<_SuffixField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.output.suffix,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SlateLabeledField(
      label: l10n.fieldSuffix,
      child: SlateField(
        controller: _text,
        // Sanitised on the way in rather than on the way out, so the field
        // shows what will actually be used — a suffix silently stripped of
        // its slashes at write time is a filename nobody predicted.
        onChanged: (value) {
          final clean = OutputNaming.sanitiseSuffix(value);
          widget.controller.output = widget.controller.output.copyWith(
            suffix: clean,
          );
        },
      ),
    );
  }
}
