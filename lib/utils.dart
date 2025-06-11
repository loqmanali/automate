import 'dart:io';

import 'constants.dart';

class Utils {
  static Future<String> get iosDisplayName async {
    final infoPlist = File('${Constants.iosDirPath}/Runner/Info.plist');
    if (!infoPlist.existsSync()) {
      throw Exception(
        'Info.plist not found at ${Constants.iosDirPath}/Runner/Info.plist',
      );
    }
    final content = await infoPlist.readAsString();
    final regex = RegExp(
      r'<key>CFBundleDisplayName</key>\s*<string>(.*?)</string>',
    );
    final match = regex.firstMatch(content);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    } else {
      throw Exception('CFBundleDisplayName not found in Info.plist');
    }
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
}
