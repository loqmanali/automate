class Templates {
  Templates._();

  static const String automateConfigContent = '''
android:
    json_key_path: "(Required)"
    
  # (Required for update)
  # Changelog is the Release Notes used only in automate update mode
    changelog :
        en-US: ""
        # ar: ""
ios:
  app_store_connect:
    key_id: "(Required)"
    issuer_id: "(Required)"
    key_filepath: "(Required)"

  # (Optional) TestFlight Configuration
  testflight:
    # Enable external testing for TestFlight builds
    enable_external_testing: false

  # (Required for update)
  # Changelog is the Release Notes used only in automate update mode
  changelog :
    en-US: ""
    # ar-SA: ""

  info:
    app_review_information:
      # (Required for release)
      first_name: ""
      last_name: ""
      email_address: ""
      phone_number: ""
      demo_user: ""
      demo_password: ""
      # (Optional)
      # notes: "Notes"
          
    # ----- Localized Information -----
    localized:
      # (Required For Release)
      name:
        en-US: ""
        # ar-SA: ""
      description:
        en-US: ""
        ar-SA: ""
  
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
    unlocalized:
      # (Required for release)
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
      beta_app_description: "TESTING",
      expire_previous_builds: true,
      groups: "Testers",
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
  
    
  desc "Release New App on App Store Connect"
  lane :release do
    deliver(
      ipa: "../build/ios/ipa/%display_name%.ipa",
      skip_screenshots: false,
      screenshots_path: "./fastlane/screenshots",
      precheck_include_in_app_purchases: false,
      submit_for_review: true,
      automatic_release: true,
      force: true,
      platform: "ios",
      app_rating_config_path: "../automate/app_rating_config.json",
      submission_information: {
              export_compliance_uses_encryption: false, # No non-standard encryption
              export_compliance_contains_proprietary_cryptography: false, # No proprietary cryptography
              export_compliance_contains_third_party_cryptography: false, # No third-party cryptography
              export_compliance_is_exempt: true, # Exempt due to standard encryption
              export_compliance_compliance_required: false, # No additional compliance needed
              export_compliance_available_on_french_store: false, # Not available in France
              export_compliance_encryption_updated: false, # No encryption changes
              export_compliance_platform: "ios",
              content_rights_has_rights: false, # No content rights
              content_rights_contains_third_party_content: false, # No third-party content
              add_id_info_uses_idfa: false # No IDFA usage
      } 
  )
  end

  desc "Upload App Privacy Details to App Store Connect"
  lane :upload_app_privacy do
          upload_app_privacy_details_to_app_store(
          app_identifier: "%app_identifier%",
          json_path: "../automate/app_privacy_details.json"
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
  "unrestrictedWebAccess": false,
  "lootBox": false
}
  ''';

  static const String iosAppPrivacyDetails = '''
[
  {
    "category": "NAME",
    "purposes": [
      "APP_FUNCTIONALITY"
    ],
    "data_protections": [
      "DATA_LINKED_TO_YOU"
    ]
  },
  {
    "category": "EMAIL_ADDRESS",
    "purposes": [
      "APP_FUNCTIONALITY"
    ],
    "data_protections": [
      "DATA_LINKED_TO_YOU"
    ]
  }
]
  ''';

  static const String automateReadmeContent = '''
Categories in automate_config.yaml
#  Available Categories
#  FOOD_AND_DRINK
#  BUSINESS
#  EDUCATION
#  SOCIAL_NETWORKING
#  BOOKS
#  SPORTS
#  FINANCE
#  REFERENCE
#  GRAPHICS_AND_DESIGN
#  DEVELOPER_TOOLS
#  HEALTH_AND_FITNESS
#  MUSIC
#  WEATHER
#  TRAVEL
#  ENTERTAINMENT
#  STICKERS
#  GAMES
#  LIFESTYLE
#  MEDICAL
#  MAGAZINES_AND_NEWSPAPERS
#  UTILITIES
#  SHOPPING
#  PRODUCTIVITY
#  NEWS
#  PHOTO_AND_VIDEO
#  NAVIGATION

iOS app rating config json
// The keys/values on the top allow one of 3 strings:
// "NONE", "INFREQUENT_OR_MILD" or "FREQUENT_OR_INTENSE",
// and the items on the bottom allow false or true.
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
  "unrestrictedWebAccess": false,
  "lootBox": false
}

  Example JSON configuration file
  Below are two examples of the app_privacy_details.json file that upload_app_privacy_details_to_app_store action will create.
  Not collecting data
  This is what will be output if your app does not collect any data.
  [
  {
  "data_protections": [
  "DATA_NOT_COLLECTED"
  ]
  }
  ]
  Collecting data
  This is what will be output that matches the example at the top of this page.
  [
  {
  "category": "PAYMENT_INFORMATION",
  "purposes": [
  "APP_FUNCTIONALITY"
  ],
  "data_protections": [
  "DATA_NOT_LINKED_TO_YOU"
  ]
  },
  {
  "category": "NAME",
  "purposes": [
  "PRODUCT_PERSONALIZATION",
  "APP_FUNCTIONALITY"
  ],
  "data_protections": [
  "DATA_LINKED_TO_YOU",
  "DATA_USED_TO_TRACK_YOU"
  ]
  }
  ]
  Data Values
  These are the values you will see in your JSON configuration file. You won't need to ever manually enter these values in your JSON configuration file (as this is what the interactive questionnaire will output for you).
  Categories
  * PAYMENT_INFORMATION
  * CREDIT_AND_FRAUD
  * OTHER_FINANCIAL_INFO
  * PRECISE_LOCATION
  * SENSITIVE_INFO
  * PHYSICAL_ADDRESS
  * EMAIL_ADDRESS
  * NAME
  * PHONE_NUMBER
  * OTHER_CONTACT_INFO
  * CONTACTS
  * EMAILS_OR_TEXT_MESSAGES
  * PHOTOS_OR_VIDEOS
  * AUDIO
  * GAMEPLAY_CONTENT
  * CUSTOMER_SUPPORT
  * OTHER_USER_CONTENT
  * BROWSING_HISTORY
  * SEARCH_HISTORY
  * USER_ID
  * DEVICE_ID
  * PURCHASE_HISTORY
  * PRODUCT_INTERACTION
  * ADVERTISING_DATA
  * OTHER_USAGE_DATA
  * CRASH_DATA
  * PERFORMANCE_DATA
  * OTHER_DIAGNOSTIC_DATA
  * OTHER_DATA
  * HEALTH
  * FITNESS
  * COARSE_LOCATION
  Purposes
  * THIRD_PARTY_ADVERTISING
  * DEVELOPERS_ADVERTISING
  * ANALYTICS
  * PRODUCT_PERSONALIZATION
  * APP_FUNCTIONALITY
  * OTHER_PURPOSES
  Data Protections
  * Uses DATA_LINKED_TO_YOU or DATA_NOT_LINKED_TO_YOU
  * Optionally uses DATA_USED_TO_TRACK_YOU

## Screenshots Naming Rules

Put all screenshots you want to use inside the folder of its language (e.g. `en-US`).
The device type will automatically be recognized using the image resolution.

The screenshots can be named whatever you want, but keep in mind they are sorted
alphabetically, in a human-friendly way. See https://github.com/fastlane/fastlane/pull/18200 for more details.

### Exceptions
  for 6.7":
  0_APP_IPHONE_67_0.png
  1_APP_IPHONE_67_1.png
  2_APP_IPHONE_67_2.png 
  3_APP_IPHONE_67_3.png
  4_APP_IPHONE_67_4.png
  5_APP_IPHONE_67_5.png
  6_APP_IPHONE_67_6.png
  
  for 6.5":
  0_APP_IPHONE_65_0.png
  1_APP_IPHONE_65_1.png
  2_APP_IPHONE_65_2.png 
  3_APP_IPHONE_65_3.png
  4_APP_IPHONE_65_4.png
  5_APP_IPHONE_65_5.png
  6_APP_IPHONE_65_6.png
  ''';
}
