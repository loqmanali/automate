# Automate

**Stop wasting hours on app deployment. One command, and your build is live on TestFlight, the stores, or Firebase App Distribution.**

Automate is a CLI tool for Flutter release workflows. It can generate and run Fastlane setup for store delivery, and it can also send beta builds to Firebase App Distribution without Fastlane.
The package name is still `automate`, but the CLI command is now `deploy`.

## Why Automate?

- **Dead Simple**: Run `deploy dev` for beta distribution or `deploy production` for store release.
- **No Fastlane Knowledge Required**: We generate the Fastlane files for store-backed flows.
- **One Config File**: All your deployment settings in one JSON file
- **Version Management**: Automatically increments your version and build numbers

## Features

- **Beta Mode**: Upload iOS builds to TestFlight or distribute iOS/Android builds through Firebase App Distribution
- **Update Mode**: Submit app updates to App Store Connect and Google Play Store
- Automatic version incrementing
- Fastlane configuration generation
- Firebase App Distribution support without Fastlane
- Support for localized changelogs

## Important Note

**You must create your app on App Store Connect and Google Play Console manually for the first time.** Automate handles all subsequent beta uploads and updates — but the initial app creation must be done through the store dashboards.

Store delivery still uses Fastlane. The no-Fastlane path in Automate is currently for Firebase App Distribution beta builds.

Once your app exists on the stores, Automate takes care of everything else! It will:
- Clean your project
- Fetch dependencies
- Increment version and build number automatically
- Build the right artifact (IPA for iOS, AAB for Android)
- Upload to the appropriate store
- Submit for review (in update mode)

## Requirements

- [Dart SDK](https://dart.dev/get-dart) ^3.7.2
- [Fastlane](https://docs.fastlane.tools) - required for TestFlight, App Store, and Google Play flows
- [Firebase CLI](https://firebase.google.com/docs/cli) - required for Firebase App Distribution flows
- For iOS: App Store Connect API Key - [How to create API Key](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)
- For Android: Google Play Service Account JSON key - [How to create Service Account](https://developers.google.com/android-publisher/getting_started#setting_up_api_access_clients)

## Installation

```bash
dart pub global activate automate
```

After activation, use the `deploy` command.

## Quick Start

### 1. Initialize

```bash
deploy init
```

`deploy init` asks which config template to generate: `Fastlane`, `Firebase App Distribution`, or `Both`.
It can also generate flavor-specific fields and human-friendly deployment profiles such as `dev`, `staging`, and `production`.

### 2. Configure

Edit `automate_config.json` with your credentials.

### 3. Deploy

```bash
deploy dev                             # Run the dev profile
deploy staging                         # Run the staging profile
deploy production                      # Run the production profile
```

**That's it!** No 50-step tutorials, no Stack Overflow rabbit holes.

## Usage

### Profile-Based Commands

These are the recommended commands. They read from `profiles` in `automate_config.json`.

```bash
# Generate config and sample profiles
deploy init

# Typical profile commands
deploy dev
deploy staging
deploy production

# Override part of a profile from the CLI
deploy dev --platform android
deploy staging --flavor staging --target lib/main_staging.dart
deploy production --skip-build
```

Example generated profile config:

```json
{
  "profiles": {
    "dev": {
      "mode": "beta",
      "provider": "firebase",
      "platform": "all"
    },
    "production": {
      "mode": "update",
      "provider": "fastlane",
      "platform": "all"
    }
  }
}
```

### Direct Commands

You can still run the explicit commands when needed.

```bash
# Build and upload for all platforms
deploy beta

# iOS only
deploy beta -p ios

# Skip build (use existing IPA)
deploy beta -p ios --skip-build

# Firebase App Distribution (Android)
deploy beta -p android --provider firebase

# Firebase App Distribution (iOS)
deploy beta -p ios --provider firebase

# Firebase App Distribution for both platforms
deploy beta --provider firebase

# TestFlight with a flavor passed on the command line
deploy beta -p ios --flavor staging --target lib/main_staging.dart

# Firebase App Distribution with an Android flavor
deploy beta -p android --provider firebase --flavor staging --target lib/main_staging.dart
```

### Update Mode (App Store / Google Play)

```bash
# Build and submit for all platforms
deploy update

# iOS only
deploy update -p ios

# Android only
deploy update -p android

# Store submission with a flavor
deploy update -p android --flavor production --target lib/main_production.dart
```

## Configuration

After running `deploy init`, edit `automate_config.json`:

### Minimal Configuration (Internal Testing Only)

If you just want to upload to TestFlight for internal testing, this is all you need:

```json
{
  "android": {
    "json_key_path": "path/to/service-account.json",
    "changelog": {
      "en-US": "Bug fixes and improvements"
    },
    "firebase_app_distribution": {
      "app_id": "1:1234567890:android:abc123def456",
      "groups": "qa-team",
      "testers": "",
      "release_notes": "Bug fixes and improvements"
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
    },
    "firebase_app_distribution": {
      "app_id": "1:1234567890:ios:abc123def456",
      "groups": "qa-team",
      "testers": "",
      "release_notes": "Bug fixes and improvements"
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

### Firebase App Distribution

To distribute builds without Fastlane, configure `firebase_app_distribution` for the platforms you want to ship:

```json
{
  "android": {
    "firebase_app_distribution": {
      "app_id": "1:1234567890:android:abc123def456",
      "groups": "qa-team",
      "testers": "",
      "release_notes": "Bug fixes and improvements"
    }
  },
  "ios": {
    "firebase_app_distribution": {
      "app_id": "1:1234567890:ios:abc123def456",
      "groups": "qa-team",
      "testers": "",
      "release_notes": "Bug fixes and improvements"
    }
  }
}
```

- `app_id`: Firebase app ID from your Firebase project settings
- `groups`: Comma-separated tester groups in App Distribution
- `testers`: Optional comma-separated tester emails
- `release_notes`: Optional. If omitted, Automate falls back to the first non-empty changelog entry for that platform

Before running a Firebase distribution command, authenticate the Firebase CLI with `firebase login` or provide CI credentials such as `FIREBASE_TOKEN`.

### Flavored Builds

If your Flutter app uses flavors, run `deploy init`, choose your provider template, then choose `Yes` when asked to include flavor configuration.

Example flavor-ready config:

```json
{
  "build": {
    "flavor": "staging",
    "target": "lib/main_staging.dart"
  },
  "android": {
    "package_name": "com.example.app.staging",
    "json_key_path": "path/to/service-account.json",
    "changelog": {
      "en-US": "Bug fixes and improvements"
    }
  },
  "ios": {
    "app_identifier": "com.example.app.staging",
    "app_store_connect": {
      "key_id": "YOUR_KEY_ID",
      "issuer_id": "YOUR_ISSUER_ID",
      "key_filepath": "path/to/AuthKey.p8"
    },
    "changelog": {
      "en-US": "Bug fixes and improvements"
    }
  }
}
```

- `build.flavor`: Passed to Flutter as `--flavor`
- `build.target`: Passed to Flutter as `--target`
- `android.package_name`: Recommended for flavored Google Play uploads so Fastlane targets the correct app
- `ios.app_identifier`: Recommended for flavored TestFlight and App Store uploads

You can also override the config at runtime:

```bash
deploy beta -p ios --flavor staging --target lib/main_staging.dart
deploy update -p android --flavor production --target lib/main_production.dart
```

### Localized Changelogs

You can add multiple languages for your changelog. Just add more locale keys:

```json
{
  "changelog": {
    "en-US": "Bug fixes and improvements",
    "ar-SA": "إصلاحات وتحسينات",
    "fr-FR": "Corrections de bugs et améliorations",
    "de-DE": "Fehlerbehebungen und Verbesserungen"
  }
}
```

The locale codes follow the format `language-REGION` (e.g., `en-US`, `ar-SA`, `fr-FR`). See [Apple's locale codes](https://developer.apple.com/documentation/xcode/choosing-localization-regions-and-scripts) and [Google Play's supported languages](https://support.google.com/googleplay/android-developer/answer/9844778#zippy=%2Chow-to-manage-translations%2Cview-list-of-available-languages).

### iOS Configuration

- **key_id**: Your App Store Connect API Key ID
- **issuer_id**: Your App Store Connect Issuer ID
- **key_filepath**: Path to your `.p8` private key file

> Learn how to create your API Key: [Apple Documentation](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)

### Android Configuration

- **json_key_path**: Path to your Google Play Service Account JSON key

> Learn how to create your Service Account: [Google Play Documentation](https://developers.google.com/android-publisher/getting_started#setting_up_api_access_clients)

## Command Options

| Option | Short | Description |
|--------|-------|-------------|
| command | - | `init`, `beta`, `update`, or a profile like `dev` / `production` |
| `--platform` | `-p` | Target platform: `ios` or `android` |
| `--provider` | `-r` | Deployment provider: `fastlane` or `firebase` |
| `--flavor` | `-f` | Flutter flavor / iOS scheme / Android product flavor |
| `--target` | `-t` | Flutter target file such as `lib/main_staging.dart` |
| `--skip-build` | `-s` | Skip the build process and use existing artifacts |

## License

BSD 3-Clause License - see [LICENSE](LICENSE) for details.
