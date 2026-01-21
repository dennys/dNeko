# dNeko

A Flutter application with platform channels for native Android (Kotlin) and iOS (Swift) integration.

## Features

- Flutter 3.38+ support
- Platform channels for native communication
- Kotlin 2.3 for Android
- targetSdkVersion 33

## Getting Started

### Prerequisites

- Flutter SDK 3.38 or higher
- Android Studio with Kotlin support
- Xcode (for iOS development)

### Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Run on Android:
```bash
flutter run
```

3. Run on iOS:
```bash
flutter run -d ios
```

## Platform Channel Usage

The app demonstrates a basic platform channel setup:

**Channel Name:** `com.dneko/native`

**Available Methods:**
- `getNativeMessage`: Returns a greeting message from the native platform

### Adding New Platform Methods

1. In [lib/main.dart](lib/main.dart), add your method call
2. In [android/app/src/main/kotlin/com/dneko/app/MainActivity.kt](android/app/src/main/kotlin/com/dneko/app/MainActivity.kt), implement the Kotlin handler
3. In [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift), implement the Swift handler

## Project Structure

```
dneko/
├── lib/
│   └── main.dart                 # Flutter app entry point
├── android/
│   └── app/
│       ├── build.gradle          # Android build configuration
│       └── src/main/kotlin/      # Kotlin source files
└── ios/
    └── Runner/
        └── AppDelegate.swift     # iOS app delegate
```

## Permissions

### Android

This app requires the following permission:

- **SYSTEM_ALERT_WINDOW**: This permission allows the app to display overlays on top of other apps. It's required for features like floating windows, chat heads, or screen overlays.

**Note:** On Android 6.0 (API level 23) and above, this is a special permission that requires the user to manually grant it through Settings. The app should request this permission at runtime and guide users to the system settings if needed.

To check and request this permission programmatically:
```kotlin
if (!Settings.canDrawOverlays(this)) {
    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
        Uri.parse("package:$packageName"))
    startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
}
```

## Configuration

- **Android targetSdkVersion:** 33
- **Kotlin version:** 2.3.0
- **Minimum SDK:** 21
