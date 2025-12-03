import 'dart:io';
import 'package:args/args.dart';
import 'package:automate/automate_config.dart';
import 'package:automate/automate_enums.dart';
import 'package:automate/constants.dart';
import 'package:automate/templates.dart';
import 'package:automate/pubspec_utils.dart';
import 'package:automate/utils.dart';

class AutomateScript {
  AutomatePlatform platform = AutomatePlatform.all;
  late AutomateMode mode;
  final AutomateConfig _automateConfig = AutomateConfig.instance;
  bool skipBuild = false;
  final String _projectDir = Directory.current.path;

  Future<void> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      throw Exception('Error: Mode (beta or update) must be provided.');
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
    if (['beta', 'update'].contains(firstArgument)) {
      mode = firstArgument.toAutomateMode();
    } else if (args['skip-build'] ?? false) {
      skipBuild = true;
    } else if (firstArgument == 'init') {
      await _init();

      exit(0);
    } else {
      throw Exception(
        'Error: Invalid mode "${arguments.first}". Must be one of: beta, update.',
      );
    }

    // load automate_config.json
    await _automateConfig.load();

    await _initializeFastlane();

    print("\nSkipping build process: ${args['skip-build']}\n");
    await _executeBuildFlow();
  }

  Future<void> _init() async {
    print('Initializing Automate...');

    // Adding automate_config.json in gitignore
    if (File(Constants.gitignorePath).existsSync()) {
      const formattedPath = '/automate_config.json';
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

    // Generate automate_config.json
    print(
      'Creating in automate directory ${Constants.automateConfigFilePath}...',
    );
    _writeToFile(
      Constants.automateConfigFilePath,
      content: Templates.automateConfigContent,
    );
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
          'Missing key_id, issuer_id, or key_filepath in automate_config.json',
        );
      }

      final appIdentifier = await Utils.iosBundleId;

      // Get TestFlight configuration (optional)
      final testflightConfig = _automateConfig.testflightConfig;
      final enableExternalTesting =
          testflightConfig?['enable_external_testing'] as bool? ?? false;

      // Build external testing config if enabled
      String externalTestingConfig = '';
      if (enableExternalTesting) {
        // Validate required fields for external testing
        final groups = testflightConfig?['groups']?.toString();
        final betaAppFeedbackEmail =
            testflightConfig?['beta_app_feedback_email']?.toString();
        final betaAppReviewInfo =
            testflightConfig?['beta_app_review_info'] as Map<String, dynamic>?;

        if (groups?.isEmpty ?? true) {
          throw Exception(
            'Missing testflight.groups in automate_config.json (required for external testing)',
          );
        }

        if (betaAppFeedbackEmail?.isEmpty ?? true) {
          throw Exception(
            'Missing testflight.beta_app_feedback_email in automate_config.json (required for external testing)',
          );
        }

        if (betaAppReviewInfo == null) {
          throw Exception(
            'Missing testflight.beta_app_review_info in automate_config.json (required for external testing)',
          );
        }

        // Validate beta_app_review_info required fields
        final requiredReviewFields = [
          'contact_email',
          'contact_first_name',
          'contact_last_name',
          'contact_phone',
        ];

        for (final field in requiredReviewFields) {
          final value = betaAppReviewInfo[field]?.toString();
          if (value?.isEmpty ?? true) {
            throw Exception(
              'Missing testflight.beta_app_review_info.$field in automate_config.json (required for external testing)',
            );
          }
        }

        // Check if demo account is required
        final demoAccountRequired =
            betaAppReviewInfo['demo_account_required'] as bool? ?? false;

        // Validate demo account fields only if demo_account_required is true
        if (demoAccountRequired) {
          final demoAccountFields = [
            'demo_account_name',
            'demo_account_password',
          ];
          for (final field in demoAccountFields) {
            final value = betaAppReviewInfo[field]?.toString();
            if (value?.isEmpty ?? true) {
              throw Exception(
                'Missing testflight.beta_app_review_info.$field in automate_config.json (required when demo_account_required is true)',
              );
            }
          }
        }

        // Build the external testing configuration
        final notes = betaAppReviewInfo['notes']?.toString() ?? '';
        final buffer = StringBuffer();
        buffer.writeln();
        buffer.writeln('      groups: "$groups",');
        buffer.writeln(
          '      beta_app_feedback_email: "$betaAppFeedbackEmail",',
        );
        buffer.writeln('      beta_app_review_info: {');
        buffer.writeln(
          '        contact_email: "${betaAppReviewInfo['contact_email']}",',
        );
        buffer.writeln(
          '        contact_first_name: "${betaAppReviewInfo['contact_first_name']}",',
        );
        buffer.writeln(
          '        contact_last_name: "${betaAppReviewInfo['contact_last_name']}",',
        );
        buffer.writeln(
          '        contact_phone: "${betaAppReviewInfo['contact_phone']}",',
        );
        buffer.writeln('        demo_account_required: $demoAccountRequired,');
        if (demoAccountRequired) {
          buffer.writeln(
            '        demo_account_name: "${betaAppReviewInfo['demo_account_name']}",',
          );
          buffer.writeln(
            '        demo_account_password: "${betaAppReviewInfo['demo_account_password']}",',
          );
        }
        if (notes.isNotEmpty) {
          buffer.writeln('        notes: "$notes",');
        }
        buffer.write('      },');
        externalTestingConfig = buffer.toString();
      }

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
          .replaceAll('%app_identifier%', appIdentifier)
          .replaceAll(
            '%enable_external_testing%',
            enableExternalTesting.toString(),
          )
          .replaceAll('%external_testing_config%', externalTestingConfig);

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
      print("Generating Fastfile from automate_config.json...");

      // Extract android section from config
      final androidConfig = _automateConfig.android;

      final jsonKeyPath = androidConfig['json_key_path']?.toString();
      final packageName = await Utils.androidPackageName;

      if (jsonKeyPath?.isEmpty ?? true) {
        throw Exception('Missing json_key_path in automate_config.json');
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
      print("Extracting changelog from automate_config.json...");
      final Map<String, dynamic>? changeLog =
          _automateConfig.ios['changelog'] as Map<String, dynamic>?;
      if (changeLog == null || changeLog.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.json',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in automate_config.json',
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
      print("Extracting changelog from automate_config.json...");
      final Map<String, dynamic>? changeLog =
          _automateConfig.android['changelog'] as Map<String, dynamic>?;
      if (changeLog == null || changeLog.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in automate_config.json',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in automate_config.json',
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
