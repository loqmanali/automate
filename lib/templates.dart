class Templates {
  Templates._();

  static const String automateConfigContent = '''
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
        "demo_account_name": "(Required if external testing enabled)",
        "demo_account_password": "(Required if external testing enabled)",
        "notes": ""
      }
    }
  }
}
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
      ipa: "../build/ios/ipa/%display_name%.ipa",
      distribute_external: %enable_external_testing%,
      notify_external_testers: %enable_external_testing%,
      beta_app_description: "This Build for TESTING",
      beta_app_feedback_email: "%beta_app_feedback_email%",
      changelog: "This Build for TESTING",
      expire_previous_builds: true,
      localized_app_info: {
        "default": {
          feedback_email: "%beta_app_feedback_email%",
          description: "This Build for TESTING",
        },
      },%external_testing_config%
    )
  end

  desc "Update App With New Build On App Store Connect"
  lane :new_update do
    deliver(
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
    aab: "../build/app/outputs/bundle/release/app-release.aab",
    mapping: "../build/app/outputs/mapping/release/mapping.txt",
  )
  end
end

''';
}