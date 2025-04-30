import 'dart:io';

import 'package:automate/constants.dart';
import 'package:yaml/yaml.dart';

class AutomateConfig {
  //Singleton
  static AutomateConfig? _instance;
  static AutomateConfig get instance => _instance ??= AutomateConfig._();
  AutomateConfig._();

  late YamlMap _config;

  YamlMap get ios {
    final ios = _config['ios'] as YamlMap?;
    if (ios == null) {
      throw Exception('Missing ios in automate_config.yaml');
    }
    return ios;
  }

  YamlMap get appStoreConfig {
    final appStoreConfig = ios['app_store_connect'] as YamlMap?;
    if (appStoreConfig == null) {
      throw Exception('Missing ios.app_store_connect in automate_config.yaml');
    }
    return appStoreConfig;
  }


  Future<void> load() async {
    try {
      final configFile = File(Constants.automateConfigFilePath);
      if (!configFile.existsSync()) {
        throw Exception('automate_config.yaml not found in the automate directory');
      }
      final configContent = await configFile.readAsString();
      _config = loadYaml(configContent) as YamlMap;
    } on Exception {
      rethrow;
    }
  }
}
