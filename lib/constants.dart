import 'dart:io';

class Constants {
  Constants._();
  static final String _projectDir = Directory.current.path;

  //.gitignore
  static String get gitignorePath => '$_projectDir/.gitignore';

  // Directories
  static String get iosDirPath => '$_projectDir/ios';
  static String get androidDirPath => '$_projectDir/android';

  // Fastlane directories
  static String get iosFastlaneDirPath => '$iosDirPath/fastlane';
  static String get androidFastlaneDirPath => '$androidDirPath/fastlane';

  // Fastfile
  static String get androidFastfilePath => '$androidFastlaneDirPath/Fastfile';
  static String get iosFastfilePath => '$iosFastlaneDirPath/Fastfile';

  // Deliverfile
  static String get iosDeliverfilePath => '$iosFastlaneDirPath/Deliverfile';
  static String get androidDeliverfilePath =>
      '$androidFastlaneDirPath/Deliverfile';

  // Automate Config
  static String get automateDirPath => '$_projectDir/automate';
  static String get automateConfigFilePath =>
      '$automateDirPath/automate_config.yaml';

  // Automate Readme
  static String get automateReadmePath => '$automateDirPath/README.md';

  // IOS app_rating_config.json
  static String get appRatingConfigPath =>
      '$automateDirPath/app_rating_config.json';

  // IOS app_privacy_details.json
  static String get appPrivacyDetailsPath =>
      '$automateDirPath/app_privacy_details.json';
}
