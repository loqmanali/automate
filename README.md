# Automate

**Stop wasting hours on app deployment. One command, and boom — your app is live on TestFlight or the App Store!**

Automate is a CLI tool that handles all the complex Fastlane configurations for you. No need to memorize store requirements, write Ruby scripts, or debug cryptic errors. Just configure once, run one command, and your Flutter app is deployed.

## Why Automate?

- **Dead Simple**: Run `automate beta` and your build is on TestFlight. That's it.
- **No Fastlane Knowledge Required**: We generate all the Fastlane files for you
- **One Config File**: All your deployment settings in one JSON file
- **Version Management**: Automatically increments your version and build numbers

## Features

- **Beta Mode**: Upload builds to TestFlight (iOS) with optional external testing support
- **Update Mode**: Submit app updates to App Store Connect and Google Play Store
- Automatic version incrementing
- Fastlane configuration generation
- Support for localized changelogs

## Important Note

**You must create your app on App Store Connect and Google Play Console manually for the first time.** Automate handles all subsequent beta uploads and updates — but the initial app creation must be done through the store dashboards.

Once your app exists on the stores, Automate takes care of everything else! It will:
- Clean your project
- Fetch dependencies
- Increment version and build number automatically
- Build the right artifact (IPA for iOS, AAB for Android)
- Upload to the appropriate store
- Submit for review (in update mode)

## Requirements

- [Dart SDK](https://dart.dev/get-dart) ^3.7.2
- [Fastlane](https://fastlane.tools/) installed
- For iOS: App Store Connect API Key
- For Android: Google Play Service Account JSON key

## Installation

```bash
dart pub global activate automate
```

## Quick Start

### 1. Initialize

```bash
automate init
```

### 2. Configure

Edit `automate_config.json` with your credentials.

### 3. Deploy

```bash
automate beta     # Upload to TestFlight
automate update   # Submit to App Store / Google Play
```

**That's it!** No 50-step tutorials, no Stack Overflow rabbit holes.

## Usage

### Beta Mode (TestFlight)

```bash
# Build and upload for all platforms
automate beta

# iOS only
automate beta -p ios

# Skip build (use existing IPA)
automate beta -p ios --skip-build
```

### Update Mode (App Store / Google Play)

```bash
# Build and submit for all platforms
automate update

# iOS only
automate update -p ios

# Android only
automate update -p android
```

## Configuration

After running `automate init`, edit `automate_config.json`:

### Minimal Configuration (Internal Testing Only)

If you just want to upload to TestFlight for internal testing, this is all you need:

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
      "enable_external_testing": false
    }
  }
}
```

> **Note**: When `enable_external_testing` is `false`, you don't need to provide any other TestFlight fields like `groups`, `beta_app_feedback_email`, or `beta_app_review_info`. Keep it simple!

### Full Configuration (With External Testing)

If you want to distribute to external testers, set `enable_external_testing` to `true` and provide the required fields:

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
      "enable_external_testing": true,
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

> **Note**: If `demo_account_required` is `false`, you don't need to provide `demo_account_name` and `demo_account_password`.

### iOS Configuration

- **key_id**: Your App Store Connect API Key ID
- **issuer_id**: Your App Store Connect Issuer ID
- **key_filepath**: Path to your `.p8` private key file

### Android Configuration

- **json_key_path**: Path to your Google Play Service Account JSON key

## Command Options

| Option | Short | Description |
|--------|-------|-------------|
| `--platform` | `-p` | Target platform: `ios` or `android` |
| `--skip-build` | `-s` | Skip the build process and use existing artifacts |

## License

BSD 3-Clause License - see [LICENSE](LICENSE) for details.