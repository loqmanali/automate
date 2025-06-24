import 'dart:io';
import 'package:args/args.dart';
import 'package:automate/automate_config.dart';
import 'package:automate/automate_enums.dart';
import 'package:automate/constants.dart';
import 'package:automate/templates.dart';
import 'package:automate/pubspec_utils.dart';
import 'package:automate/utils.dart';
import 'package:yaml/yaml.dart';

class AutomateScript {
  AutomatePlatform platform = AutomatePlatform.all;
  late AutomateMode mode;
  final AutomateConfig _automateConfig = AutomateConfig.instance;
  bool skipBuild = false;
  final String _projectDir = Directory.current.path;

  Future<void> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      throw Exception(
        'Error: Mode (beta, release, or update) must be provided.',
      );
    }

    final String firstArgument = arguments.first.toLowerCase().trim();
    final restArguments = arguments.skip(1).toList();
    // optional named args

    final parser =
        ArgParser()
          ..addOption(
            'platform',
            allowed: ['ios', 'android'],
            help: 'Target platform',
            abbr: 'p',
          )
          ..addFlag("skip-build", abbr: "s", help: "Skip build process");

    final ArgResults args;

    try {
      args = parser.parse(restArguments);
    } catch (e) {
      throw Exception('Error parsing arguments: $e\n${parser.usage}');
    }

    if (args['platform'] == 'ios') {
      platform = AutomatePlatform.ios;
    } else if (args['platform'] == 'android') {
      platform = AutomatePlatform.android;
    }
    if (['beta', 'release', 'update'].contains(firstArgument)) {
      if (firstArgument == 'release' && platform == AutomatePlatform.android) {
        throw Exception(
          'Error: Release build is not supported for Android platform.',
        );
      }
      mode = firstArgument.toAutomateMode();
    } else if (args['skip-build'] ?? false) {
      skipBuild = true;
    } else if (firstArgument == 'init') {
      await _init();

      exit(0);
    } else {
      throw Exception(
        'Error: Invalid mode "${arguments.first}". Must be one of: beta, release, update.',
      );
    }

    // load automate_config.yaml
    await _automateConfig.load();

    await _initializeFastlane();

    print("\nSkipping build process: ${args['skip-build']}\n");
    await _executeBuildFlow();
  }

  Future<void> _init() async {
    print('Initializing Automate...');

    // Create automate dir if it doesn't exist in project root
    print('Creating ${Constants.automateDirPath}...');
    _createNewDirectory(Constants.automateDirPath);

    //Generate Readme.md
    print('Creating in automate directory ${Constants.automateReadmePath}...');
    _writeToFile(
      Constants.automateReadmePath,
      content: Templates.automateReadmeContent,
    );

    // Adding automate_config.yaml in gitignore
    if (File(Constants.gitignorePath).existsSync()) {
      const formattedPath = '/automate/automate_config.yaml';
      print('Adding $formattedPath to .gitignore...');
      // Read .gitignore file
      final gitignoreContent = File(Constants.gitignorePath).readAsStringSync();

      if (!gitignoreContent.contains(formattedPath)) {
        // Write .gitignore file with new line
        File(
          Constants.gitignorePath,
        ).writeAsStringSync('$gitignoreContent\n$formattedPath');
      } else {
        print('$formattedPath already added to .gitignore.');
      }
    }

    // Generate automate_config.yaml
    print(
      'Creating in automate directory ${Constants.automateConfigFilePath}...',
    );
    _writeToFile(
      Constants.automateConfigFilePath,
      content: Templates.automateConfigContent,
    );

    // Generate app_rating_config.json
    print('Creating in automate directory ${Constants.appRatingConfigPath}...');
    _writeToFile(
      Constants.appRatingConfigPath,
      content: Templates.iosAppRatingConfig,
    );

    // Generate app_privacy_details.json
    print(
      'Creating in automate directory ${Constants.appPrivacyDetailsPath}...',
    );
    _writeToFile(
      Constants.appPrivacyDetailsPath,
      content: Templates.iosAppPrivacyDetails,
    );

    // Create screenshots directory in IOS

    if (platform == AutomatePlatform.ios || platform == AutomatePlatform.all) {
      final fastlaneDir = Directory(Constants.iosFastlaneDirPath);
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }
      final screenshotsDir = Directory(
        '${Constants.iosFastlaneDirPath}/screenshots',
      );
      if (!screenshotsDir.existsSync()) {
        await screenshotsDir.create(recursive: true);
        final enLangDir = Directory(
          '${Constants.iosFastlaneDirPath}/screenshots/en-US',
        );
        if (!enLangDir.existsSync()) {
          await enLangDir.create(recursive: true);
        }
      }
    }
  }

  void _createNewDirectory(String path) {
    if (!Directory(path).existsSync()) {
      Directory(path).createSync();
    } else {
      print('Directory ${Constants.automateDirPath} already exists.');
    }
  }

  void _writeToFile(String path, {String? content}) {
    if (!File(path).existsSync()) {
      File(path).createSync();
      if (content != null) {
        File(path).writeAsStringSync(content);
      }
    } else {
      print('File $path already exists.');
    }
  }

  Future<bool> _isFastlaneInstalled() async {
    try {
      await _runCommand(
        "fastlane",
        arguments: ["--version"],
        description: "Fastlane version",
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _initializeFastlane() async {
    print('Initializing Fastlane...');
    if (!await _isFastlaneInstalled()) {
      throw Exception(
        'Error: Fastlane is not installed. Please install fastlane and try again.',
      );
    }
    if (platform == AutomatePlatform.all) {
      await _initializeIosFastlane();
      await _initializeAndroidFastlane();
    } else if (platform == AutomatePlatform.ios) {
      await _initializeIosFastlane();
    } else if (platform == AutomatePlatform.android) {
      await _initializeAndroidFastlane();
    }
    print('Fastlane initialized successfully.');
  }

  Future<void> _initializeIosFastlane() async {
    print('Initializing Fastlane for iOS...');
    try {
      // Check if ios directory exists
      final iosDir = Directory(Constants.iosDirPath);
      if (!iosDir.existsSync()) {
        throw Exception(
          'iOS directory not found at ${Constants.iosDirPath}. Ensure this is a valid Flutter project with an iOS module.',
        );
      }

      // Ensure fastlane directory exists
      final fastlaneDir = Directory(Constants.iosFastlaneDirPath);
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      await _createIosFastfile();

      print('IOS Fastlane initialized successfully.');
    } catch (e) {
      throw Exception('Failed to initialize iOS Fastlane: $e');
    }
  }

  Future<void> _initializeAndroidFastlane() async {
    print('Initializing Fastlane for Android...');
    // Check if android directory exists
    try {
      final androidDir = Directory(Constants.androidDirPath);
      if (!androidDir.existsSync()) {
        throw Exception(
          'Android directory not found at ${Constants.androidDirPath}. Ensure this is a valid Flutter project with an Android module.',
        );
      }

      // Ensure fastlane directory exists
      final fastlaneDir = Directory(Constants.androidFastlaneDirPath);
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      await _createAndroidFastfile();

      print('Android Fastlane initialized successfully.');
    } on Exception catch (e) {
      throw Exception('Failed to initialize Android Fastlane: $e');
    }
  }

  Future<void> _createIosFastfile() async {
    // Extract App Store Connect API key values
    try {
      final appStoreConfig = _automateConfig.appStoreConfig;

      final keyId = appStoreConfig['key_id']?.toString();
      final issuerId = appStoreConfig['issuer_id']?.toString();
      final keyFilepath = appStoreConfig['key_filepath']?.toString();

      if ((keyId?.isEmpty ?? true) ||
          (issuerId?.isEmpty ?? true) ||
          (keyFilepath?.isEmpty ?? true)) {
        throw Exception(
          'Missing key_id, issuer_id, or key_filepath in automate_config.yaml',
        );
      }

      final appIdentifier = await Utils.iosBundleId;

      // Define Fastlane configuration for iOS
      const fastlaneTemplate = Templates.iosFastFileContent;

      // Check for placeholder if key_id, issuer_id, or key_filepath is missing
      if (!fastlaneTemplate.contains('%key_id%') &&
          !fastlaneTemplate.contains('%issuer_id%') &&
          !fastlaneTemplate.contains('%key_filepath%') &&
          !fastlaneTemplate.contains('%display_name%') &&
          !fastlaneTemplate.contains('%app_identifier%')) {
        throw Exception(
          'Error: Missing key_id, issuer_id, app_identifier, display_name, or key_filepath in Fastlane template Must be all of: %key_id%, %issuer_id%, %key_filepath%, %app_identifier%, %team_id% or %username% existing in Fastlane template as placeholders',
        );
      }

      // Replace placeholders with config values
      String fastlaneContent = fastlaneTemplate
          .replaceAll('%key_id%', keyId!)
          .replaceAll('%issuer_id%', issuerId!)
          .replaceAll('%key_filepath%', keyFilepath!)
          .replaceAll('%app_identifier%', appIdentifier);

      // Means That IPAs are already built and exists
      if (skipBuild) {
        final iosIpaName = await Utils.iosIpaName;
        // Modify Display Name in fastfile ios
        fastlaneContent = fastlaneContent.replaceAll(
          '%display_name%',
          iosIpaName,
        );
      }

      // Write Fastfile for iOS
      final fastfile = File(Constants.iosFastfilePath);
      await fastfile.writeAsString(fastlaneContent);
    } on Exception {
      rethrow;
    }
  }

  Future<void> _createAndroidFastfile() async {
    try {
      print("Generating Fastfile from automate_config.yaml...");

      // Extract android section from YAML
      final androidConfig = _automateConfig.android;

      final jsonKeyPath = androidConfig['json_key_path']?.toString();
      final packageName = await Utils.androidPackageName;

      if (jsonKeyPath?.isEmpty ?? true) {
        throw Exception('Missing json_key_path in automate_config.yaml');
      }

      // Define Fastlane configuration for Android
      const fastlaneTemplate = Templates.androidFastFileContent;

      // Replace placeholders with config values
      final fastlaneContent = fastlaneTemplate
          .replaceAll('%json_key_path%', jsonKeyPath!)
          .replaceAll('%package_name%', packageName);

      // Write Fastfile for Android
      final fastfile = File(Constants.androidFastfilePath);
      await fastfile.writeAsString(fastlaneContent);

      print("Fastfile created at ${Constants.androidFastfilePath}");
    } on Exception {
      rethrow;
    }
  }

  Future<void> _createIosDeliveryFile() async {
    try {
      print("Generating Deliverfile from automate_config.yaml...");

      // Extract ios section from YAML
      final iosConfig = _automateConfig.ios;

      // Extract localized, unlocalized, and app review information
      final localizedInfo = iosConfig['info']['localized'] as YamlMap?;
      final unlocalizedInfo = iosConfig['info']['unlocalized'] as YamlMap?;
      final appReviewInfo =
          iosConfig['info']['app_review_information'] as YamlMap?;

      if (localizedInfo == null ||
          unlocalizedInfo == null ||
          appReviewInfo == null) {
        throw Exception('Missing required sections in ios configuration');
      }

      // Create or open Deliverfile
      final deliverFile = File(Constants.iosDeliverfilePath);
      if (!deliverFile.existsSync()) {
        deliverFile.createSync(recursive: true);
        print("Deliverfile created at ${Constants.iosDeliverfilePath}");
      }

      // Build Deliverfile content
      final buffer = StringBuffer();
      buffer.writeln(
        '# The Deliverfile allows you to store various App Store Connect metadata',
      );
      buffer.writeln('# For more information, check out the docs');
      buffer.writeln('# https://docs.fastlane.tools/actions/deliver/');
      buffer.writeln();

      // App Review Information
      buffer.writeln('app_review_information(');
      for (final entry in appReviewInfo.entries) {
        final key = entry.key as String;
        final value = entry.value as String;
        buffer.writeln('  $key: "$value",');
      }
      buffer.writeln(')');
      buffer.writeln();

      // Localized Fields
      for (final fieldEntry in localizedInfo.entries) {
        final fieldName = fieldEntry.key as String;
        final fieldData = fieldEntry.value as YamlMap;

        buffer.writeln('$fieldName(');
        if (fieldName != 'subtitle') {
          buffer.writeln('{');
        }
        for (final localeEntry in fieldData.entries) {
          final locale = localeEntry.key as String;
          final value = (localeEntry.value as String)
              .replaceAll('"', r'\"')
              .replaceAll('\n', r'\n');

          buffer.writeln('  "$locale" => "$value",');
        }
        if (fieldName != 'subtitle') {
          buffer.writeln('}');
        }
        buffer.writeln(')');
        buffer.writeln();
      }

      // Unlocalized Fields
      for (final entry in unlocalizedInfo.entries) {
        final key = entry.key as String;
        final value = entry.value as String;
        if (key == 'copyright') {
          buffer.writeln('$key("#{Time.now.year} $value")');
        } else {
          buffer.writeln('$key("$value")');
        }
        buffer.writeln();
      }

      // Write content to Deliverfile
      await deliverFile.writeAsString(buffer.toString());
      buffer.clear();
      print(
        "Deliverfile generated successfully at ${Constants.iosDeliverfilePath}",
      );
    } catch (e) {
      throw Exception('Failed to generate Deliverfile: $e');
    }
  }

  Future<void> _executeBuildFlow() async {
    try {
      if (!skipBuild) {
        await _buildProcess();
      }

      // Upload Process
      switch (mode) {
        case AutomateMode.beta:
          await _handleBetaBuild();
          break;
        case AutomateMode.release:
          await _handleIOSReleaseBuild();
          break;
        case AutomateMode.update:
          await _handleUpdateBuild();
          break;
        case AutomateMode.none:
          break;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _buildProcess() async {
    await _runCommand(
      'flutter',
      arguments: ['clean'],
      description: 'Cleaning project',
    );
    await _runCommand(
      'flutter',
      arguments: ['pub', 'get'],
      description: 'Fetching dependencies',
    );

    // Increment version only if not android beta
    if (!(platform == AutomatePlatform.android && mode == AutomateMode.beta)) {
      await PubspecUtils.incrementVersion();
    }

    // Build Process
    switch (platform) {
      case AutomatePlatform.all:
        if (mode == AutomateMode.beta) {
          await _buildAndroidApk();
        } else {
          await _buildAndroidAppBundle();
        }

        await _buildIOS();
        break;
      case AutomatePlatform.ios:
        await _buildIOS();
        break;
      case AutomatePlatform.android:
        if (mode == AutomateMode.beta) {
          await _buildAndroidApk();
        } else {
          await _buildAndroidAppBundle();
        }
        break;
    }
  }

  Future<void> _buildAndroidApk() async {
    await _runCommand(
      'flutter',
      arguments: ['build', "apk", "--release"],
      description: 'Building Android APK',
    );
  }

  Future<void> _buildAndroidAppBundle() async {
    await _runCommand(
      'flutter',
      arguments: [
        'build',
        "appbundle",
        "--release",
        "--obfuscate",
        "--split-debug-info=build/app/outputs/symbols",
      ],
      description: 'Building Android AppBundle',
    );
  }

  Future<void> _buildIOS() async {
    await _runCommand(
      'pod',
      arguments: ['install', '--repo-update'],
      description: 'Installing CocoaPods',
      workingDir: 'ios',
    );
    await _runCommand(
      'pod',
      arguments: ['update'],
      description: 'Updating CocoaPods',
      workingDir: 'ios',
    );
    await _runCommand(
      'flutter',
      arguments: [
        'build',
        "ipa",
        "--release",
        "--obfuscate",
        "--split-debug-info=build/ios/symbols",
      ],
      description: 'Building iOS IPA',
    );

    // Modify Display Name in fastfile ios
    final iosIpaName = await Utils.iosIpaName;
    final fastfile = File(Constants.iosFastfilePath);
    String fastfileContent = await fastfile.readAsString();
    fastfileContent = fastfileContent.replaceAll('%display_name%', iosIpaName);
    await fastfile.writeAsString(fastfileContent);
  }

  Future<void> _handleBetaBuild() async {
    switch (platform) {
      case AutomatePlatform.all:
        await _uploadToTestFlight();
        await _buildAndroidApk();
        break;
      case AutomatePlatform.ios:
        await _uploadToTestFlight();
        break;
      case AutomatePlatform.android:
        await _buildAndroidApk();
        break;
    }
  }

  Future<void> _uploadToTestFlight() async {
    await _runCommand(
      'fastlane',
      arguments: ['beta'],
      description: 'Uploading to TestFlight',
      workingDir: 'ios',
    );
  }

  Future<void> _handleUpdateBuild() async {
    switch (platform) {
      case AutomatePlatform.all:
        await _handleIOSUpdateBuild();
        await _handleAndroidUpdateBuild();
        break;
      case AutomatePlatform.ios:
        await _handleIOSUpdateBuild();
        break;
      case AutomatePlatform.android:
        await _handleAndroidUpdateBuild();
        break;
    }
  }

  Future<void> _handleIOSUpdateBuild() async {
    try {
      print("Extracting changelog from automate_config.yaml...");
      final YamlMap? changeLog = _automateConfig.ios['changelog'] as YamlMap?;
      if (changeLog == null || changeLog.isEmpty || changeLog.value.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.yaml',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in automate_config.yaml',
            );
          }
        }
      }

      print("Changelog extracted successfully.");

      // Check if Deliverfile exists
      final deliverFile = File(Constants.iosDeliverfilePath);
      if (!deliverFile.existsSync()) {
        deliverFile.createSync();
        print(
          "Deliverfile not found at ${Constants.iosDeliverfilePath}, creating...",
        );
      }

      // Read Deliverfile content
      String content = await deliverFile.readAsString();

      //Prepare changelog for Deliverfile
      final buffer = StringBuffer('\nrelease_notes({');
      for (final locale in changeLog.keys) {
        final message = changeLog[locale] as String;
        final escapedMessage = message.replaceAll('"', r'\"')
          ..replaceAll('\n', r'\n');
        buffer.writeln("  '$locale' => \"$escapedMessage\",");
      }
      buffer.write('})');
      final releaseNotesContent = buffer.toString();

      final releaseNotesPattern = RegExp(
        r'release_notes\s*\(\s*\{[^}]*\}\s*\)',
        multiLine: true,
      );

      if (releaseNotesPattern.hasMatch(content)) {
        print("Existing release notes found. Replacing...");
        content = content.replaceFirst(
          releaseNotesPattern,
          releaseNotesContent,
        );
      } else {
        print("No existing release notes found. Appending...");
        content += releaseNotesContent;
      }

      await deliverFile.writeAsString(content);
      print("Deliverfile updated successfully.");

      print("Uploading new update to distribution...");
      await _runCommand(
        'fastlane',
        arguments: ['new_update'],
        description: 'Uploading new update to distribution',
        workingDir: 'ios',
      );
    } on Exception {
      rethrow;
    }
  }

  Future<void> _handleAndroidUpdateBuild() async {
    try {
      print("Extracting changelog from automate_config.yaml...");
      final YamlMap? changeLog =
          _automateConfig.android['changelog'] as YamlMap?;
      if (changeLog == null || changeLog.isEmpty || changeLog.value.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.yaml',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in automate_config.yaml',
            );
          }
        }
      }

      print("Changelog extracted successfully.");

      // Creating metadata directory | android/metadata/android/en-US and for each locale/changelogs/14.txt
      final metadataDir = Directory(Constants.androidFastlaneMetadataDirPath);
      if (!metadataDir.existsSync()) {
        metadataDir.createSync();
      }

      final appVersion = await PubspecUtils.appVersion;
      final versionCode = appVersion.split('+').last;

      for (final locale in changeLog.keys) {
        final message = changeLog[locale] as String;
        final escapedMessage = message.replaceAll('"', r'\"')
          ..replaceAll('\n', r'\n');

        final changelogDirPath =
            "${metadataDir.path}/android/$locale/changelogs";
        final changelogsDir = Directory(changelogDirPath);

        if (!changelogsDir.existsSync()) {
          changelogsDir.createSync(recursive: true);
        } else {
          // remove old changelogs in changelogsDir
          changelogsDir.listSync().forEach((file) {
            file.deleteSync();
          });
        }

        final changelogFile = File("$changelogDirPath/$versionCode.txt");
        if (!changelogFile.existsSync()) {
          changelogFile.createSync(recursive: true);
        }

        await changelogFile.writeAsString(escapedMessage);
        print(
          "Changelog for $locale created in ${changelogFile.path} successfully.",
        );
      }

      print("Uploading new update to distribution...");
      await _runCommand(
        'fastlane',
        arguments: ['new_update'],
        description: 'Uploading new update to distribution',
        workingDir: 'android',
      );
    } on Exception {
      rethrow;
    }
  }

  Future<void> _handleIOSReleaseBuild() async {
    try {
      await _createIosDeliveryFile();

      print("Uploading new release to distribution...");
      await _runCommand(
        'fastlane',
        arguments: ['release'],
        description: 'Uploading new release to distribution',
        workingDir: 'ios',
      );

      print("Release uploaded successfully!.");
      print("-----------------------------------");

      await _uploadIosAppPrivacy();
    } on Exception {
      rethrow;
    }
  }

  Future<void> _uploadIosAppPrivacy() async {
    print("Trying to upload the app privacy details...");
    print("It may fails if it is the first time you are uploading a release.");
    print(
      "Because the uploading of the app privacy details require interactive from you to login in app store connect.",
    );
    print(
      "If it fails, please run this command 'fastlane upload_app_privacy' in your terminal in ios directory.",
    );
    try {
      await _runCommand(
        'fastlane',
        arguments: ['upload_app_privacy'],
        description: 'Uploading app privacy details',
        workingDir: 'ios',
      );
    } on Exception catch (e) {
      print("Error uploading app privacy details: $e");
      throw Exception(
        "Try to run this command 'fastlane upload_app_privacy' in your terminal in ios directory.",
      );
    }
  }

  Future<void> _runCommand(
    String executable, {
    List<String> arguments = const [],
    String? description,
    String? workingDir,
  }) async {
    print('Running: $description...');
    try {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory:
            workingDir != null ? '$_projectDir/$workingDir' : _projectDir,
        runInShell: true,
      );
      // Listen to stdout
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        stdout.write(data); // Print directly to terminal
      });

      // Listen to stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderr.write(data); // Print errors
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception('Command failed with exit code $exitCode');
      }
    } catch (e) {
      throw Exception('Error running command: $e');
    }
  }
}

void main(List<String> arguments) async {
  final script = AutomateScript();
  try {
    await script.run(arguments);
  } catch (e) {
    print(e);
    exit(1);
  }
}
