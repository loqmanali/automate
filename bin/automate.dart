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
  AutomateProvider provider = AutomateProvider.fastlane;
  late AutomateMode mode;
  final AutomateConfig _automateConfig = AutomateConfig.instance;
  bool skipBuild = false;
  String buildFlavor = '';
  String buildTarget = '';
  String selectedProfileName = '';
  Map<String, dynamic>? _selectedProfile;
  final String _projectDir = Directory.current.path;

  Future<void> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      throw Exception(
        'Error: Command is required. Use init, beta, update, or a profile like dev/staging/production.',
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
          ..addOption(
            'provider',
            allowed: ['fastlane', 'firebase'],
            help: 'Deployment provider',
            abbr: 'r',
          )
          ..addOption(
            'flavor',
            help: 'Flutter flavor / Xcode scheme / Android product flavor',
            abbr: 'f',
          )
          ..addOption(
            'target',
            help: 'Flutter target file, for example lib/main_staging.dart',
            abbr: 't',
          )
          ..addFlag("skip-build", abbr: "s", help: "Skip build process");

    final ArgResults args;

    try {
      args = parser.parse(restArguments);
    } catch (e) {
      throw Exception('Error parsing arguments: $e\n${parser.usage}');
    }

    if (firstArgument == 'init') {
      await _init();

      exit(0);
    }

    // load automate_config.json
    await _automateConfig.load();

    skipBuild = args['skip-build'] ?? false;

    if (_isDirectModeCommand(firstArgument)) {
      _configureDirectCommand(firstArgument, args);
    } else {
      _configureProfileCommand(firstArgument, args);
    }

    print("\nSkipping build process: $skipBuild\n");
    if (selectedProfileName.isNotEmpty) {
      print('Deployment profile: $selectedProfileName\n');
    }
    print('Deployment provider: ${provider.name}\n');
    if (buildFlavor.isNotEmpty) {
      print('Build flavor: $buildFlavor\n');
    }
    if (buildTarget.isNotEmpty) {
      print('Build target: $buildTarget\n');
    }

    if (provider == AutomateProvider.fastlane) {
      await _initializeFastlane();
    } else {
      await _initializeFirebase();
    }

    await _executeBuildFlow();
  }

  Future<void> _init() async {
    print('Initializing deployment setup...');

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
      'Creating deployment config at ${Constants.automateConfigFilePath}...',
    );
    final configContent = _promptInitConfigTemplate();
    _writeToFile(Constants.automateConfigFilePath, content: configContent);
  }

  String _promptInitConfigTemplate() {
    stdout.writeln('Select config template to generate:');
    stdout.writeln('1. Fastlane');
    stdout.writeln('2. Firebase App Distribution');
    stdout.writeln('3. Both');
    stdout.write('Enter choice [3]: ');

    final selection = stdin.readLineSync()?.trim().toLowerCase();

    late final String templateKind;
    late String templateContent;

    switch (selection) {
      case '1':
      case 'fastlane':
        templateKind = 'fastlane';
        templateContent = Templates.automateConfigFastlaneContent;
        break;
      case '2':
      case 'firebase':
      case 'firebase app distribution':
        templateKind = 'firebase';
        templateContent = Templates.automateConfigFirebaseContent;
        break;
      case '':
      case null:
      case '3':
      case 'both':
        templateKind = 'both';
        templateContent = Templates.automateConfigContent;
        break;
      default:
        stdout.writeln(
          'Invalid choice. Generating config with both providers.',
        );
        templateKind = 'both';
        templateContent = Templates.automateConfigContent;
        break;
    }

    final includeFlavorConfig = _promptIncludeFlavorConfig();
    if (includeFlavorConfig) {
      templateContent = Templates.withFlavorConfig(templateContent);
    }

    if (_promptIncludeProfilesConfig()) {
      templateContent = Templates.withProfilesConfig(
        templateContent,
        templateKind: templateKind,
        includeFlavorConfig: includeFlavorConfig,
      );
    }

    return templateContent;
  }

  bool _promptIncludeFlavorConfig() {
    stdout.writeln('Include flavor configuration?');
    stdout.writeln('1. No');
    stdout.writeln('2. Yes');
    stdout.write('Enter choice [1]: ');

    final selection = stdin.readLineSync()?.trim().toLowerCase();

    switch (selection) {
      case '2':
      case 'y':
      case 'yes':
      case 'flavor':
      case 'flavoured':
      case 'flavored':
        return true;
      case '':
      case null:
      case '1':
      case 'n':
      case 'no':
        return false;
      default:
        stdout.writeln(
          'Invalid choice. Generating standard config without flavors.',
        );
        return false;
    }
  }

  bool _promptIncludeProfilesConfig() {
    stdout.writeln('Generate deployment profiles like deploy dev?');
    stdout.writeln('1. Yes');
    stdout.writeln('2. No');
    stdout.write('Enter choice [1]: ');

    final selection = stdin.readLineSync()?.trim().toLowerCase();

    switch (selection) {
      case '':
      case null:
      case '1':
      case 'y':
      case 'yes':
      case 'profile':
      case 'profiles':
        return true;
      case '2':
      case 'n':
      case 'no':
        return false;
      default:
        stdout.writeln('Invalid choice. Generating config with profiles.');
        return true;
    }
  }

  bool _isDirectModeCommand(String command) {
    return ['beta', 'update'].contains(command);
  }

  void _configureDirectCommand(String command, ArgResults args) {
    selectedProfileName = '';
    _selectedProfile = null;
    mode = _parseMode(command);
    platform =
        _parsePlatform(args['platform'] as String?) ?? AutomatePlatform.all;
    provider =
        _parseProvider(args['provider'] as String?) ??
        AutomateProvider.fastlane;
    buildFlavor = _firstNonEmpty([
      args['flavor'] as String?,
      _automateConfig.buildFlavor,
    ]);
    buildTarget = _firstNonEmpty([
      args['target'] as String?,
      _automateConfig.buildTarget,
    ]);
  }

  void _configureProfileCommand(String profileName, ArgResults args) {
    final profile = _automateConfig.profile(profileName);
    if (profile == null) {
      final availableProfiles = _automateConfig.profileNames;
      final profileHint =
          availableProfiles.isEmpty
              ? 'No profiles are configured yet. Run deploy init to generate them.'
              : 'Available profiles: ${availableProfiles.join(', ')}.';
      throw Exception(
        'Unknown deployment profile "$profileName". $profileHint',
      );
    }

    selectedProfileName = profileName;
    _selectedProfile = profile;

    mode = _parseMode(_requiredProfileValue(profile, 'mode'));
    platform =
        _parsePlatform(args['platform'] as String?) ??
        _parsePlatform(_optionalString(profile['platform'])) ??
        AutomatePlatform.all;
    provider =
        _parseProvider(args['provider'] as String?) ??
        _parseProvider(_optionalString(profile['provider'])) ??
        AutomateProvider.fastlane;
    buildFlavor = _firstNonEmpty([
      args['flavor'] as String?,
      _profileBuildValue('flavor'),
      _automateConfig.buildFlavor,
    ]);
    buildTarget = _firstNonEmpty([
      args['target'] as String?,
      _profileBuildValue('target'),
      _automateConfig.buildTarget,
    ]);
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

  Future<bool> _isFirebaseInstalled() async {
    try {
      await _runCommand(
        'firebase',
        arguments: ['--version'],
        description: 'Firebase CLI version',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _initializeFirebase() async {
    print('Initializing Firebase CLI...');

    if (mode != AutomateMode.beta) {
      throw Exception(
        'Error: Firebase provider currently supports beta mode only. Use fastlane for update mode.',
      );
    }

    if (!await _isFirebaseInstalled()) {
      throw Exception(
        'Error: Firebase CLI is not installed. Install firebase-tools and authenticate before using --provider firebase.',
      );
    }

    switch (platform) {
      case AutomatePlatform.all:
        _firebaseDistributionConfig(AutomatePlatform.android);
        _firebaseDistributionConfig(AutomatePlatform.ios);
        break;
      case AutomatePlatform.android:
      case AutomatePlatform.ios:
        _firebaseDistributionConfig(platform);
        break;
    }

    print('Firebase CLI initialized successfully.');
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
      final appStoreConfig =
          _resolvedIosConfig['app_store_connect'] as Map<String, dynamic>?;

      if (appStoreConfig == null) {
        throw Exception(
          'Missing ios.app_store_connect in automate_config.json',
        );
      }

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

      final appIdentifier =
          _optionalString(_resolvedIosConfig['app_identifier']) ??
          await Utils.iosBundleId;

      // Get TestFlight configuration (optional)
      final testflightConfig =
          _resolvedIosConfig['testflight'] as Map<String, dynamic>?;
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
      if ([
        '%key_id%',
        '%issuer_id%',
        '%key_filepath%',
        '%display_name%',
        '%app_identifier%',
      ].any((placeholder) => !fastlaneTemplate.contains(placeholder))) {
        throw Exception(
          'Error: Missing one of the required placeholders in the iOS Fastlane template: %key_id%, %issuer_id%, %key_filepath%, %display_name%, %app_identifier%',
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
      final androidConfig = _resolvedAndroidConfig;

      final jsonKeyPath = androidConfig['json_key_path']?.toString();
      final packageName =
          _optionalString(androidConfig['package_name']) ??
          await Utils.androidPackageName;
      final aabPath = Utils.androidAabPath(flavor: buildFlavor);
      final mappingPath = Utils.androidMappingPath(flavor: buildFlavor);

      if (jsonKeyPath?.isEmpty ?? true) {
        throw Exception('Missing json_key_path in automate_config.json');
      }

      // Define Fastlane configuration for Android
      const fastlaneTemplate = Templates.androidFastFileContent;

      // Replace placeholders with config values
      final fastlaneContent = fastlaneTemplate
          .replaceAll('%json_key_path%', jsonKeyPath!)
          .replaceAll('%package_name%', packageName)
          .replaceAll('%aab_path%', aabPath)
          .replaceAll('%mapping_path%', mappingPath);

      // Write Fastfile for Android
      final fastfile = File(Constants.androidFastfilePath);
      await fastfile.writeAsString(fastlaneContent);

      print("Fastfile created at ${Constants.androidFastfilePath}");
    } on Exception {
      rethrow;
    }
  }

  Map<String, dynamic> _firebaseDistributionConfig(
    AutomatePlatform targetPlatform,
  ) {
    final config = switch (targetPlatform) {
      AutomatePlatform.android =>
        _resolvedAndroidConfig['firebase_app_distribution'],
      AutomatePlatform.ios => _resolvedIosConfig['firebase_app_distribution'],
      AutomatePlatform.all => null,
    };

    if (config == null) {
      throw Exception(
        'Missing ${targetPlatform.name}.firebase_app_distribution in automate_config.json',
      );
    }

    final appId = config['app_id']?.toString().trim() ?? '';
    final groups = config['groups']?.toString().trim() ?? '';
    final testers = config['testers']?.toString().trim() ?? '';

    if (appId.isEmpty) {
      throw Exception(
        'Missing ${targetPlatform.name}.firebase_app_distribution.app_id in automate_config.json',
      );
    }

    if (groups.isEmpty && testers.isEmpty) {
      throw Exception(
        'Provide either ${targetPlatform.name}.firebase_app_distribution.groups or testers in automate_config.json',
      );
    }

    return config;
  }

  Future<String> _firebaseArtifactPath(AutomatePlatform targetPlatform) async {
    switch (targetPlatform) {
      case AutomatePlatform.android:
        final apkFile = File(Utils.androidApkPath(flavor: buildFlavor));
        if (!apkFile.existsSync()) {
          throw Exception('Android APK not found at ${apkFile.path}');
        }
        return apkFile.path;
      case AutomatePlatform.ios:
        return Utils.iosIpaPath;
      case AutomatePlatform.all:
        throw Exception('A concrete platform is required for Firebase upload');
    }
  }

  String _firebaseReleaseNotes(AutomatePlatform targetPlatform) {
    final config = _firebaseDistributionConfig(targetPlatform);
    final releaseNotes = config['release_notes']?.toString().trim() ?? '';
    if (releaseNotes.isNotEmpty) {
      return releaseNotes;
    }

    final changelogSource = switch (targetPlatform) {
      AutomatePlatform.android => _resolvedAndroidConfig['changelog'],
      AutomatePlatform.ios => _resolvedIosConfig['changelog'],
      AutomatePlatform.all => null,
    };

    if (changelogSource is Map<String, dynamic>) {
      for (final value in changelogSource.values) {
        final message = value?.toString().trim() ?? '';
        if (message.isNotEmpty) {
          return message;
        }
      }
    }

    return '';
  }

  Future<void> _uploadToFirebaseAppDistribution(
    AutomatePlatform targetPlatform,
  ) async {
    final config = _firebaseDistributionConfig(targetPlatform);
    final artifactPath = await _firebaseArtifactPath(targetPlatform);
    final appId = config['app_id']!.toString().trim();
    final groups = config['groups']?.toString().trim() ?? '';
    final testers = config['testers']?.toString().trim() ?? '';
    final releaseNotes = _firebaseReleaseNotes(targetPlatform);

    final arguments = [
      'appdistribution:distribute',
      artifactPath,
      '--app',
      appId,
    ];

    if (groups.isNotEmpty) {
      arguments.addAll(['--groups', groups]);
    }

    if (testers.isNotEmpty) {
      arguments.addAll(['--testers', testers]);
    }

    if (releaseNotes.isNotEmpty) {
      arguments.addAll(['--release-notes', releaseNotes]);
    }

    await _runCommand(
      'firebase',
      arguments: arguments,
      description:
          'Uploading ${targetPlatform.name} build to Firebase App Distribution',
    );
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

    await _cleanupLegacyFlutterAndroidArtifacts();

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
    final arguments = ['build', 'apk', '--release', ..._flavorBuildArguments()];
    await _runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android APK',
    );
  }

  Future<void> _buildAndroidAppBundle() async {
    final arguments = [
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/app/outputs/symbols',
      ..._flavorBuildArguments(),
    ];
    await _runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android AppBundle',
    );
  }

  Future<void> _buildIOS() async {
    await _runCommand(
      'pod',
      arguments: ['install'],
      description: 'Installing CocoaPods',
      workingDir: 'ios',
    );
    final arguments = [
      'build',
      'ipa',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/ios/symbols',
      ..._flavorBuildArguments(),
    ];
    await _runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building iOS IPA',
    );

    // Modify Display Name in fastfile ios
    final iosIpaName = await Utils.iosIpaName;
    final fastfile = File(Constants.iosFastfilePath);
    String fastfileContent = await fastfile.readAsString();
    fastfileContent = fastfileContent.replaceAll('%display_name%', iosIpaName);
    await fastfile.writeAsString(fastfileContent);
  }

  Future<void> _cleanupLegacyFlutterAndroidArtifacts() async {
    final manifestFile = File(
      '${Constants.androidDirPath}/app/src/main/AndroidManifest.xml',
    );
    final registrantFile = File(
      '${Constants.androidDirPath}/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
    );

    if (!manifestFile.existsSync() || !registrantFile.existsSync()) {
      return;
    }

    final manifestContent = await manifestFile.readAsString();
    final usesFlutterEmbeddingV2 =
        manifestContent.contains('android:name="flutterEmbedding"') &&
        manifestContent.contains('android:value="2"');

    if (!usesFlutterEmbeddingV2) {
      return;
    }

    await registrantFile.delete();
    print(
      'Removed legacy android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java for Flutter embedding v2.',
    );
  }

  Future<void> _handleBetaBuild() async {
    if (provider == AutomateProvider.firebase) {
      switch (platform) {
        case AutomatePlatform.all:
          await _uploadToFirebaseAppDistribution(AutomatePlatform.android);
          await _uploadToFirebaseAppDistribution(AutomatePlatform.ios);
          break;
        case AutomatePlatform.ios:
          await _uploadToFirebaseAppDistribution(AutomatePlatform.ios);
          break;
        case AutomatePlatform.android:
          await _uploadToFirebaseAppDistribution(AutomatePlatform.android);
          break;
      }
      return;
    }

    switch (platform) {
      case AutomatePlatform.all:
        await _uploadToTestFlight();
        print(
          'Android beta builds are created locally only when using fastlane. Use --provider firebase to distribute Android betas.',
        );
        break;
      case AutomatePlatform.ios:
        await _uploadToTestFlight();
        break;
      case AutomatePlatform.android:
        throw Exception(
          'Android beta distribution is not supported with fastlane in this tool. Use --provider firebase instead.',
        );
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
          _resolvedIosConfig['changelog'] as Map<String, dynamic>?;
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
        final escapedMessage = message
            .replaceAll('"', r'\"')
            .replaceAll('\n', r'\n');
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
          _resolvedAndroidConfig['changelog'] as Map<String, dynamic>?;
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
        final escapedMessage = message
            .replaceAll('"', r'\"')
            .replaceAll('\n', r'\n');

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

  Map<String, dynamic> get _resolvedIosConfig {
    return _mergeConfig(_automateConfig.ios, _profileSection('ios'));
  }

  Map<String, dynamic> get _resolvedAndroidConfig {
    return _mergeConfig(_automateConfig.android, _profileSection('android'));
  }

  Map<String, dynamic> _mergeConfig(
    Map<String, dynamic> base,
    Map<String, dynamic>? override,
  ) {
    final merged = Map<String, dynamic>.from(base);
    if (override != null) {
      for (final entry in override.entries) {
        final baseValue = merged[entry.key];
        final overrideValue = entry.value;

        if (baseValue is Map && overrideValue is Map) {
          merged[entry.key] = _mergeConfig(
            Map<String, dynamic>.from(baseValue),
            Map<String, dynamic>.from(overrideValue),
          );
        } else {
          merged[entry.key] = overrideValue;
        }
      }
    }
    return merged;
  }

  Map<String, dynamic>? _profileSection(String key) {
    return _selectedProfile?[key] as Map<String, dynamic>?;
  }

  String? _profileBuildValue(String key) {
    final buildConfig = _profileSection('build');
    return _optionalString(buildConfig?[key]) ??
        _optionalString(_selectedProfile?[key]);
  }

  String _requiredProfileValue(Map<String, dynamic> profile, String key) {
    final value = _optionalString(profile[key]);
    if (value == null) {
      throw Exception(
        'Missing profiles.$selectedProfileName.$key in automate_config.json',
      );
    }
    return value;
  }

  AutomateMode _parseMode(String value) {
    final mode = value.trim().toLowerCase().toAutomateMode();
    if (mode == AutomateMode.none) {
      throw Exception(
        'Invalid deployment mode "$value". Must be one of: beta, update.',
      );
    }
    return mode;
  }

  AutomatePlatform? _parsePlatform(String? value) {
    final normalized = _optionalString(value);
    if (normalized == null) {
      return null;
    }
    return normalized.toLowerCase().toAutomatePlatform();
  }

  AutomateProvider? _parseProvider(String? value) {
    final normalized = _optionalString(value)?.toLowerCase();
    if (normalized == null) {
      return null;
    }

    switch (normalized) {
      case 'fastlane':
      case 'firebase':
        return normalized.toAutomateProvider();
      default:
        throw Exception(
          'Invalid deployment provider "$value". Must be one of: fastlane, firebase.',
        );
    }
  }

  String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = _optionalString(value);
      if (normalized != null) {
        return normalized;
      }
    }
    return '';
  }

  String? _optionalString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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

  List<String> _flavorBuildArguments() {
    final arguments = <String>[];

    if (buildFlavor.isNotEmpty) {
      arguments.addAll(['--flavor', buildFlavor]);
    }

    if (buildTarget.isNotEmpty) {
      arguments.addAll(['-t', buildTarget]);
    }

    return arguments;
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
