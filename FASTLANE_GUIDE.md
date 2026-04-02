# Fastlane Setup and Usage with `deploy`

This guide explains how to install Fastlane and how to use it with the `automate` package.
The package name is still `automate`, but the command you run is `deploy`.

## What `deploy` does with Fastlane

`deploy` does not replace Fastlane for store delivery. It uses Fastlane for these flows:

- iOS beta uploads to TestFlight
- iOS App Store updates
- Android Google Play updates

When you run a `deploy` command with the default Fastlane provider, it:

1. Checks that `fastlane` is installed on your machine
2. Reads values from `automate_config.json`
3. Generates Fastlane files inside your Flutter app
4. Builds your app unless you pass `--skip-build`
5. Runs the matching Fastlane lane

Generated files:

- `ios/fastlane/Fastfile`
- `android/fastlane/Fastfile`
- `ios/fastlane/Deliverfile` for iOS update release notes
- `android/fastlane/metadata/...` for Android localized changelogs

## Prerequisites

Before using Fastlane with `deploy`, make sure you have:

- Flutter installed and working
- Dart SDK `^3.7.2`
- A valid Flutter project with `ios/` and/or `android/`
- App Store Connect API key for iOS
- Google Play service account JSON key for Android
- CocoaPods installed for iOS builds

## Install Fastlane

### Recommended for macOS

```bash
brew install fastlane
```

### Alternative with RubyGems

```bash
sudo gem install fastlane -NV
```

If you use a Ruby version manager such as `rbenv` or `rvm`, install Fastlane without `sudo` inside that Ruby environment.

### Verify the installation

```bash
fastlane --version
```

If the command is not found, Fastlane is not available in your shell `PATH`, and `deploy` will fail before deployment starts.

## Install the `automate` package

```bash
dart pub global activate automate
```

Verify it:

```bash
deploy init
```

## Initialize `deploy`

Run this inside your Flutter project:

```bash
deploy init
```

The command creates `automate_config.json` and asks which template to generate:

- `Fastlane`
- `Firebase App Distribution`
- `Both`

If you want to use Fastlane, choose `Fastlane` or `Both`.

It also adds `/automate_config.json` to `.gitignore` if the file exists.

## Configure `automate_config.json`

For Fastlane-based flows, the main fields are:

```json
{
  "android": {
    "json_key_path": "path/to/service-account.json",
    "changelog": {
      "en-US": "Bug fixes and improvements"
    }
  },
  "ios": {
    "app_store_connect": {
      "key_id": "YOUR_KEY_ID",
      "issuer_id": "YOUR_ISSUER_ID",
      "key_filepath": "path/to/AuthKey.p8"
    },
    "changelog": {
      "en-US": "Bug fixes and improvements"
    },
    "testflight": {
      "enable_external_testing": false,
      "groups": "Beta Testers",
      "beta_app_feedback_email": "feedback@example.com",
      "beta_app_review_info": {
        "contact_email": "contact@example.com",
        "contact_first_name": "John",
        "contact_last_name": "Doe",
        "contact_phone": "+1234567890",
        "demo_account_required": false,
        "demo_account_name": "",
        "demo_account_password": "",
        "notes": ""
      }
    }
  }
}
```

## Required iOS fields

- `ios.app_store_connect.key_id`
- `ios.app_store_connect.issuer_id`
- `ios.app_store_connect.key_filepath`

## Required Android fields

- `android.json_key_path`

## TestFlight external testing

If `ios.testflight.enable_external_testing` is `false`, the extra TestFlight review fields are not required.

If it is `true`, `deploy` requires:

- `groups`
- `beta_app_feedback_email`
- `beta_app_review_info.contact_email`
- `beta_app_review_info.contact_first_name`
- `beta_app_review_info.contact_last_name`
- `beta_app_review_info.contact_phone`

If `demo_account_required` is `true`, these are also required:

- `demo_account_name`
- `demo_account_password`

## How Fastlane is used by `deploy`

`deploy` generates Fastlane configuration automatically. You do not need to run `fastlane init` yourself.

### iOS beta flow

Command:

```bash
deploy beta
```

What happens:

1. Validates Fastlane is installed
2. Generates `ios/fastlane/Fastfile`
3. Runs Flutter build steps unless `--skip-build` is used
4. Builds an IPA
5. Runs `fastlane beta` inside the `ios` directory
6. Uploads the build to TestFlight

### iOS update flow

Command:

```bash
deploy update -p ios
```

What happens:

1. Generates `ios/fastlane/Fastfile`
2. Ensures `ios/fastlane/Deliverfile` exists
3. Writes localized `release_notes(...)` into the Deliverfile from `ios.changelog`
4. Builds the IPA
5. Runs `fastlane new_update` inside `ios`
6. Submits the build to App Store Connect

### Android update flow

Command:

```bash
deploy update -p android
```

What happens:

1. Generates `android/fastlane/Fastfile`
2. Builds the Android App Bundle (`.aab`)
3. Creates Fastlane metadata changelog files under `android/fastlane/metadata/android/<locale>/changelogs/`
4. Runs `fastlane new_update` inside `android`
5. Uploads the bundle to Google Play

## Commands you will use

### Profile-based commands

If you generated profiles during `deploy init`, you can use more human-friendly commands:

```bash
deploy dev
deploy staging
deploy production
```

These profiles map to `beta` or `update` internally based on `profiles` in `automate_config.json`.

### TestFlight beta

```bash
deploy beta
deploy beta -p ios
deploy beta -p ios --skip-build
```

Notes:

- Fastlane beta distribution in this package is iOS only
- Android beta distribution should use Firebase App Distribution instead of Fastlane

### Store updates

```bash
deploy update
deploy update -p ios
deploy update -p android
```

## Provider behavior

The default provider is `fastlane`, so these are equivalent:

```bash
deploy beta
deploy beta --provider fastlane
```

```bash
deploy update
deploy update --provider fastlane
```

Use Firebase only for beta distribution:

```bash
deploy beta --provider firebase
```

`deploy update --provider firebase` is not supported.

## Important behavior to know

- `deploy` runs `flutter clean` and `flutter pub get` before builds
- It increments the app version automatically in most flows
- iOS builds run `pod install` before `flutter build ipa`
- `--skip-build` is mainly useful when an IPA already exists for iOS beta upload
- For update mode, changelogs are required for both iOS and Android

## Common setup example

### iOS TestFlight only

1. Install Fastlane
2. Activate `automate`
3. Run `deploy init`
4. Choose `Fastlane`
5. Fill in `ios.app_store_connect`
6. Optionally fill in `ios.testflight`
7. Run `deploy beta -p ios`

### iOS App Store + Android Play Store

1. Install Fastlane
2. Run `deploy init`
3. Add iOS App Store Connect credentials
4. Add Android `json_key_path`
5. Add changelog entries for both platforms
6. Run `deploy update`

## Troubleshooting

### `Error: Fastlane is not installed`

Install Fastlane and verify with:

```bash
fastlane --version
```

### `Missing key_id, issuer_id, or key_filepath`

Your `ios.app_store_connect` block in `automate_config.json` is incomplete.

### `Missing json_key_path in automate_config.json`

Your Android service account key path is missing.

### `Android beta distribution is not supported with fastlane`

Use Firebase App Distribution instead:

```bash
deploy beta -p android --provider firebase
```

### `Changelog required for update mode`

Add non-empty `changelog` entries for the platform you are updating.

## Summary

Use Fastlane with `deploy` when you want:

- TestFlight uploads for iOS beta
- App Store submissions for iOS updates
- Google Play submissions for Android updates

Main workflow:

1. Install Fastlane
2. Run `deploy init`
3. Fill in `automate_config.json`
4. Run `deploy beta` or `deploy update`

That is enough for `deploy` to generate the Fastlane files and execute the correct lanes for your Flutter project.
