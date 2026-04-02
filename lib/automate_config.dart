import 'dart:convert';
import 'dart:io';

import 'package:automate/constants.dart';

class AutomateConfig {
  //Singleton
  static AutomateConfig? _instance;
  static AutomateConfig get instance => _instance ??= AutomateConfig._();
  AutomateConfig._();

  late Map<String, dynamic> _config;

  Map<String, dynamic>? get build => _config['build'] as Map<String, dynamic>?;

  String get buildFlavor => _optionalString(build?['flavor']) ?? '';

  String get buildTarget => _optionalString(build?['target']) ?? '';

  Map<String, dynamic> get profiles {
    return _config['profiles'] as Map<String, dynamic>? ?? {};
  }

  Map<String, dynamic>? profile(String name) {
    return profiles[name] as Map<String, dynamic>?;
  }

  List<String> get profileNames {
    final names = profiles.keys.toList();
    names.sort();
    return names;
  }

  Map<String, dynamic> get ios {
    final ios = _config['ios'] as Map<String, dynamic>?;
    if (ios == null) {
      throw Exception('Missing ios in automate_config.json');
    }
    return ios;
  }

  Map<String, dynamic> get appStoreConfig {
    final appStoreConfig = ios['app_store_connect'] as Map<String, dynamic>?;
    if (appStoreConfig == null) {
      throw Exception('Missing ios.app_store_connect in automate_config.json');
    }
    return appStoreConfig;
  }

  Map<String, dynamic>? get testflightConfig {
    return ios['testflight'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? get iosFirebaseConfig {
    return ios['firebase_app_distribution'] as Map<String, dynamic>?;
  }

  String? get iosAppIdentifier {
    return _optionalString(ios['app_identifier']);
  }

  Map<String, dynamic> get android {
    final android = _config['android'] as Map<String, dynamic>?;
    if (android == null) {
      throw Exception('Missing android in automate_config.json');
    }
    return android;
  }

  Map<String, dynamic>? get androidFirebaseConfig {
    return android['firebase_app_distribution'] as Map<String, dynamic>?;
  }

  String? get androidPackageName {
    return _optionalString(android['package_name']);
  }

  Future<void> load() async {
    try {
      final configFile = File(Constants.automateConfigFilePath);
      if (!configFile.existsSync()) {
        throw Exception('automate_config.json not found in the project root');
      }
      final configContent = await configFile.readAsString();
      _config = jsonDecode(configContent) as Map<String, dynamic>;
    } on Exception {
      rethrow;
    }
  }

  String? _optionalString(dynamic value) {
    final stringValue = value?.toString().trim();
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }
    return stringValue;
  }
}
