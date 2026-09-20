// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shrink';

  @override
  String get appTagline => 'Batch image resizer';

  @override
  String get windowMinimize => 'Minimise';

  @override
  String get windowMaximize => 'Maximise';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuTheme => 'Theme';

  @override
  String get actionAddFiles => 'Add Images...';

  @override
  String get actionAddFolder => 'Add Folder...';

  @override
  String get actionRemoveSelected => 'Remove Selected';

  @override
  String get actionClearQueue => 'Clear List';

  @override
  String get actionStart => 'Start';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionQuit => 'Quit';

  @override
  String get actionResetTarget => 'Reset Target';

  @override
  String get actionChooseOutputFolder => 'Choose Output Folder...';

  @override
  String get actionRevealOutput => 'Show in File Manager';

  @override
  String get actionAbout => 'About Shrink';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionBrowse => 'Browse...';

  @override
  String get keyCtrl => 'Ctrl';

  @override
  String get keyShift => 'Shift';

  @override
  String get keyAlt => 'Alt';

  @override
  String get keyDelete => 'Del';

  @override
  String get keyEnter => 'Enter';

  @override
  String get themeSystem => 'Follow the desktop';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get imagesFilterLabel => 'Images';

  @override
  String get chooseOutputFolderConfirm => 'Use this folder';

  @override
  String get dropHint => 'Drop images or folders to add them';

  @override
  String get emptyQueueTitle => 'Nothing to resize yet';

  @override
  String get emptyQueueHint =>
      'Add images, or drop them anywhere in this window.';

  @override
  String get columnFile => 'File';

  @override
  String get columnSource => 'Source';

  @override
  String get columnOutput => 'Output';

  @override
  String get columnChange => 'Change';

  @override
  String get columnStatus => 'Status';

  @override
  String get statusProbing => 'Reading';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusUnreadable => 'Unreadable';

  @override
  String get statusRunning => 'Working';

  @override
  String get statusDone => 'Done';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusOverBudget => 'Over budget';

  @override
  String get statusKeptOriginal => 'Kept as is';

  @override
  String get statusKeptOriginalHint =>
      'Already as small as these settings can make it, so the copy is the original, untouched.';

  @override
  String get previewKeptOriginal => 'kept as is';

  @override
  String get failureUnreadable => 'Not an image this application can read';

  @override
  String get failureNoEncoder =>
      'This format can be read but not written. Choose a target format.';

  @override
  String get failureIo => 'The file could not be written';

  @override
  String dimensions(int width, int height) {
    return '$width x $height';
  }

  @override
  String pixels(int value) {
    return '$value px';
  }

  @override
  String get unitPixels => 'px';

  @override
  String approximately(String value) {
    return '~ $value';
  }

  @override
  String percentSmaller(int percent) {
    return '$percent% smaller';
  }

  @override
  String percentLarger(int percent) {
    return '$percent% larger';
  }

  @override
  String get panelTarget => 'Target';

  @override
  String get panelOutput => 'Output';

  @override
  String get panelPreview => 'Preview';

  @override
  String get fieldFormat => 'Format';

  @override
  String get formatSameAsSource => 'Same as source';

  @override
  String get fieldMaxEdge => 'Longest edge';

  @override
  String get fieldQuality => 'Quality';

  @override
  String get fieldMaxSize => 'File size';

  @override
  String get limitDimensions => 'Limit dimensions';

  @override
  String get limitFileSize => 'Limit file size';

  @override
  String qualityUnavailable(String format) {
    return '$format has no quality setting';
  }

  @override
  String get budgetByDimensionsOnly =>
      'A size limit is met by reducing dimensions alone';

  @override
  String recommendQualityForBudget(int value) {
    return 'Quality $value would fit';
  }

  @override
  String recommendEdgeForBudget(int value) {
    return '$value px would fit';
  }

  @override
  String recommendEdgeQualityExhausted(int value) {
    return 'Quality alone will not fit it; $value px would';
  }

  @override
  String recommendBudget(String value) {
    return 'These settings produce about $value';
  }

  @override
  String get budgetUnreachable => 'No setting reaches this size';

  @override
  String get previewNoSelection => 'Select a file to see it at these settings';

  @override
  String get previewUnwritable => 'This format can be read but not written';

  @override
  String get previewOriginal => 'Original';

  @override
  String get previewResult => 'Result';

  @override
  String get previewShowBoth => 'Both';

  @override
  String get actionEnlargePreview => 'Enlarge preview';

  @override
  String get previewMeasuring => 'Measuring';

  @override
  String previewQualityUsed(int value) {
    return 'quality $value';
  }

  @override
  String get outputSameFolder => 'Beside the originals';

  @override
  String get outputChosenFolder => 'Into a folder';

  @override
  String get fieldSuffix => 'Name suffix';

  @override
  String get fieldFolder => 'Folder';

  @override
  String get fieldCollision => 'If that name exists';

  @override
  String get collisionRename => 'Add a number';

  @override
  String get collisionOverwrite => 'Replace it';

  @override
  String get collisionSkip => 'Skip the file';

  @override
  String get outputNoFolder => 'No folder chosen';

  @override
  String get outputNeverOverwritesSource => 'An original is never overwritten.';

  @override
  String queueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
      zero: 'No images',
    );
    return '$_temp0';
  }

  @override
  String queueSelected(int index, int total) {
    return '$index of $total';
  }

  @override
  String batchProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String summaryWritten(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count written',
      one: '1 written',
    );
    return '$_temp0';
  }

  @override
  String summarySkipped(int count) {
    return '$count skipped';
  }

  @override
  String summaryFailed(int count) {
    return '$count failed';
  }

  @override
  String summaryOverBudget(int count) {
    return '$count over budget';
  }

  @override
  String summarySaved(String value) {
    return '$value saved';
  }

  @override
  String get summaryCancelled => 'Cancelled';

  @override
  String get summaryNoChange => 'No smaller';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Resizes images in batches to a format, a pixel size, a quality or a file size — and recommends the rest when you set one of them.';

  @override
  String get aboutBuiltWith => 'Built with Flutter and the Slate widget kit.';

  @override
  String get buttonOk => 'OK';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonClose => 'Close';
}
