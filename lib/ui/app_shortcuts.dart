import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Every keyboard shortcut, declared once.
///
/// The menu renders these into its right-hand column and the shell binds them;
/// declaring them in both places is how a menu ends up promising a key that does
/// nothing.
abstract final class AppShortcuts {
  static const SingleActivator addFiles = SingleActivator(
    LogicalKeyboardKey.keyO,
    control: true,
  );

  static const SingleActivator addFolder = SingleActivator(
    LogicalKeyboardKey.keyO,
    control: true,
    shift: true,
  );

  /// Start, or cancel while running. Ctrl+Enter rather than a bare Enter,
  /// which belongs to whichever field has focus.
  static const SingleActivator startOrCancel = SingleActivator(
    LogicalKeyboardKey.enter,
    control: true,
  );

  static const SingleActivator removeSelected = SingleActivator(
    LogicalKeyboardKey.delete,
  );

  static const SingleActivator quit = SingleActivator(
    LogicalKeyboardKey.keyQ,
    control: true,
  );
}
