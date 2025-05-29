import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecUtils {
  static final String _projectDir = Directory.current.path;

  static Future<void> incrementVersion() async {
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

  static Future<String> get appVersion async =>
      (await _readPubspec())['version'].toString();

  static Future<YamlMap> _readPubspec() async {
    final file = File('$_projectDir/pubspec.yaml');
    if (!file.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }
    return loadYaml(await file.readAsString()) as YamlMap;
  }

  static Future<void> _writePubspec(String newVersion) async {
    final file = File('$_projectDir/pubspec.yaml');
    final content = await file.readAsString();
    final updatedContent = content.replaceFirst(
      RegExp(r'version: .+'),
      'version: $newVersion',
    );
    await file.writeAsString(updatedContent);
  }
}
