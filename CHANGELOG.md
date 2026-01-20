## 1.0.2

- Fixed `--skip-build` flag not replacing %display_name% placeholder in iOS Fastfile
- Fixed skipBuild flag initialization timing issue

## 1.0.1

- Improved README documentation
- Added localized changelogs example (ar-SA, fr-FR, de-DE)
- Added documentation links for Fastlane, Apple API Key, and Google Service Account setup

## 1.0.0

- Initial release
- **Beta Mode**: Upload builds to TestFlight with optional external testing support
- **Update Mode**: Submit app updates to App Store Connect and Google Play Store
- Automatic version and build number incrementing
- Fastlane configuration generation
- Support for localized changelogs
- Platform selection (`-p ios` or `-p android`)
- Skip build option (`--skip-build`) to use existing artifacts