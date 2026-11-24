# Project Structure

## Project type
- Mobile application: cross-platform Flutter client, with Android-specific configuration and native plugin integration.
- Primary deployable: Android app; iOS and web/desktop folders exist but the README and platform code focus Android.

## Top-level layout
- `service_reminder/lib/`: application source.
  - `data/local/`: Drift tables, database, generated database code.
  - `data/repositories/`: customer and service-history persistence operations.
  - `models/`: derived UI/domain values.
  - `providers/`: Riverpod dependency and state providers.
  - `screens/`: externally reachable Flutter pages.
  - `services/`: notifications, reminders, backup, preferences, and Workmanager dispatch.
  - `widgets/`: reusable forms and UI controls.
- `service_reminder/test/`: widget, service, repository, and backup-snapshot tests.
- `service_reminder/android/`, `ios/`: platform shells and build configuration.
- `service_reminder/assets/`: icon and splash source images.
- `service_reminder/tool/`: icon generation tooling.
- `.github/modernize/`: modernization workflow hooks and scripts.

## Layer structure
- Presentation: `screens/` and `widgets/`.
- State and composition: `providers/`.
- Application/service logic: `services/`.
- Repository/data access: `data/repositories/`.
- Persistence and generated mapping: `data/local/`.
- Models: `models/`.

## Entry points
- Flutter: `service_reminder/lib/main.dart:20`.
- Android launcher: `service_reminder/android/app/src/main/AndroidManifest.xml`.
- Android native activity: `service_reminder/android/app/src/main/kotlin/com/servicereminder/service_reminder/MainActivity.kt`.
- Workmanager callback: `service_reminder/lib/services/workmanager_callback_dispatcher.dart:12`.
- Daily reminder task: `service_reminder/lib/services/reminders/reminder_background_task.dart:22`.
- Weekly backup task: `service_reminder/lib/services/backup/backup_background_task.dart:20`.

## Functional areas
- Customer management: list, add, edit, delete.
- Service history: log, edit, delete, due-date recomputation.
- Reminder status and notifications: due-state badges and persistent overdue alerts.
- Settings: reminder interval, sound/vibration, theme.
- Google Drive backup and restore.
- Contacts import.

