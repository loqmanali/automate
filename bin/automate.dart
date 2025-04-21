import 'dart:io';
import 'package:args/args.dart';
import 'package:process_run/shell.dart';
import 'package:yaml/yaml.dart';

class BuildScript {
  final Shell shell = Shell();
  final String projectDir = Directory.current.path;

  Future<void> run(List<String> arguments) async {
    final parser = _createArgParser();
    final ArgResults args;

    try {
      args = parser.parse(arguments);
    } catch (e) {
      print('Error parsing arguments: $e');
      print(parser.usage);
      exit(1);
    }

    // Validate that exactly one of --beta or --release is provided
    if (!(args['beta'] as bool) && !(args['release'] as bool)) {
      print('Error: You must specify either --beta or --release.');
      print(parser.usage);
      exit(1);
    }

    // Check if Fastlane is installed
    try {
      await shell.run('fastlane --version');
    } catch (e) {
      print(
        'Error: Fastlane is not installed or not accessible. Please install Fastlane using `gem install fastlane`.',
      );
      exit(1);
    }

    if (!await _isFastlaneInitialized()) {
      await _initializeFastlane();
    }
    await _executeBuildFlow(args);
  }

  ArgParser _createArgParser() {
    return ArgParser()
      ..addFlag('beta', help: 'Run beta build and deployment', negatable: false)
      ..addFlag(
        'release',
        help: 'Run release build and deployment',
        negatable: false,
      )
      ..addOption(
        'platform',
        allowed: ['ios', 'android'],
        help: 'Target platform (required)',
        mandatory: true,
      )
      ..addFlag(
        'firebase',
        help: 'Use Firebase App Distribution for Android beta (optional)',
        negatable: false,
      );
  }

  Future<bool> _isFastlaneInitialized() async {
    return Directory('$projectDir/ios/fastlane').existsSync() &&
        Directory('$projectDir/android/fastlane').existsSync();
  }

  Future<void> _initializeFastlane() async {
    print('Initializing Fastlane...');
    try {
      await _initializeIosFastlane();
      await _initializeAndroidFastlane();
      print('Fastlane initialized successfully.');
    } catch (e) {
      print('Failed to initialize Fastlane: $e');
      exit(1);
    }
  }

  Future<void> _initializeIosFastlane() async {
    print('Initializing Fastlane for iOS...');
    try {
      // Check if ios directory exists
      final iosDir = Directory('$projectDir/ios');
      if (!iosDir.existsSync()) {
        throw Exception(
          'iOS directory not found at $projectDir/ios. Ensure this is a valid Flutter project with an iOS module.',
        );
      }

      // Ensure fastlane directory exists
      final fastlaneDir = Directory('$projectDir/ios/fastlane');
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      // Read automate_config.yaml
      final configFile = File('$projectDir/automate_config.yaml');
      if (!configFile.existsSync()) {
        throw Exception('automate_config.yaml not found in project root');
      }
      final configContent = await configFile.readAsString();
      final config = loadYaml(configContent) as YamlMap;

      // Extract App Store Connect API key values
      final iosConfig = config['ios']?['app_store_connect'] as YamlMap?;
      if (iosConfig == null) {
        throw Exception(
          'Missing ios.app_store_connect in automate_config.yaml',
        );
      }
      final keyId = iosConfig['key_id']?.toString();
      final issuerId = iosConfig['issuer_id']?.toString();
      final keyFilepath = iosConfig['key_filepath']?.toString();
      if (keyId == null || issuerId == null || keyFilepath == null) {
        throw Exception(
          'Missing key_id, issuer_id, or key_filepath in automate_config.yaml',
        );
      }

      // Define Fastlane configuration for iOS
      const fastlaneTemplate = '''
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools
#
# For a list of all available actions, check out
#
#     https://docs.fastlane.tools/actions
#
# For a list of all available plugins, check out
#
#     https://docs.fastlane.tools/plugins/available-plugins
#

# Uncomment the line if you want fastlane to automatically update itself
# update_fastlane

default_platform(:ios)

platform :ios do

  desc "Upload New Build to Test Flight"
  lane :beta do
    api_key = app_store_connect_api_key(
      key_id: "%key_id%",
      issuer_id: "%issuer_id%",
      key_filepath: "%key_filepath%",
    )

    pilot(api_key: api_key,
      ipa: "../build/ios/ipa/Banic.ipa",
      distribute_external: false,
      notify_external_testers: false,
      expire_previous_builds: true,
      groups: "Testers",
    )
  end
end
''';

      // Replace placeholders with config values
      final fastlaneContent = fastlaneTemplate
          .replaceAll('%key_id%', keyId)
          .replaceAll('%issuer_id%', issuerId)
          .replaceAll('%key_filepath%', keyFilepath);

      // Write Fastfile for iOS
      final fastfile = File('$projectDir/ios/fastlane/Fastfile');
      await fastfile.writeAsString(fastlaneContent);
      print('iOS Fastfile overwritten successfully');
    } catch (e) {
      throw Exception('Failed to initialize iOS Fastlane: $e');
    }
  }

  Future<void> _initializeAndroidFastlane() async {
    print('Initializing Fastlane for Android...');
    try {
      // Check if android directory exists
      final androidDir = Directory('$projectDir/android');
      if (!androidDir.existsSync()) {
        throw Exception(
          'Android directory not found at $projectDir/android. Ensure this is a valid Flutter project with an Android module.',
        );
      }

      // Run fastlane init with piped input to select manual setup
      await _runCommand(
        'cd android && echo -e "4\\n\\n\\n" | fastlane init',
        'Android',
      );
    } catch (e) {
      throw Exception('Failed to initialize Android Fastlane: $e');
    }
  }

  Future<void> _executeBuildFlow(ArgResults args) async {
    try {
      await _runCommand('flutter clean', 'Cleaning project');
      await _runCommand('flutter pub get', 'Fetching dependencies');

      final platform = args['platform'];
      final useFirebase = args['firebase'] as bool;

      if (args['beta']) {
        await _handleBetaBuild(platform, useFirebase);
      } else if (args['release']) {
        await _handleReleaseBuild(platform);
      }
    } catch (e) {
      print('Build flow failed: $e');
      exit(1);
    }
  }

  Future<void> _handleBetaBuild(String platform, bool useFirebase) async {
    if (platform == 'ios') {
      await _incrementVersionAndBuildNumber();
      await _runCommand('flutter build ipa --release', 'Building iOS IPA');
      await _runCommand('cd ios && fastlane beta', 'Uploading to TestFlight');
    } else if (platform == 'android') {
      if (useFirebase) {
        await _incrementVersionAndBuildNumber();
        await _runCommand(
          'flutter build appbundle --release',
          'Building Android AppBundle',
        );
        await _uploadToFirebaseAppDistribution();
      } else {
        await _incrementVersionAndBuildNumber();
        await _runCommand(
          'flutter build apk --release',
          'Building Android APK',
        );
      }
    }
  }

  Future<void> _handleReleaseBuild(String platform) async {
    await _incrementVersionAndBuildNumber();

    if (platform == 'ios') {
      await _runCommand('flutter build ipa --release', 'Building iOS IPA');
      await _runCommand('cd ios && fastlane release', 'Uploading to App Store');
    } else if (platform == 'android') {
      await _runCommand(
        'flutter build appbundle --release',
        'Building Android AppBundle',
      );
      await _runCommand(
        'cd android && fastlane release',
        'Uploading to Play Store',
      );
    }
  }

  Future<void> _incrementVersionAndBuildNumber() async {
    final pubspec = await _readPubspec();
    final version = pubspec['version'].toString();
    final parts = version.split('+');
    final versionParts = parts[0].split('.');
    final patch = int.parse(versionParts[2]) + 1;
    final newVersion = '${versionParts[0]}.${versionParts[1]}.$patch';
    final buildNumber = int.parse(parts[1]) + 1;

    await _writePubspec('$newVersion+$buildNumber');
    print('Incremented version to $newVersion, build number to $buildNumber');
  }

  Future<YamlMap> _readPubspec() async {
    final file = File('$projectDir/pubspec.yaml');
    if (!file.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }
    return loadYaml(await file.readAsString()) as YamlMap;
  }

  Future<void> _writePubspec(String newVersion) async {
    final file = File('$projectDir/pubspec.yaml');
    final content = await file.readAsString();
    final updatedContent = content.replaceFirst(
      RegExp(r'version: .+'),
      'version: $newVersion',
    );
    await file.writeAsString(updatedContent);
  }

  Future<void> _uploadToFirebaseAppDistribution() async {
    final configFile = File('$projectDir/automate_config.yaml');
    if (!configFile.existsSync()) {
      throw Exception('automate_config.yaml not found in project root');
    }
    final configContent = await configFile.readAsString();
    final config = loadYaml(configContent) as YamlMap;

    final androidConfig = config['android']?['firebase'] as YamlMap?;
    if (androidConfig == null) {
      throw Exception('Missing android.firebase in automate_config.yaml');
    }
    final firebaseToken = androidConfig['token']?.toString();
    final appId = androidConfig['app_id']?.toString();
    if (firebaseToken == null || appId == null) {
      throw Exception(
        'Missing token or app_id in android.firebase in automate_config.yaml',
      );
    }

    final command =
        'firebase appdistribution:distribute build/app/outputs/bundle/release/app-release.aab '
        '--app $appId --token $firebaseToken';
    await _runCommand(command, 'Uploading to Firebase App Distribution');
  }

  Future<void> _runCommand(String command, String description) async {
    print('Running: $description...');
    try {
      await shell.run(command);
    } catch (e) {
      throw Exception('Failed to run $description: $e');
    }
  }
}

void main(List<String> arguments) async {
  final script = BuildScript();
  await script.run(arguments);
}
