import 'dart:io';

class PubspecUtils {
  static final String _projectDir = Directory.current.path;

  static Future<void> incrementVersion() async {
    final version = await appVersion;
    final parts = version.split('+');
    final versionParts = parts[0].split('.');
    final patch = int.parse(versionParts[2]) + 1;
    final newVersion = '${versionParts[0]}.${versionParts[1]}.$patch';
    final buildNumber = int.parse(parts[1]) + 1;

    await _writePubspec('$newVersion+$buildNumber');
    print('Incremented version to $newVersion, build number to $buildNumber');
  }

  static Future<String> get appVersion async {
    final file = File('$_projectDir/pubspec.yaml');
    if (!file.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }
    final content = await file.readAsString();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
    if (versionMatch == null) {
      throw Exception('version not found in pubspec.yaml');
    }
    return versionMatch.group(1)!.trim();
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
