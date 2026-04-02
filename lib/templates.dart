class Templates {
  Templates._();

  static const String automateConfigContent = '''
{
  "android": {
    "json_key_path": "(Required)",
    "changelog": {
      "en-US": ""
    },
    "firebase_app_distribution": {
      "app_id": "(Required for firebase provider)",
      "groups": "",
      "testers": "",
      "release_notes": ""
    }
  },
  "ios": {
    "app_store_connect": {
      "key_id": "(Required)",
      "issuer_id": "(Required)",
      "key_filepath": "(Required)"
    },
    "changelog": {
      "en-US": ""
    },
    "testflight": {
      "enable_external_testing": false,
      "groups": "(Group Name)",
      "beta_app_feedback_email": "(Required if external testing enabled)",
      "beta_app_review_info": {
        "contact_email": "(Required if external testing enabled)",
        "contact_first_name": "(Required if external testing enabled)",
        "contact_last_name": "(Required if external testing enabled)",
        "contact_phone": "(Required if external testing enabled)",
        "demo_account_required": false,
        "demo_account_name": "(Required if demo_account_required is true)",
        "demo_account_password": "(Required if demo_account_required is true)",
        "notes": ""
      }
    },
    "firebase_app_distribution": {
      "app_id": "(Required for firebase provider)",
      "groups": "",
      "testers": "",
      "release_notes": ""
    }
  }
}
''';

  static const String automateConfigFastlaneContent = '''
{
  "android": {
    "json_key_path": "(Required)",
    "changelog": {
      "en-US": ""
    }
  },
  "ios": {
    "app_store_connect": {
      "key_id": "(Required)",
      "issuer_id": "(Required)",
      "key_filepath": "(Required)"
    },
    "changelog": {
      "en-US": ""
    },
    "testflight": {
      "enable_external_testing": false,
      "groups": "(Group Name)",
      "beta_app_feedback_email": "(Required if external testing enabled)",
      "beta_app_review_info": {
        "contact_email": "(Required if external testing enabled)",
        "contact_first_name": "(Required if external testing enabled)",
        "contact_last_name": "(Required if external testing enabled)",
        "contact_phone": "(Required if external testing enabled)",
        "demo_account_required": false,
        "demo_account_name": "(Required if demo_account_required is true)",
        "demo_account_password": "(Required if demo_account_required is true)",
        "notes": ""
      }
    }
  }
}
''';

  static const String automateConfigFirebaseContent = '''
{
  "android": {
    "changelog": {
      "en-US": ""
    },
    "firebase_app_distribution": {
      "app_id": "(Required for firebase provider)",
      "groups": "",
      "testers": "",
      "release_notes": ""
    }
  },
  "ios": {
    "changelog": {
      "en-US": ""
    },
    "firebase_app_distribution": {
      "app_id": "(Required for firebase provider)",
      "groups": "",
      "testers": "",
      "release_notes": ""
    }
  }
}
''';

  static String withFlavorConfig(String template) {
    return template
        .replaceFirst(
          '{\n',
          '{\n  "build": {\n    "flavor": "(Required for flavored builds, e.g. staging)",\n    "target": "lib/main_staging.dart"\n  },\n',
        )
        .replaceFirst(
          '  "android": {\n',
          '  "android": {\n    "package_name": "(Recommended for flavored builds, e.g. com.example.app.staging)",\n',
        )
        .replaceFirst(
          '  "ios": {\n',
          '  "ios": {\n    "app_identifier": "(Recommended for flavored builds, e.g. com.example.app.staging)",\n',
        );
  }

  static String withProfilesConfig(
    String template, {
    required String templateKind,
    required bool includeFlavorConfig,
  }) {
    final profilesBlock = _profilesBlock(
      templateKind: templateKind,
      includeFlavorConfig: includeFlavorConfig,
    );
    return template.replaceFirst(
      '{'
          '\n',
      '{'
          '\n$profilesBlock',
    );
  }

  static String _profilesBlock({
    required String templateKind,
    required bool includeFlavorConfig,
  }) {
    switch (templateKind) {
      case 'fastlane':
        return includeFlavorConfig
            ? _fastlaneFlavoredProfilesContent
            : _fastlaneProfilesContent;
      case 'firebase':
        return includeFlavorConfig
            ? _firebaseFlavoredProfilesContent
            : _firebaseProfilesContent;
      case 'both':
      default:
        return includeFlavorConfig
            ? _combinedFlavoredProfilesContent
            : _combinedProfilesContent;
    }
  }

  static const String _combinedProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all"
    },
    "staging": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all"
    },
    "production": {
      "mode": "update",
      "provider": "fastlane",
      "platform": "all"
    }
  },
''';

  static const String _combinedFlavoredProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all",
      "build": {
        "flavor": "dev",
        "target": "lib/main_dev.dart"
      },
      "android": {
        "package_name": "com.example.app.dev"
      },
      "ios": {
        "app_identifier": "com.example.app.dev"
      }
    },
    "staging": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all",
      "build": {
        "flavor": "staging",
        "target": "lib/main_staging.dart"
      },
      "android": {
        "package_name": "com.example.app.staging"
      },
      "ios": {
        "app_identifier": "com.example.app.staging"
      }
    },
    "production": {
      "mode": "update",
      "provider": "fastlane",
      "platform": "all",
      "build": {
        "flavor": "production",
        "target": "lib/main_production.dart"
      },
      "android": {
        "package_name": "com.example.app"
      },
      "ios": {
        "app_identifier": "com.example.app"
      }
    }
  },
''';

  static const String _fastlaneProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "fastlane",
      "platform": "ios"
    },
    "staging": {
      "mode": "beta",
      "provider": "fastlane",
      "platform": "ios"
    },
    "production": {
      "mode": "update",
      "provider": "fastlane",
      "platform": "all"
    }
  },
''';

  static const String _fastlaneFlavoredProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "fastlane",
      "platform": "ios",
      "build": {
        "flavor": "dev",
        "target": "lib/main_dev.dart"
      },
      "android": {
        "package_name": "com.example.app.dev"
      },
      "ios": {
        "app_identifier": "com.example.app.dev"
      }
    },
    "staging": {
      "mode": "beta",
      "provider": "fastlane",
      "platform": "ios",
      "build": {
        "flavor": "staging",
        "target": "lib/main_staging.dart"
      },
      "android": {
        "package_name": "com.example.app.staging"
      },
      "ios": {
        "app_identifier": "com.example.app.staging"
      }
    },
    "production": {
      "mode": "update",
      "provider": "fastlane",
      "platform": "all",
      "build": {
        "flavor": "production",
        "target": "lib/main_production.dart"
      },
      "android": {
        "package_name": "com.example.app"
      },
      "ios": {
        "app_identifier": "com.example.app"
      }
    }
  },
''';

  static const String _firebaseProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all"
    },
    "staging": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all"
    }
  },
''';

  static const String _firebaseFlavoredProfilesContent = '''
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all",
      "build": {
        "flavor": "dev",
        "target": "lib/main_dev.dart"
      },
      "android": {
        "package_name": "com.example.app.dev"
      },
      "ios": {
        "app_identifier": "com.example.app.dev"
      }
    },
    "staging": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all",
      "build": {
        "flavor": "staging",
        "target": "lib/main_staging.dart"
      },
      "android": {
        "package_name": "com.example.app.staging"
      },
      "ios": {
        "app_identifier": "com.example.app.staging"
      }
    }
  },
''';

  static const String iosFastFileContent = '''
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools
#
# For a list of all available actions, check out
#
#     https://docs.fastlane.tools/actions
#
# For a list of all available plugins, check out
#
#     https://docs.fastlane.tools/plugins/available-plugins
#

# Uncomment the line if you want fastlane to automatically update itself
# update_fastlane

default_platform(:ios)

platform :ios do
  before_all do
    app_store_connect_api_key(
      key_id: "%key_id%",
      issuer_id: "%issuer_id%",
      key_filepath: "%key_filepath%",
    )
  end

  desc "Upload New Build to Test Flight"
  lane :beta do
    pilot(
      app_identifier: "%app_identifier%",
      ipa: "../build/ios/ipa/%display_name%.ipa",
      distribute_external: %enable_external_testing%,
      notify_external_testers: %enable_external_testing%,
      beta_app_description: "This Build for TESTING",
      changelog: "This Build for TESTING",
      expire_previous_builds: true,
      %external_testing_config%
    )
  end

  desc "Update App With New Build On App Store Connect"
  lane :new_update do
    deliver(
      app_identifier: "%app_identifier%",
      ipa: "../build/ios/ipa/%display_name%.ipa",
      skip_screenshots: true,
      precheck_include_in_app_purchases: false,
      submit_for_review: true,
      automatic_release: true,
      force: true,
      submission_information: {
              export_compliance_uses_encryption: false, # No non-standard encryption
              export_compliance_contains_proprietary_cryptography: false, # No proprietary cryptography
              export_compliance_contains_third_party_cryptography: false, # No third-party cryptography
              export_compliance_is_exempt: true, # Exempt due to standard encryption
              export_compliance_compliance_required: false, # No additional compliance needed
              export_compliance_available_on_french_store: false, # Not available in France
              export_compliance_encryption_updated: false, # No encryption changes
              export_compliance_platform: "ios",
              add_id_info_uses_idfa: false, # No IDFA usage
              content_rights_has_rights: false, # No content rights
              content_rights_contains_third_party_content: false # No third-party content
            }
      )
  end
end

''';

  static const String androidFastFileContent = '''
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools
#
# For a list of all available actions, check out
#
#     https://docs.fastlane.tools/actions
#
# For a list of all available plugins, check out
#
#     https://docs.fastlane.tools/plugins/available-plugins
#

# Uncomment the line if you want fastlane to automatically update itself
# update_fastlane

default_platform(:android)

platform :android do
  desc "Deploy a new version to the Google Play"
  lane :new_update do
  supply(
    package_name: "%package_name%",
    json_key: "%json_key_path%",
    aab: "%aab_path%",
    mapping: "%mapping_path%",
  )
  end
end

''';
}
