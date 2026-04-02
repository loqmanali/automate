enum AutomatePlatform { all, android, ios }

enum AutomateMode { none, beta, update }

enum AutomateProvider { fastlane, firebase }

extension AutomateModeExtension on String {
  AutomateMode toAutomateMode() {
    switch (this) {
      case 'beta':
        return AutomateMode.beta;
      case 'update':
        return AutomateMode.update;
      default:
        return AutomateMode.none;
    }
  }
}

extension AutomatePlatformExtension on String {
  AutomatePlatform toAutomatePlatform() {
    switch (this) {
      case 'android':
        return AutomatePlatform.android;
      case 'ios':
        return AutomatePlatform.ios;
      case 'all':
        return AutomatePlatform.all;
      default:
        throw Exception(
          'Invalid platform "$this". Must be one of: all, ios, android.',
        );
    }
  }
}

extension AutomateProviderExtension on String {
  AutomateProvider toAutomateProvider() {
    switch (this) {
      case 'firebase':
        return AutomateProvider.firebase;
      case 'fastlane':
      default:
        return AutomateProvider.fastlane;
    }
  }
}
