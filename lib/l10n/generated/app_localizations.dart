import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name, shown in the window title and About dialog
  ///
  /// In en, this message translates to:
  /// **'Shrink'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Batch image resizer'**
  String get appTagline;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimise'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximise'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @menuTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get menuTheme;

  /// No description provided for @actionAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Add Images...'**
  String get actionAddFiles;

  /// No description provided for @actionAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder...'**
  String get actionAddFolder;

  /// No description provided for @actionRemoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Remove Selected'**
  String get actionRemoveSelected;

  /// No description provided for @actionClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear List'**
  String get actionClearQueue;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get actionQuit;

  /// No description provided for @actionResetTarget.
  ///
  /// In en, this message translates to:
  /// **'Reset Target'**
  String get actionResetTarget;

  /// No description provided for @actionChooseOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Output Folder...'**
  String get actionChooseOutputFolder;

  /// No description provided for @actionRevealOutput.
  ///
  /// In en, this message translates to:
  /// **'Show in File Manager'**
  String get actionRevealOutput;

  /// No description provided for @actionAbout.
  ///
  /// In en, this message translates to:
  /// **'About Shrink'**
  String get actionAbout;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse...'**
  String get actionBrowse;

  /// Modifier key name as shown in a menu's shortcut column
  ///
  /// In en, this message translates to:
  /// **'Ctrl'**
  String get keyCtrl;

  /// No description provided for @keyShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get keyShift;

  /// No description provided for @keyAlt.
  ///
  /// In en, this message translates to:
  /// **'Alt'**
  String get keyAlt;

  /// No description provided for @keyDelete.
  ///
  /// In en, this message translates to:
  /// **'Del'**
  String get keyDelete;

  /// No description provided for @keyEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get keyEnter;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the desktop'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @imagesFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imagesFilterLabel;

  /// No description provided for @chooseOutputFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this folder'**
  String get chooseOutputFolderConfirm;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop images or folders to add them'**
  String get dropHint;

  /// No description provided for @emptyQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to resize yet'**
  String get emptyQueueTitle;

  /// No description provided for @emptyQueueHint.
  ///
  /// In en, this message translates to:
  /// **'Add images, or drop them anywhere in this window.'**
  String get emptyQueueHint;

  /// No description provided for @columnFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get columnFile;

  /// No description provided for @columnSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get columnSource;

  /// No description provided for @columnOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get columnOutput;

  /// No description provided for @columnChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get columnChange;

  /// No description provided for @columnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get columnStatus;

  /// No description provided for @statusProbing.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get statusProbing;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unreadable'**
  String get statusUnreadable;

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get statusRunning;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusOverBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get statusOverBudget;

  /// No description provided for @failureUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Not an image this application can read'**
  String get failureUnreadable;

  /// No description provided for @failureNoEncoder.
  ///
  /// In en, this message translates to:
  /// **'This format can be read but not written. Choose a target format.'**
  String get failureNoEncoder;

  /// No description provided for @failureIo.
  ///
  /// In en, this message translates to:
  /// **'The file could not be written'**
  String get failureIo;

  /// No description provided for @dimensions.
  ///
  /// In en, this message translates to:
  /// **'{width} x {height}'**
  String dimensions(int width, int height);

  /// No description provided for @pixels.
  ///
  /// In en, this message translates to:
  /// **'{value} px'**
  String pixels(int value);

  /// Unit shown beside a field that takes a pixel count
  ///
  /// In en, this message translates to:
  /// **'px'**
  String get unitPixels;

  /// Marks a size that is modelled rather than measured
  ///
  /// In en, this message translates to:
  /// **'~ {value}'**
  String approximately(String value);

  /// No description provided for @percentSmaller.
  ///
  /// In en, this message translates to:
  /// **'{percent}% smaller'**
  String percentSmaller(int percent);

  /// No description provided for @percentLarger.
  ///
  /// In en, this message translates to:
  /// **'{percent}% larger'**
  String percentLarger(int percent);

  /// No description provided for @panelTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get panelTarget;

  /// No description provided for @panelOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get panelOutput;

  /// No description provided for @panelPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get panelPreview;

  /// No description provided for @fieldFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get fieldFormat;

  /// No description provided for @formatSameAsSource.
  ///
  /// In en, this message translates to:
  /// **'Same as source'**
  String get formatSameAsSource;

  /// No description provided for @fieldMaxEdge.
  ///
  /// In en, this message translates to:
  /// **'Longest edge'**
  String get fieldMaxEdge;

  /// No description provided for @fieldQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get fieldQuality;

  /// No description provided for @fieldMaxSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get fieldMaxSize;

  /// No description provided for @limitDimensions.
  ///
  /// In en, this message translates to:
  /// **'Limit dimensions'**
  String get limitDimensions;

  /// No description provided for @limitFileSize.
  ///
  /// In en, this message translates to:
  /// **'Limit file size'**
  String get limitFileSize;

  /// Shown under the disabled quality slider for a lossless format
  ///
  /// In en, this message translates to:
  /// **'{format} has no quality setting'**
  String qualityUnavailable(String format);

  /// No description provided for @budgetByDimensionsOnly.
  ///
  /// In en, this message translates to:
  /// **'A size limit is met by reducing dimensions alone'**
  String get budgetByDimensionsOnly;

  /// No description provided for @recommendQualityForBudget.
  ///
  /// In en, this message translates to:
  /// **'Quality {value} would fit'**
  String recommendQualityForBudget(int value);

  /// No description provided for @recommendEdgeForBudget.
  ///
  /// In en, this message translates to:
  /// **'{value} px would fit'**
  String recommendEdgeForBudget(int value);

  /// No description provided for @recommendEdgeQualityExhausted.
  ///
  /// In en, this message translates to:
  /// **'Quality alone will not fit it; {value} px would'**
  String recommendEdgeQualityExhausted(int value);

  /// No description provided for @recommendBudget.
  ///
  /// In en, this message translates to:
  /// **'These settings produce about {value}'**
  String recommendBudget(String value);

  /// No description provided for @budgetUnreachable.
  ///
  /// In en, this message translates to:
  /// **'No setting reaches this size'**
  String get budgetUnreachable;

  /// No description provided for @previewNoSelection.
  ///
  /// In en, this message translates to:
  /// **'Select a file to see it at these settings'**
  String get previewNoSelection;

  /// No description provided for @previewUnwritable.
  ///
  /// In en, this message translates to:
  /// **'This format can be read but not written'**
  String get previewUnwritable;

  /// No description provided for @previewOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get previewOriginal;

  /// No description provided for @previewResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get previewResult;

  /// Shows the original and the result side by side in the enlarged preview
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get previewShowBoth;

  /// No description provided for @actionEnlargePreview.
  ///
  /// In en, this message translates to:
  /// **'Enlarge preview'**
  String get actionEnlargePreview;

  /// No description provided for @previewMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring'**
  String get previewMeasuring;

  /// No description provided for @previewQualityUsed.
  ///
  /// In en, this message translates to:
  /// **'quality {value}'**
  String previewQualityUsed(int value);

  /// No description provided for @outputSameFolder.
  ///
  /// In en, this message translates to:
  /// **'Beside the originals'**
  String get outputSameFolder;

  /// No description provided for @outputChosenFolder.
  ///
  /// In en, this message translates to:
  /// **'Into a folder'**
  String get outputChosenFolder;

  /// No description provided for @fieldSuffix.
  ///
  /// In en, this message translates to:
  /// **'Name suffix'**
  String get fieldSuffix;

  /// No description provided for @fieldFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get fieldFolder;

  /// No description provided for @fieldCollision.
  ///
  /// In en, this message translates to:
  /// **'If that name exists'**
  String get fieldCollision;

  /// No description provided for @collisionRename.
  ///
  /// In en, this message translates to:
  /// **'Add a number'**
  String get collisionRename;

  /// No description provided for @collisionOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Replace it'**
  String get collisionOverwrite;

  /// No description provided for @collisionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip the file'**
  String get collisionSkip;

  /// No description provided for @outputNoFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder chosen'**
  String get outputNoFolder;

  /// No description provided for @outputNeverOverwritesSource.
  ///
  /// In en, this message translates to:
  /// **'An original is never overwritten.'**
  String get outputNeverOverwritesSource;

  /// No description provided for @queueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No images} =1{1 image} other{{count} images}}'**
  String queueCount(int count);

  /// No description provided for @queueSelected.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String queueSelected(int index, int total);

  /// No description provided for @batchProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String batchProgress(int done, int total);

  /// No description provided for @summaryWritten.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 written} other{{count} written}}'**
  String summaryWritten(int count);

  /// No description provided for @summarySkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String summarySkipped(int count);

  /// No description provided for @summaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String summaryFailed(int count);

  /// No description provided for @summaryOverBudget.
  ///
  /// In en, this message translates to:
  /// **'{count} over budget'**
  String summaryOverBudget(int count);

  /// No description provided for @summarySaved.
  ///
  /// In en, this message translates to:
  /// **'{value} saved'**
  String summarySaved(String value);

  /// No description provided for @summaryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get summaryCancelled;

  /// No description provided for @summaryNoChange.
  ///
  /// In en, this message translates to:
  /// **'No smaller'**
  String get summaryNoChange;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Resizes images in batches to a format, a pixel size, a quality or a file size — and recommends the rest when you set one of them.'**
  String get aboutDescription;

  /// No description provided for @aboutBuiltWith.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter and the Slate widget kit.'**
  String get aboutBuiltWith;

  /// No description provided for @buttonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get buttonOk;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get buttonClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
