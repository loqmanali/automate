import 'dart:convert';
import 'dart:io';

import 'package:automate/constants.dart';

class AutomateConfig {
  //Singleton
  static AutomateConfig? _instance;
  static AutomateConfig get instance => _instance ??= AutomateConfig._();
  AutomateConfig._();

  late Map<String, dynamic> _config;

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

  Map<String, dynamic> get android {
    final android = _config['android'] as Map<String, dynamic>?;
    if (android == null) {
      throw Exception('Missing android in automate_config.json');
    }
    return android;
  }

  Future<void> load() async {
    try {
      final configFile = File(Constants.automateConfigFilePath);
      if (!configFile.existsSync()) {
        throw Exception(
          'automate_config.json not found in the automate directory',
        );
      }
      final configContent = await configFile.readAsString();
      _config = jsonDecode(configContent) as Map<String, dynamic>;
    } on Exception {
      rethrow;
    }
  }
}
