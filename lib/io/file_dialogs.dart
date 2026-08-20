/// The native open and folder-choose dialogs.
///
/// Thin on purpose: `file_selector` already routes to GTK on Linux and to the
/// common item dialog on Windows. What this adds is the filter, which is built
/// from [OutputFormat.readableExtensions] so the dialog offers exactly what the
/// queue will accept — a dialog that lets someone pick a file the application
/// then refuses is a dialog that lied.
library;

import 'package:file_selector/file_selector.dart';

import '../model/output_format.dart';

abstract final class FileDialogs {
  /// Picks image files. Empty when the user cancelled.
  static Future<List<String>> openImages({required String imagesLabel}) async {
    final files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: imagesLabel,
          extensions: OutputFormat.readableExtensions,
        ),
      ],
    );
    return files.map((file) => file.path).toList();
  }

  /// Picks a folder, either to add or to write into. Null when cancelled.
  static Future<String?> chooseFolder({String? confirmButtonText}) =>
      getDirectoryPath(confirmButtonText: confirmButtonText);
}
