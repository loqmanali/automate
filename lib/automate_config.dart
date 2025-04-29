import 'dart:io';

import 'package:yaml/yaml.dart';

class AutomateConfig {
  //Singleton
  static AutomateConfig? _instance;
  static AutomateConfig get instance => _instance ??= AutomateConfig._();
  AutomateConfig._();

  static final String _projectDir = Directory.current.path;

  late YamlMap _config;

  YamlMap get appStoreConfig {
    final appStoreConfig = _config['ios']?['app_store_connect'] as YamlMap?;
    if (appStoreConfig == null) {
      throw Exception('Missing ios.app_store_connect in automate_config.yaml');
    }
    return appStoreConfig;
  }

  YamlMap get info {
    final info = _config['info'] as YamlMap?;
    if (info == null) {
      throw Exception('Missing info in automate_config.yaml');
    }
    return info;
  }

  Future<void> load() async {
    try {
      final configFile = File('$_projectDir/automate_config.yaml');
      if (!configFile.existsSync()) {
        throw Exception('automate_config.yaml not found in project root');
      }
      final configContent = await configFile.readAsString();
      _config = loadYaml(configContent) as YamlMap;
    } on Exception {
      rethrow;
    }
  }
}
