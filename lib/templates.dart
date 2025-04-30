class Templates {
  Templates._();

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

  static const String iosAppRatingConfig = '''
  {
  "alcoholTobaccoOrDrugUseOrReferences": "NONE",
  "contests": "NONE",
  "gamblingSimulated": "NONE",
  "horrorOrFearThemes": "NONE",
  "matureOrSuggestiveThemes": "NONE",
  "medicalOrTreatmentInformation": "NONE",
  "profanityOrCrudeHumor": "NONE",
  "sexualContentGraphicAndNudity": "NONE",
  "sexualContentOrNudity": "NONE",
  "violenceCartoonOrFantasy": "NONE",
  "violenceRealisticProlongedGraphicOrSadistic": "NONE",
  "violenceRealistic": "NONE",
  "gambling": false,  
  "seventeenPlus": false,
  "unrestrictedWebAccess": false
}
  ''';

  static const String automateConfigContent = '''
  
ios:
  app_store_connect:
    key_id: "(Required)"
    issuer_id: "(Required)"
    key_filepath: "(Required)"

  # (Required) for automate update mode
  # Changelog is the Release Notes used only in automate update mode
  changelog :
    en-US: ""
    # ar-SA: ""

  info:
    # ----- Localized Information -----
    # (Required)
    name:
      en-US: ""
      # ar-SA: ""
    description:
      en-US: >
        This is Example of Multiline Description
        You can use copy your description
        and paste it here.
      # ar-SA: >
        # هذا مثال على وصف متعدد الأسطر
        # يمكنك استخدام نسخ ولصق وصفك
        # هنا.

    privacy_url:
      en-US: ""
      # ar-SA: ""
    keywords:
      en-US: ""
      # ar-SA: ""
    subtitle:
      en-US: ""
      # ar-SA: ""
    support_url:
      en-US: ""
      # ar-SA: ""

    # (Optional)
    # Uncomment the variables you need
    # promotional_text:
      # en-US: ""
      # ar-SA: ""
    # marketing_url:
      # en-US: ""
      # ar-SA: ""
    # apple_tv_privacy:
      # en-US: ""
      # ar-SA: ""


    # ----- UnLocalized Information -----

    # (Required)
    copyright: ""
    
    # Take a look at README.md in automate Directory
    # To see the category codes
    # (Required)
    primary_category: ""

    # (Optional)
    # Uncomment the variables you need
    # secondary_category: ""
    # primary_first_sub_category: ""
    # primary_second_sub_category: ""
    # secondary_first_sub_category: ""
    # secondary_second_sub_category: ""



    app_review_information:
      # (Required)
      first_name: ""
      last_name: ""
      email_address: ""
      phone_number: ""
      demo_user: ""
      demo_password: ""
      # (Optional)
      # notes: "Notes"
  ''';
}
