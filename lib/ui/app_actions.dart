import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/batch_controller.dart';
import '../controller/queue_controller.dart';
import '../controller/target_controller.dart';
import '../core/fire_and_forget.dart';
import '../core/settings_controller.dart';
import '../io/file_dialogs.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/output_options.dart';
import '../model/resize_target.dart';
import 'dialogs.dart';

/// Every user command, implemented exactly once.
///
/// The menu, the toolbar and the keyboard shortcuts all call through here, so
/// they cannot drift apart — which is the failure mode that produces a menu
/// item quietly doing something slightly different from the button next to it.
///
/// Constructed cheaply per use from a [BuildContext]; it holds nothing.
class AppActions {
  AppActions(this.context);

  final BuildContext context;

  QueueController get _queue => context.read<QueueController>();
  TargetController get _target => context.read<TargetController>();
  BatchController get _batch => context.read<BatchController>();
  SettingsController get _settings => context.read<SettingsController>();
  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get canStart => !_batch.isRunning && _queue.processable.isNotEmpty;

  Future<void> addFiles() async {
    final paths = await FileDialogs.openImages(
      imagesLabel: _l10n.imagesFilterLabel,
    );
    if (paths.isEmpty) return;
    await _queue.addPaths(paths);
  }

  Future<void> addFolder() async {
    final folder = await FileDialogs.chooseFolder();
    if (folder == null) return;
    await _queue.addPaths(<String>[folder]);
  }

  /// Adds paths that arrived by drag-and-drop.
  Future<void> addDropped(Iterable<String> paths) => _queue.addPaths(paths);

  void removeSelected() {
    final index = _queue.selectedIndex;
    if (index < 0) return;
    _queue.removeAt(index);
  }

  void clearQueue() => _queue.clear();

  void start() {
    if (!canStart) return;
    // Last run's outcomes are not answers to the question being asked now.
    _queue.resetOutcomes();
    fireAndForget(_batch.start());
  }

  void cancel() => _batch.cancel();

  /// Start, or cancel if a batch is already running. One key, one button, and
  /// the state decides — the alternative is a button that is disabled at the
  /// only moment anyone wants to press it.
  void startOrCancel() {
    if (_batch.isRunning) {
      cancel();
    } else {
      start();
    }
  }

  void resetTarget() {
    _target
      ..format = const ResizeTarget().format
      ..maxEdge = null
      ..maxBytes = null
      ..quality = ResizeTarget.defaultQuality;
  }

  Future<void> chooseOutputFolder() async {
    final folder = await FileDialogs.chooseFolder(
      confirmButtonText: _l10n.chooseOutputFolderConfirm,
    );
    if (folder == null) return;
    _target.output = _target.output.copyWith(
      folder: folder,
      destination: OutputDestination.chosenFolder,
    );
  }

  /// Opens the folder the last run wrote into.
  ///
  /// Best-effort by nature: this is the one place the application asks the
  /// desktop to do something for it, and a machine with no file manager
  /// registered is a machine where nothing should happen rather than one where
  /// an error dialog appears.
  Future<void> revealOutput() async {
    final item = _queue.selected;
    final path = item?.outputPath;
    final folder = path != null
        ? File(path).parent.path
        : _target.output.folder;
    if (folder == null || !Directory(folder).existsSync()) return;

    try {
      if (Platform.isWindows) {
        await Process.run('explorer', <String>[folder]);
      } else {
        await Process.run('xdg-open', <String>[folder]);
      }
    } on ProcessException {
      // No file manager, or none on the path. Nothing to report.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => _settings.setThemeMode(mode);

  void showAbout() => showAboutShrinkDialog(context);
}
