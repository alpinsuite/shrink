import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/output_format.dart';
import '../model/output_options.dart';
import '../model/resize_target.dart';

/// Preferences that outlive a session.
///
/// Everything here is best-effort. If persistence fails the application still
/// runs on the defaults, because losing a remembered slider position must never
/// stop anyone resizing an image.
///
/// The target and the output options are remembered together and deliberately:
/// this is a tool people run repeatedly with the same settings on different
/// folders, and re-entering "under 500 KB, longest edge 1600" every launch
/// would be most of the work.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  static const _keyThemeMode = 'theme_mode';
  static const _keyFormat = 'target_format';
  static const _keyMaxEdge = 'target_max_edge';
  static const _keyQuality = 'target_quality';
  static const _keyMaxBytes = 'target_max_bytes';
  static const _keyDestination = 'output_destination';
  static const _keyFolder = 'output_folder';
  static const _keySuffix = 'output_suffix';
  static const _keyCollision = 'output_collision';

  final SharedPreferences _prefs;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }

  ThemeMode get themeMode => switch (_prefs.getString(_keyThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  /// The target as it was last left.
  ///
  /// Anything unparseable falls back to the default rather than throwing: a
  /// preferences file written by a future version, or corrupted, is a reason to
  /// start fresh and not a reason to refuse to open.
  ResizeTarget get target {
    return ResizeTarget(
      format: OutputFormat.values.firstWhere(
        (format) => format.name == _prefs.getString(_keyFormat),
        orElse: () => OutputFormat.sameAsSource,
      ),
      maxEdge: _prefs.getInt(_keyMaxEdge),
      quality: _prefs.getInt(_keyQuality) ?? ResizeTarget.defaultQuality,
      maxBytes: _prefs.getInt(_keyMaxBytes),
    );
  }

  Future<void> setTarget(ResizeTarget target) async {
    await _prefs.setString(_keyFormat, target.format.name);
    await _prefs.setInt(_keyQuality, target.quality);
    await _setNullableInt(_keyMaxEdge, target.maxEdge);
    await _setNullableInt(_keyMaxBytes, target.maxBytes);
    notifyListeners();
  }

  OutputOptions get outputOptions {
    final folder = _prefs.getString(_keyFolder);
    return OutputOptions(
      destination: OutputDestination.values.firstWhere(
        (value) => value.name == _prefs.getString(_keyDestination),
        orElse: () => OutputDestination.sameFolder,
      ),
      // A folder that has been deleted or unplugged since last launch would
      // otherwise leave the batch pointed at nothing and only say so at the
      // moment it tried to write.
      folder: folder != null && Directory(folder).existsSync() ? folder : null,
      suffix: _prefs.getString(_keySuffix) ?? OutputOptions.defaultSuffix,
      collision: CollisionPolicy.values.firstWhere(
        (value) => value.name == _prefs.getString(_keyCollision),
        orElse: () => CollisionPolicy.rename,
      ),
    );
  }

  Future<void> setOutputOptions(OutputOptions options) async {
    await _prefs.setString(_keyDestination, options.destination.name);
    await _prefs.setString(_keySuffix, options.suffix);
    await _prefs.setString(_keyCollision, options.collision.name);
    final folder = options.folder;
    if (folder == null) {
      await _prefs.remove(_keyFolder);
    } else {
      await _prefs.setString(_keyFolder, folder);
    }
    notifyListeners();
  }

  Future<void> _setNullableInt(String key, int? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setInt(key, value);
    }
  }
}
