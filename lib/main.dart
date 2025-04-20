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

    if (await _isFastlaneInitialized()) {
      await _executeBuildFlow(args);
    } else {
      await _initializeFastlane();
    }
  }

  ArgParser _createArgParser() {
    return ArgParser()
      ..addFlag('beta', help: 'Run beta build and deployment')
      ..addFlag('release', help: 'Run release build and deployment')
      ..addOption('platform',
          allowed: ['ios', 'android'], help: 'Target platform')
      ..addFlag('firebase',
          help: 'Use Firebase App Distribution for Android beta');
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
      await _runCommand('cd ios && fastlane init', 'iOS');

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
        throw Exception('Missing ios.app_store_connect in automate_config.yaml');
      }
      final keyId = iosConfig['key_id']?.toString();
      final issuerId = iosConfig['issuer_id']?.toString();
      final keyFilepath = iosConfig['key_filepath']?.toString();
      if (keyId == null || issuerId == null || keyFilepath == null) {
        throw Exception(
            'Missing key_id, issuer_id, or key_filepath in automate_config.yaml');
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
      await _runCommand('cd android && fastlane init', 'Android');
    } catch (e) {
      throw Exception('Failed to initialize Android Fastlane: $e');
    }
  }

  Future<void> _executeBuildFlow(ArgResults args) async {
    try {
      await _runCommand('flutter clean', 'Cleaning project');
      await _runCommand('flutter pub get', 'Fetching dependencies');

      final platform = args['platform'];
      final isFirebase = args['firebase'] as bool;

      if (args['beta']) {
        await _handleBetaBuild(platform, isFirebase);
      } else if (args['release']) {
        await _handleReleaseBuild(platform);
      } else {
        print('Please specify --beta or --release.');
        exit(1);
      }
    } catch (e) {
      print('Build flow failed: $e');
      exit(1);
    }
  }

  Future<void> _handleBetaBuild(String? platform, bool isFirebase) async {
    if (platform == null) {
      print('Please specify --platform (ios or android).');
      exit(1);
    }

    if (platform == 'ios') {
      await _incrementBuildNumber();
      await _runCommand('flutter build ipa --release', 'Building iOS IPA');
      await _runCommand('cd ios && fastlane beta', 'Uploading to TestFlight');
    } else if (platform == 'android') {
      if (isFirebase) {
        await _runCommand(
            'flutter build appbundle --release', 'Building Android AppBundle');
        await _uploadToFirebaseAppDistribution();
      } else {
        await _runCommand('flutter build apk --release', 'Building Android APK');
      }
    }
  }

  Future<void> _handleReleaseBuild(String? platform) async {
    if (platform == null) {
      print('Please specify --platform (ios or android).');
      exit(1);
    }

    await _incrementVersionAndBuildNumber();

    if (platform == 'ios') {
      await _runCommand('flutter build ipa --release', 'Building iOS IPA');
      await _runCommand('cd ios && fastlane release', 'Uploading to App Store');
    } else if (platform == 'android') {
      await _runCommand(
          'flutter build appbundle --release', 'Building Android AppBundle');
      await _runCommand(
          'cd android && fastlane release', 'Uploading to Play Store');
    }
  }

  Future<void> _incrementBuildNumber() async {
    final pubspec = await _readPubspec();
    final version = pubspec['version'].toString();
    final parts = version.split('+');
    final versionNumber = parts[0];
    final buildNumber = int.parse(parts[1]) + 1;

    await _writePubspec('$versionNumber+$buildNumber');
    print('Incremented build number to $buildNumber');
  }

  Future<void> _incrementVersionAndBuildNumber() async {
    final pubspec = await _readPubspec();
    final version = pubspec['version'].toString();
    final parts = version.split('+');
    final versionParts = parts[0].split('.');
    final minor = int.parse(versionParts[1]) + 1;
    final newVersion = '${versionParts[0]}.$minor.0';
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
    final updatedContent =
    content.replaceFirst(RegExp(r'version: .+'), 'version: $newVersion');
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
          'Missing token or app_id in android.firebase in automate_config.yaml');
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