# Tech Stack

## Language and runtime
- Dart SDK constraint: `^3.11.4`.
- Flutter SDK: README declares `^3.41.4`; Android and iOS are platform targets.
- Android Java/Kotlin: Java 17 source/target compatibility and Kotlin JVM target 17.
- Android minimum SDK: 24.

## Application dependencies
| Dependency | Version |
|---|---|
| cupertino_icons | ^1.0.8 |
| drift | ^2.34.3 |
| flutter_riverpod | ^2.6.1 |
| flutter_local_notifications | ^22.3.0 |
| workmanager | ^0.10.9 |
| google_sign_in | ^7.2.0 |
| googleapis | ^16.0.0 |
| intl | ^0.20.3 |
| uuid | ^4.6.0 |
| path_provider | ^2.1.6 |
| path | ^1.9.1 |
| shared_preferences | ^2.5.5 |
| http | ^1.6.0 |
| flutter_contacts | ^1.1.9 |

## Development dependencies
| Dependency | Version |
|---|---|
| flutter_lints | ^6.0.0 |
| drift_dev | ^2.34.0 |
| build_runner | ^2.15.1 |
| image | ^4.9.2 |
| flutter_launcher_icons | ^0.14.4 |
| flutter_native_splash | ^2.4.7 |

## Build and configuration
- Drift code generation uses `build_runner` and `build.yaml`.
- Drift stores DateTime values as ISO-8601 text.
- Android uses Gradle Kotlin DSL and a fallback debug signing config.
- Release signing loads `android/key.properties`; its example is not a secret.
- Analysis uses `package:flutter_lints/flutter.yaml`.

## Existing integrations
- Drift/SQLite local storage.
- SharedPreferences for reminder, notification, theme, and backup preferences.
- Workmanager for 24-hour reminder checks and 7-day backup tasks.
- Flutter Local Notifications.
- Google Sign-In and Google Drive `appDataFolder`.
- Flutter Contacts for Android contact import.

