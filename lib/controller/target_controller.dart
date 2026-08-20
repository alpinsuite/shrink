import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/fire_and_forget.dart';
import '../core/settings_controller.dart';
import '../model/output_format.dart';
import '../model/output_options.dart';
import '../model/resize_target.dart';

/// Which of the four controls the user touched last.
///
/// The interface uses this to decide what to *recommend*: moving the quality
/// slider is a question about file size, and moving the file-size slider is a
/// question about quality. Without knowing which knob moved, every hint would
/// have to be shown at once, which is the noise this feature exists to remove.
enum TargetKnob { format, maxEdge, quality, maxBytes }

/// What the user is asking for, and where the results go.
///
/// Holds no images and does no work — it is the settings, the last knob
/// touched, and their persistence. [EstimateController] is what turns this into
/// numbers.
class TargetController extends ChangeNotifier {
  TargetController({required SettingsController settings})
    : _settings = settings,
      _target = settings.target,
      _output = settings.outputOptions;

  /// Writing to preferences on every frame of a slider drag would be hundreds
  /// of writes for one decision.
  static const Duration _persistDelay = Duration(milliseconds: 600);

  final SettingsController _settings;

  ResizeTarget _target;
  OutputOptions _output;
  TargetKnob? _lastMoved;
  Timer? _persist;

  ResizeTarget get target => _target;
  OutputOptions get output => _output;
  TargetKnob? get lastMoved => _lastMoved;

  set format(OutputFormat value) {
    if (value == _target.format) return;
    _apply(_target.copyWith(format: value), TargetKnob.format);
  }

  set quality(int value) {
    if (value == _target.quality) return;
    _apply(_target.copyWith(quality: value), TargetKnob.quality);
  }

  /// Null switches the dimension cap off entirely.
  set maxEdge(int? value) {
    if (value == _target.maxEdge) return;
    _apply(_target.withMaxEdge(value), TargetKnob.maxEdge);
  }

  /// Null switches the file-size budget off entirely.
  set maxBytes(int? value) {
    if (value == _target.maxBytes) return;
    _apply(_target.withMaxBytes(value), TargetKnob.maxBytes);
  }

  set output(OutputOptions value) {
    _output = value;
    _schedulePersist();
    notifyListeners();
  }

  void _apply(ResizeTarget target, TargetKnob knob) {
    _target = target;
    _lastMoved = knob;
    _schedulePersist();
    notifyListeners();
  }

  void _schedulePersist() {
    _persist?.cancel();
    _persist = Timer(_persistDelay, () {
      fireAndForget(_settings.setTarget(_target));
      fireAndForget(_settings.setOutputOptions(_output));
    });
  }

  @override
  void dispose() {
    _persist?.cancel();
    // The pending write is the user's most recent decision; dropping it because
    // the window closed within half a second of the last drag is exactly when
    // losing it would be most annoying.
    fireAndForget(_settings.setTarget(_target));
    fireAndForget(_settings.setOutputOptions(_output));
    super.dispose();
  }
}
