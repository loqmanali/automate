enum AutomatePlatform { all, android, ios }

enum AutomateMode { none, beta, update }

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
