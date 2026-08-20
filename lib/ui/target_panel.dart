import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/estimate_controller.dart';
import '../controller/target_controller.dart';
import '../core/byte_format.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/output_format.dart';
import '../model/resize_target.dart';
import '../ops/resize_ops.dart';
import 'labels.dart';
import 'recommendation_hint.dart';

/// The four constraints, and what each one implies about the others.
///
/// This panel is the application. Every control is a *limit* rather than a
/// setting — "no wider than", "no larger than" — because that is how the job
/// arrives: somebody has been told 2 MB, or 1600 pixels, and the rest has to
/// follow from it. Moving one shows what the others would have to be, and
/// offers to set them.
class TargetPanel extends StatelessWidget {
  const TargetPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final controller = context.watch<TargetController>();
    final estimate = context.watch<EstimateController>().estimate;
    final target = controller.target;

    return SlateSidePanel(
      title: l10n.panelTarget,
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
            SlateLabeledField(
              label: l10n.fieldFormat,
              child: SlateSelect<OutputFormat>(
                value: target.format,
                values: OutputFormat.targets,
                labelOf: (format) => format.labelFor(l10n),
                onChanged: (format) => controller.format = format,
              ),
            ),
            const SizedBox(height: 14),
            _MaxEdgeControl(
              controller: controller,
              recommendation: estimate.edgeRecommendation,
            ),
            const SizedBox(height: 14),
            _QualityControl(
              controller: controller,
              recommendation: estimate.qualityRecommendation,
            ),
            const SizedBox(height: 14),
            _MaxBytesControl(
              controller: controller,
              recommendation: estimate.budgetRecommendation,
            ),
          ],
        ),
      ),
    );
  }
}

/// The dimension cap: off, or a longest edge in pixels.
class _MaxEdgeControl extends StatelessWidget {
  const _MaxEdgeControl({
    required this.controller,
    required this.recommendation,
  });

  final TargetController controller;
  final Recommendation? recommendation;

  /// The value the slider shows while the constraint is switched off — a common
  /// page width, so turning it on lands somewhere sensible rather than at one
  /// end of the scale.
  static const int _default = 1600;

  /// A slider position for [edge], on a log scale.
  ///
  /// Linear would spend most of its travel between 6000 and 12000 px, a range
  /// nobody targets, and make everything under 1000 impossible to hit.
  static double _toSlider(int edge) {
    final low = math.log(ResizeOps.minEdge.toDouble());
    final high = math.log(ResizeOps.maxEdge.toDouble());
    return ((math.log(edge.toDouble()) - low) / (high - low)).clamp(0.0, 1.0);
  }

  static int _fromSlider(double position) {
    final low = math.log(ResizeOps.minEdge.toDouble());
    final high = math.log(ResizeOps.maxEdge.toDouble());
    return _round(math.exp(low + position * (high - low)).round());
  }

  /// Rounded to something a person would have typed. Nobody wants a 1637-pixel
  /// image, and a slider that produces one reads as broken rather than precise.
  static int _round(int edge) {
    if (edge < 200) return (edge / 10).round() * 10;
    if (edge < 2000) return (edge / 50).round() * 50;
    return (edge / 100).round() * 100;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final target = controller.target;
    final enabled = target.maxEdge != null;
    final edge = target.maxEdge ?? _default;

    return _Constraint(
      label: l10n.fieldMaxEdge,
      enabled: enabled,
      onToggled: (on) => controller.maxEdge = on ? edge : null,
      slider: SlateSlider(
        value: _toSlider(edge),
        min: 0,
        max: 1,
        onChanged: (position) => controller.maxEdge = _fromSlider(position),
      ),
      field: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _NumberField(
            value: edge,
            width: 58,
            parse: (text) {
              final value = int.tryParse(text);
              return value == null || value < 1 ? null : value;
            },
            onSubmitted: (value) => controller.maxEdge = value,
          ),
          const SizedBox(width: 4),
          Text(l10n.unitPixels, style: theme.dimTextStyle),
        ],
      ),
      hint: RecommendationHint(
        recommendation: recommendation,
        onApply: (value) => controller.maxEdge = value,
      ),
    );
  }
}

/// Quality, which only some formats have.
class _QualityControl extends StatelessWidget {
  const _QualityControl({
    required this.controller,
    required this.recommendation,
  });

  final TargetController controller;
  final Recommendation? recommendation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final target = controller.target;
    final applies = target.qualityApplies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.fieldQuality,
          style: applies
              ? theme.dimTextStyle
              // Not merely greyed: the label of a control that cannot do
              // anything should be as quiet as the control.
              : theme.dimTextStyle.copyWith(
                  color: theme.palette.inkDim.withValues(alpha: 0.5),
                ),
        ),
        const SizedBox(height: 4),
        _Dimmed(
          enabled: applies,
          child: Row(
            children: <Widget>[
              Expanded(
                child: SlateSlider(
                  value: target.quality.toDouble(),
                  min: ResizeTarget.minQuality.toDouble(),
                  max: ResizeTarget.maxQuality.toDouble(),
                  onChanged: (value) => controller.quality = value.round(),
                ),
              ),
              const SizedBox(width: 8),
              _NumberField(
                value: target.quality,
                width: 46,
                parse: (text) {
                  final value = int.tryParse(text);
                  if (value == null) return null;
                  return value.clamp(
                    ResizeTarget.minQuality,
                    ResizeTarget.maxQuality,
                  );
                },
                onSubmitted: (value) => controller.quality = value,
              ),
            ],
          ),
        ),
        if (!applies)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              l10n.qualityUnavailable(target.format.labelFor(l10n)),
              style: theme.dimTextStyle,
            ),
          )
        else
          RecommendationHint(
            recommendation: recommendation,
            onApply: (value) => controller.quality = value,
          ),
      ],
    );
  }
}

/// The file-size budget.
class _MaxBytesControl extends StatelessWidget {
  const _MaxBytesControl({
    required this.controller,
    required this.recommendation,
  });

  final TargetController controller;
  final Recommendation? recommendation;

  /// A common attachment limit, so switching the constraint on lands on a
  /// number people recognise.
  static const int _default = ByteFormat.mb;

  static double _toSlider(int bytes) {
    final low = math.log(ResizeTarget.minBudget.toDouble());
    final high = math.log(ResizeTarget.maxBudget.toDouble());
    return ((math.log(bytes.toDouble()) - low) / (high - low)).clamp(0.0, 1.0);
  }

  static int _fromSlider(double position) {
    final low = math.log(ResizeTarget.minBudget.toDouble());
    final high = math.log(ResizeTarget.maxBudget.toDouble());
    return _round(math.exp(low + position * (high - low)).round());
  }

  /// Rounded the way a person states a size, so the field never reads `487 KB`
  /// when the user was reaching for 500.
  static int _round(int bytes) {
    if (bytes < 100 * ByteFormat.kb) {
      return (bytes / (5 * ByteFormat.kb)).round() * 5 * ByteFormat.kb;
    }
    if (bytes < ByteFormat.mb) {
      return (bytes / (25 * ByteFormat.kb)).round() * 25 * ByteFormat.kb;
    }
    if (bytes < 10 * ByteFormat.mb) {
      return (bytes / (100 * ByteFormat.kb)).round() * 100 * ByteFormat.kb;
    }
    return (bytes / ByteFormat.mb).round() * ByteFormat.mb;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final target = controller.target;
    final enabled = target.maxBytes != null;
    final bytes = target.maxBytes ?? _default;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Constraint(
          label: l10n.fieldMaxSize,
          enabled: enabled,
          onToggled: (on) => controller.maxBytes = on ? bytes : null,
          slider: SlateSlider(
            value: _toSlider(bytes),
            min: 0,
            max: 1,
            onChanged: (position) =>
                controller.maxBytes = _fromSlider(position),
          ),
          field: _TextField(
            text: ByteFormat.format(bytes),
            width: 76,
            parse: ByteFormat.parse,
            onSubmitted: (value) => controller.maxBytes = value,
          ),
          hint: RecommendationHint(
            recommendation: recommendation,
            onApply: (value) => controller.maxBytes = value,
          ),
        ),
        // The one thing a user cannot work out for themselves: with no quality
        // knob, the only way to reach a size is to make the image smaller.
        if (enabled && !target.qualityApplies)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(l10n.budgetByDimensionsOnly, style: theme.dimTextStyle),
          ),
      ],
    );
  }
}

/// A constraint that can be switched off: a checkbox, a slider, a field and a
/// recommendation, laid out the same way every time.
class _Constraint extends StatelessWidget {
  const _Constraint({
    required this.label,
    required this.enabled,
    required this.onToggled,
    required this.slider,
    required this.field,
    required this.hint,
  });

  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final Widget slider;
  final Widget field;
  final Widget hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The checkbox carries the label. A heading *and* a "Limit ..."
        // tickbox saying the same thing is a row of duplicated words in a panel
        // with no room for them.
        SlateCheckbox(value: enabled, label: label, onChanged: onToggled),
        const SizedBox(height: 4),
        _Dimmed(
          enabled: enabled,
          child: Row(
            children: <Widget>[
              Expanded(child: slider),
              const SizedBox(width: 8),
              field,
            ],
          ),
        ),
        // Shown whether or not the constraint is switched on. A recommendation
        // to cap the longest edge is at its most useful precisely when no cap
        // has been set yet — hiding it until the box is ticked would mean the
        // one suggestion that solves an unreachable budget only appears once
        // the user has already worked out that they need it. Applying it
        // switches the constraint on.
        hint,
      ],
    );
  }
}

/// Fades a control that is switched off, and stops it taking the pointer.
///
/// Fading alone leaves a slider that is invisible but still draggable and a
/// field that can still be focused and typed into: the value changes, nothing
/// happens, and the control looks broken.
class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return Opacity(
      // Still legible: switched off, the control shows the value it *would*
      // take, which is what makes switching it on predictable.
      opacity: 0.45,
      child: IgnorePointer(child: ExcludeFocus(child: child)),
    );
  }
}

/// A small right-aligned integer field.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.value,
    required this.width,
    required this.parse,
    required this.onSubmitted,
  });

  final int value;
  final double width;
  final int? Function(String text) parse;
  final ValueChanged<int> onSubmitted;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value.toString(),
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Committing on blur as well as on Enter. A field that silently discards
    // what was typed the moment the pointer moves away is the single most
    // common complaint about numeric entry.
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // The value changed elsewhere — a slider, or an applied recommendation. Not
    // while the field has focus, or it would rewrite what is being typed.
    if (widget.value != old.value && !_focus.hasFocus) {
      _text.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit(_text.text);
  }

  void _commit(String text) {
    final parsed = widget.parse(text);
    if (parsed == null) {
      _text.text = widget.value.toString();
      return;
    }
    widget.onSubmitted(parsed);
    _text.text = parsed.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SlateField(
      controller: _text,
      focusNode: _focus,
      width: widget.width,
      textAlign: TextAlign.right,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: _commit,
    );
  }
}

/// A field whose value is text a person writes — `800 KB`, `1.5 MB`.
class _TextField extends StatefulWidget {
  const _TextField({
    required this.text,
    required this.width,
    required this.parse,
    required this.onSubmitted,
  });

  final String text;
  final double width;
  final int? Function(String text) parse;
  final ValueChanged<int> onSubmitted;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_TextField old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text && !_focus.hasFocus) _text.text = widget.text;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit(_text.text);
  }

  void _commit(String text) {
    final parsed = widget.parse(text);
    if (parsed == null) {
      _text.text = widget.text;
      return;
    }
    widget.onSubmitted(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SlateField(
      controller: _text,
      focusNode: _focus,
      width: widget.width,
      textAlign: TextAlign.right,
      onSubmitted: _commit,
    );
  }
}
