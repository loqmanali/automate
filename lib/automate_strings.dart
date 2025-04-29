class AutomateStrings {
  AutomateStrings._();

  static const String fastFileContent = '''
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
      ipa: "../build/ios/ipa/Banic.ipa",
      distribute_external: false,
      notify_external_testers: false,
      beta_app_description: "",
      expire_previous_builds: true,
      groups: "Testers",
    )
  end

  desc "Update App With New Build On App Store Connect"
  lane :new_update do

    deliver(
      ipa: "../build/ios/ipa/Banic.ipa",
      skip_screenshots: true,
      skip_metadata: false,
      metadata_path: "%metadata_path%",
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
              add_id_info_uses_idfa: false # No IDFA usage
            }
      )

  end
end

''';
}