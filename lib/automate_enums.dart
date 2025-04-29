enum AutomatePlatform { all, android, ios }

enum AutomateMode { none, beta, release, update }

extension AutomateModeExtension on String {
  AutomateMode toAutomateMode() {
    switch (this) {
      case 'beta':
        return AutomateMode.beta;
      case 'release':
        return AutomateMode.release;
      case 'update':
        return AutomateMode.update;
      default:
        return AutomateMode.none;
    }
  }
}
