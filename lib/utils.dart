import 'dart:io';

import 'constants.dart';

class Utils {
  static String androidApkPath({String? flavor}) {
    final normalizedFlavor = _normalizedFlavor(flavor);
    if (normalizedFlavor == null) {
      return Constants.buildAndroidApkPath;
    }

    return '${Constants.projectDir}/build/app/outputs/flutter-apk/app-$normalizedFlavor-release.apk';
  }

  static String androidAabPath({String? flavor}) {
    final normalizedFlavor = _normalizedFlavor(flavor);
    if (normalizedFlavor == null) {
      return '${Constants.projectDir}/build/app/outputs/bundle/release/app-release.aab';
    }

    final buildVariant = '${normalizedFlavor}Release';
    return '${Constants.projectDir}/build/app/outputs/bundle/$buildVariant/app-$normalizedFlavor-release.aab';
  }

  static String androidMappingPath({String? flavor}) {
    final normalizedFlavor = _normalizedFlavor(flavor);
    if (normalizedFlavor == null) {
      return '${Constants.projectDir}/build/app/outputs/mapping/release/mapping.txt';
    }

    final buildVariant = '${normalizedFlavor}Release';
    return '${Constants.projectDir}/build/app/outputs/mapping/$buildVariant/mapping.txt';
  }

  static Future<String> get iosIpaName async {
    final Directory buildDir = Directory(Constants.buildIosIpaDirPath);
    if (!buildDir.existsSync()) {
      throw Exception(
        'Build directory not found at ${Constants.buildIosIpaDirPath}',
      );
    }

    // Find the first .ipa file in the directory
    final ipaFile = buildDir.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.ipa'),
    );

    if (ipaFile.isEmpty) {
      throw Exception('No .ipa file found in build directory');
    }

    final ipaFilePath = ipaFile.first.path;
    final ipaFileName = ipaFilePath.split('/').last;
    final ipaName = ipaFileName.split('.').first;
    return ipaName;
  }

  Utils._();

  static Future<String> get iosBundleId async {
    // First, try Info.plist
    final infoPlist = File('${Constants.iosDirPath}/Runner/Info.plist');
    if (infoPlist.existsSync()) {
      final content = await infoPlist.readAsString();
      final regex = RegExp(
        r'<key>CFBundleIdentifier</key>\s*<string>(.*?)</string>',
      );
      final match = regex.firstMatch(content);
      if (match != null && match.group(1) != null) {
        final bundleId = match.group(1)!.trim();
        if (bundleId.isNotEmpty && !bundleId.contains('\$')) {
          print(
            "Bundle ID found in ${Constants.iosDirPath}/Runner/Info.plist: $bundleId",
          );
          return bundleId;
        } else {
          print(
            "Bundle ID not found in ${Constants.iosDirPath}/Runner/Info.plist",
          );
          print("Falling back to project.pbxproj");
        }
      }
    } else {
      print(
        'Warning: Info.plist not found at ${Constants.iosDirPath}/Runner/Info.plist',
      );
    }

    // Fallback to project.pbxproj
    final projectFile = File(
      '${Constants.iosDirPath}/Runner.xcodeproj/project.pbxproj',
    );
    if (!projectFile.existsSync()) {
      throw Exception(
        'project.pbxproj not found at ${Constants.iosDirPath}/Runner.xcodeproj/project.pbxproj',
      );
    }

    final content = await projectFile.readAsString();
    final regex = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);');
    final matches = regex.allMatches(content);
    if (matches.isEmpty) {
      throw Exception('PRODUCT_BUNDLE_IDENTIFIER not found in project.pbxproj');
    }

    // Take the first non-empty, non-variable value (e.g., avoid $(inherited))
    for (final match in matches) {
      final bundleId = match.group(1)?.trim();
      if (bundleId != null && bundleId.isNotEmpty && !bundleId.contains('\$')) {
        print(
          "Bundle ID found in ${Constants.iosDirPath}/Runner.xcodeproj/project.pbxproj: $bundleId",
        );
        return bundleId;
      }
    }

    throw Exception(
      'Valid PRODUCT_BUNDLE_IDENTIFIER not found in project.pbxproj',
    );
  }

  static Future<String> get androidPackageName async {
    final gradleFile = File('${Constants.androidDirPath}/app/build.gradle');
    final ktsFile = File('${Constants.androidDirPath}/app/build.gradle.kts');

    File? targetFile;

    if (gradleFile.existsSync()) {
      targetFile = gradleFile;
    } else if (ktsFile.existsSync()) {
      targetFile = ktsFile;
    } else {
      throw Exception(
        'Neither build.gradle nor build.gradle.kts found in ${Constants.androidDirPath}/app',
      );
    }

    final content = await targetFile.readAsString();

    final regex = RegExp(
      r'''applicationId\s*(=)?\s*['"]([a-zA-Z0-9_.]+)['"]''',
    );
    final match = regex.firstMatch(content);

    if (match == null || match.group(2) == null) {
      throw Exception('applicationId not found in ${targetFile.path}');
    }

    return match.group(2)!;
  }

  static Future<String> get iosIpaPath async {
    final Directory buildDir = Directory(Constants.buildIosIpaDirPath);
    if (!buildDir.existsSync()) {
      throw Exception(
        'Build directory not found at ${Constants.buildIosIpaDirPath}',
      );
    }

    final ipaFiles = buildDir.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.ipa'),
    );

    if (ipaFiles.isEmpty) {
      throw Exception('No .ipa file found in build directory');
    }

    return ipaFiles.first.path;
  }

  static String? _normalizedFlavor(String? flavor) {
    final value = flavor?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
