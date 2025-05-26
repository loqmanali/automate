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
        ArgParser()..addOption(
          'platform',
          allowed: ['ios', 'android'],
          help: 'Target platform',
          abbr: 'p',
        );

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
      mode = firstArgument.toAutomateMode();
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

    // await _executeBuildFlow();
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
      print('Adding ${Constants.automateConfigFilePath} to .gitignore...');
      // Read .gitignore file
      final gitignoreContent = File(Constants.gitignorePath).readAsStringSync();
      final formattedPath =
          Constants.automateConfigFilePath
              .split('/automate/automate_config.yaml')
              .first;

      if (!gitignoreContent.contains(formattedPath)) {
        // Write .gitignore file with new line
        File(
          Constants.gitignorePath,
        ).writeAsStringSync('$gitignoreContent\n$formattedPath');
      } else {
        print('automate_config.yaml already added to .gitignore.');
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

  Future<bool> _isFastlaneInitialized() async {
    await _runCommand(
      "fastlane",
      arguments: ["--version"],
      description: "Fastlane version",
    );

    if (platform == AutomatePlatform.ios) {
      return Directory(Constants.iosFastlaneDirPath).existsSync();
    } else if (platform == AutomatePlatform.android) {
      return Directory(Constants.androidFastlaneDirPath).existsSync();
    }
    return Directory(Constants.iosFastlaneDirPath).existsSync() &&
        Directory(Constants.androidFastlaneDirPath).existsSync();
  }

  Future<void> _initializeFastlane() async {
    if (await _isFastlaneInitialized()) {
      print('Fastlane already initialized.');
      return;
    }
    print('Initializing Fastlane...');
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

      // Extract App Store Connect API key values
      await _createIosFastfile();
      await _createIosDeliveryFile();

      print('IOS Fastlane initialized successfully.');
    } catch (e) {
      throw Exception('Failed to initialize iOS Fastlane: $e');
    }
  }

  Future<void> _createIosFastfile() async {
    // Extract App Store Connect API key values
    final appStoreConfig = _automateConfig.appStoreConfig;

    final keyId = appStoreConfig['key_id']?.toString();
    final issuerId = appStoreConfig['issuer_id']?.toString();
    final keyFilepath = appStoreConfig['key_filepath']?.toString();
    final username = appStoreConfig['username']?.toString();
    final teamId = appStoreConfig['team_id']?.toString();
    if (keyId == null ||
        issuerId == null ||
        keyFilepath == null ||
        username == null ||
        teamId == null) {
      throw Exception(
        'Missing key_id, issuer_id, username, team_id or key_filepath in automate_config.yaml',
      );
    }

    final appIdentifier = await Utils.getIosBundleId;

    // Define Fastlane configuration for iOS
    const fastlaneTemplate = Templates.iosFastFileContent;

    // Check for placeholder if key_id, issuer_id, or key_filepath is missing
    if (!fastlaneTemplate.contains('%key_id%') &&
        !fastlaneTemplate.contains('%issuer_id%') &&
        !fastlaneTemplate.contains('%key_filepath%') &&
        !fastlaneTemplate.contains('%username%') &&
        !fastlaneTemplate.contains('%team_id%') &&
        !fastlaneTemplate.contains('%app_identifier%')) {
      throw Exception(
        'Error: Missing key_id, issuer_id, app_identifier, username, team_id or key_filepath in Fastlane template Must be all of: %key_id%, %issuer_id%, %key_filepath%, %app_identifier%, %team_id% or %username% existing in Fastlane template as placeholders',
      );
    }

    // Replace placeholders with config values
    final fastlaneContent = fastlaneTemplate
        .replaceAll('%key_id%', keyId)
        .replaceAll('%issuer_id%', issuerId)
        .replaceAll('%key_filepath%', keyFilepath)
        .replaceAll('%username%', username)
        .replaceAll('%team_id%', teamId)
        .replaceAll('%app_identifier%', appIdentifier);

    // Write Fastfile for iOS
    final fastfile = File(Constants.iosFastfilePath);
    await fastfile.writeAsString(fastlaneContent);
  }

  Future<void> _createIosDeliveryFile() async {}

  Future<void> _initializeAndroidFastlane() async {
    print('Initializing Fastlane for Android...');
    // Check if android directory exists
    final androidDir = Directory(Constants.androidDirPath);
    if (!androidDir.existsSync()) {
      throw Exception(
        'Android directory not found at ${Constants.androidDirPath}. Ensure this is a valid Flutter project with an Android module.',
      );
    }
  }

  Future<void> _executeBuildFlow() async {
    try {
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
      if (!(platform == AutomatePlatform.android &&
          mode == AutomateMode.beta)) {
        await PubspecUtils.incrementVersion();
      }

      // Build Process
      switch (platform) {
        case AutomatePlatform.all:
          await _buildAndroid();
          await _buildIOS();
          break;
        case AutomatePlatform.ios:
          await _buildIOS();
          break;
        case AutomatePlatform.android:
          await _buildAndroid();
          break;
      }

      // Upload Process
      switch (mode) {
        case AutomateMode.beta:
          await _handleBetaBuild();
          break;
        case AutomateMode.release:
          // await _handleReleaseBuild();
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

  Future<void> _buildAndroid() async {
    await _runCommand(
      'flutter',
      arguments: ['build', "apk", "--release"],
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
      'flutter',
      arguments: ['build', "ipa", "--release"],
      description: 'Building iOS IPA',
    );
  }

  Future<void> _handleBetaBuild() async {
    switch (platform) {
      case AutomatePlatform.all:
        await _uploadToTestFlight();
        await _buildAndroid();

        break;
      case AutomatePlatform.ios:
        await _uploadToTestFlight();
        break;
      case AutomatePlatform.android:
        await _buildAndroid();
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
        //await _handleAndroidUpdateBuild();
        break;
      case AutomatePlatform.ios:
        await _handleIOSUpdateBuild();
        break;
      case AutomatePlatform.android:
        //await _handleAndroidUpdateBuild();
        break;
    }
  }

  Future<void> _handleIOSUpdateBuild() async {
    try {
      print("Extracting changelog from automate_config.yaml...");
      final YamlMap? changeLog = _automateConfig.ios['changelog'] as YamlMap?;
      if (changeLog == null) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.yaml',
        );
      }
      print("Changelog extracted successfully.");

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

      /*      // Try to extract metadata path from config if it exists or use default "$_projectDir/fastlane/metadata"
      print("Trying to extract metadata path from automate_config.yaml...");
      String? metadataPath = _automateConfig.ios['metadata_path'] as String?;
      if (metadataPath?.isEmpty ?? true) {
        print(
          "No metadata path found in automate_config.yaml, using default path ios/fastlane/metadata....",
        );
        metadataPath = '$_projectDir/ios/fastlane/metadata';
      }

      // Generate metadata directory and its localization files for fastlane
      final metadataDir = Directory(metadataPath!);
      if (!metadataDir.existsSync()) {
        print("Metadata directory not found at $metadataPath, creating...");
        metadataDir.createSync();
      }

      // Edit FastFile to Replace %metadata_path% placeholder with real value
      final fastFile = File('$_projectDir/ios/fastlane/Fastfile');
      if (!fastFile.existsSync()) {
        throw Exception('Fastfile not found at $_projectDir/ios/fastlane/Fastfile');
      }
      final fastFileContent = await fastFile.readAsString();
      final newFastFileContent = fastFileContent.replaceAll(
        '%metadata_path%',
        metadataPath,
      );
      fastFile.writeAsStringSync(newFastFileContent);
      print("Fastfile updated with metadata path successfully.");

      // Loop through each language
      for (final language in changeLog.keys) {
        final languageMetadataDir = Directory('$metadataPath/$language');
        if (!languageMetadataDir.existsSync()) {
          print(
            "Metadata directory not found at $metadataPath/$language, creating...",
          );
          languageMetadataDir.createSync();
        }

        final languageMetadataFile = File(
          '$metadataPath/$language/release_notes.txt',
        );
        if (!languageMetadataFile.existsSync()) {
          print(
            "Writing changelog to $metadataPath/$language/release_notes.txt...",
          );
          languageMetadataFile.writeAsStringSync(
            changeLog[language].toString(),
          );
        }
      }
      print("Metadata generated successfully.");*/

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
