import 'dart:io';
import 'package:args/args.dart';
import 'package:automate/automate_config.dart';
import 'package:automate/automate_enums.dart';
import 'package:automate/automate_strings.dart';
import 'package:automate/pubspec_utils.dart';
import 'package:yaml/yaml.dart';

class AutomateScript {
  late AutomatePlatform platform;
  late AutomateMode mode;

  final String _projectDir = Directory.current.path;
  final AutomateConfig _automateConfig = AutomateConfig.instance;

  Future<void> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      throw Exception(
        'Error: Mode (beta, release, or update) must be provided.',
      );
    }

    if (['beta', 'release', 'update'].contains(arguments.first)) {
      mode = arguments.first.toAutomateMode();
    } else {
      throw Exception(
        'Error: Invalid mode "${arguments.first}". Must be one of: beta, release, update.',
      );
    }

    final restArguments = arguments.skip(1).toList(); // optional named args

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

    // load automate_config.yaml
    await _automateConfig.load();

    // Check if Fastlane is installed
    await _checkFastLane();

    if (!_isFastlaneInitialized()) {
      await _initializeFastlane();
    }
    await _executeBuildFlow();
  }

  Future<void> _checkFastLane() async {
    await _runCommand(
      "fastlane",
      arguments: ["--version"],
      description: "Fastlane version",
    );
  }

  bool _isFastlaneInitialized() {
    if (platform == AutomatePlatform.ios) {
      return Directory('$_projectDir/ios/fastlane').existsSync();
    } else if (platform == AutomatePlatform.android) {
      return Directory('$_projectDir/android/fastlane').existsSync();
    }
    return Directory('$_projectDir/ios/fastlane').existsSync() &&
        Directory('$_projectDir/android/fastlane').existsSync();
  }

  Future<void> _initializeFastlane() async {
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
      final iosDir = Directory('$_projectDir/ios');
      if (!iosDir.existsSync()) {
        throw Exception(
          'iOS directory not found at $_projectDir/ios. Ensure this is a valid Flutter project with an iOS module.',
        );
      }

      // Ensure fastlane directory exists
      final fastlaneDir = Directory('$_projectDir/ios/fastlane');
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      // Extract App Store Connect API key values
      final appStoreConfig = _automateConfig.appStoreConfig;

      final keyId = appStoreConfig['key_id']?.toString();
      final issuerId = appStoreConfig['issuer_id']?.toString();
      final keyFilepath = appStoreConfig['key_filepath']?.toString();
      if (keyId == null || issuerId == null || keyFilepath == null) {
        throw Exception(
          'Missing key_id, issuer_id, or key_filepath in automate_config.yaml',
        );
      }

      // Define Fastlane configuration for iOS
      const fastlaneTemplate = AutomateStrings.fastFileContent;

      // Check for placeholder if key_id, issuer_id, or key_filepath is missing
      if (!fastlaneTemplate.contains('%key_id%') &&
          !fastlaneTemplate.contains('%issuer_id%') &&
          !fastlaneTemplate.contains('%key_filepath%')) {
        throw Exception(
          'Error: Missing key_id, issuer_id, or key_filepath in Fastlane template Must be all of: %key_id%, %issuer_id%, %key_filepath% existing in Fastlane template as placeholders',
        );
      }

      // Replace placeholders with config values
      final fastlaneContent = fastlaneTemplate
          .replaceAll('%key_id%', keyId)
          .replaceAll('%issuer_id%', issuerId)
          .replaceAll('%key_filepath%', keyFilepath);

      // Write Fastfile for iOS
      final fastfile = File('$_projectDir/ios/fastlane/Fastfile');
      await fastfile.writeAsString(fastlaneContent);
      print('IOS Fastlane initialized successfully.');
    } catch (e) {
      throw Exception('Failed to initialize iOS Fastlane: $e');
    }
  }

  Future<void> _initializeAndroidFastlane() async {
    print('Initializing Fastlane for Android...');
    // Check if android directory exists
    final androidDir = Directory('$_projectDir/android');
    if (!androidDir.existsSync()) {
      throw Exception(
        'Android directory not found at $_projectDir/android. Ensure this is a valid Flutter project with an Android module.',
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

      // Increment version
      await PubspecUtils.incrementVersion();

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
      arguments: ['build', "appbundle", "--release"],
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
        //  await _uploadToFirebaseAppDistribution();
        break;
      case AutomatePlatform.ios:
        await _uploadToTestFlight();
        break;
      case AutomatePlatform.android:
        //  await _uploadToFirebaseAppDistribution();
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
      final YamlMap? changeLog = _automateConfig.info['changelog'] as YamlMap?;
      if (changeLog == null) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.yaml',
        );
      }
      print("Changelog extracted successfully.");

      // Try to extract metadata path from config if it exists or use default "$_projectDir/ios/fastlane/metadata"
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
      print("Metadata generated successfully.");

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
