# Service Reminder

A Flutter app for small service businesses (e.g. water purifier / appliance
servicing) to track customers, log service visits, and get reminded when a
customer's next service is due — with optional Google Drive backup.

Targets Android first (`minSdk 24`); iOS is not yet configured.

## Requirements

- Flutter 3.41.x (stable channel), Dart 3.11.x — check with `flutter --version`.
- Android SDK with a device or emulator running Android 7.0 (API 24) or newer.

## First-time setup

After cloning the repo there are two optional (but recommended) setup steps
before you run the app:

### 1. Google Sign-In / Drive backup (optional)

The core app (customer tracking, reminders) works without any Google credentials.
If you want the optional Drive backup feature to be active:

1. Create or reuse a [Firebase project](https://console.firebase.google.com).
2. Enable the **Google Drive API** in the linked Google Cloud project.
3. Register an Android app with package name `com.servicereminder.service_reminder`.
4. Add your **debug SHA-1** (`keytool -list -v -keystore ~/.android/debug.keystore`)
   and your **release SHA-1** (from your release keystore) to the Firebase app.
5. Download `google-services.json` and place it at `android/app/google-services.json`.

> **`android/app/google-services.json` is gitignored — never commit it.**
> See `.env.example` for a full checklist and the `google_sign_in` package docs
> for troubleshooting.

Without this file the app starts normally; Settings shows
*"Google Sign-In not set up"* and the backup section is hidden.

### 2. Release signing (optional for local development)

Debug builds work without any signing config. For Play Store / release builds
see the [Release signing](#release-signing) section below.

## Building

```bash
flutter pub get
flutter run                 # debug build on a connected device/emulator
```

If you change anything in `lib/data/local/tables.dart` or `database.dart`,
regenerate drift's generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If you change the source images in `assets/icon/` or the
`flutter_launcher_icons:` / `flutter_native_splash:` sections of
`pubspec.yaml`, regenerate the platform icon/splash assets:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Release signing

Release builds are signed using `android/key.properties`, which is
gitignored and **must be created locally** — it's never committed.

1. Generate a keystore if you don't already have one (keep the resulting
   `.jks` file and its passwords somewhere safe and *outside* this repo —
   losing it means you can never publish an update to the same Play Store
   listing again):

   ```bash
   keytool -genkey -v -keystore /path/to/service-reminder-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias service_reminder
   ```

2. Copy `android/key.properties.example` to `android/key.properties` and
   fill in the real values (`storeFile` should point at the `.jks` from
   step 1):

   ```bash
   cp android/key.properties.example android/key.properties
   ```

3. Build:

   ```bash
   flutter build apk --release        # a single installable APK
   flutter build appbundle --release  # .aab, for Play Store upload
   ```

   Output lands in `build/app/outputs/flutter-apk/app-release.apk` or
   `build/app/outputs/bundle/release/app-release.aab`.

   Without `key.properties` present, release builds still work but fall
   back to the debug signing key — fine for local testing, **not** for
   distribution (debug-signed builds can't receive Play Store updates and
   Google will reject the upload).

To cut a new release, bump the single `version:` line in `pubspec.yaml`
(`versionName+versionCode`, e.g. `1.0.1+2`) — `android/app/build.gradle.kts`
reads both from there.

### Verifying a release build (manual checklist)

Gradle release builds could not be exercised in the sandbox this project was
developed in — verify these yourself on a real device/emulator before
shipping:

- [ ] `flutter build apk --release`, install it (`adb install -r
      build/app/outputs/flutter-apk/app-release.apk`), and confirm it opens
      to the customer list.
- [ ] Add a customer with an installation date a few months in the past so
      they're immediately overdue.
- [ ] Grant the notification permission when prompted (Android 13+).
- [ ] Settings → **Check reminders now** — confirm the overdue notification
      appears.
- [ ] Force-stop the app (Android Settings → Apps → Service Reminder → Force
      stop) and reboot the device. Don't reopen the app. Within a day (or
      trigger it sooner — see below), the overdue notification should still
      appear on its own, proving the daily background check survived both
      the app process dying and the device restarting.
      - WorkManager (which the daily check and weekly backup both run on)
        persists its own schedule outside the app's process and re-arms
        itself after reboot via its own boot receiver — nothing in this
        app's code has to run first for that to happen.
      - To avoid waiting a full day: `adb shell dumpsys jobscheduler | grep
        -A5 service_reminder` shows whether the job is scheduled, or use
        Android Studio's *App Inspection → Background Task Inspector* to
        force-run it immediately.
- [ ] Tap the notification — it should open straight to that customer's
      detail screen.
- [ ] Log a service for that customer — the notification should clear and
      the next-due date should move forward.

## How the reminder logic works

- Every customer has `next_due_date`, computed as *(a reference date) +
  (a reminder interval)*.
- The reference date is the customer's `installation_date` until they have
  a logged service record, after which it's whichever service record has
  the latest `service_date` — even if records are logged out of
  chronological order.
- The interval defaults to 3 months, configurable app-wide in **Settings →
  Default reminder interval**, with an optional per-customer override
  (open a customer → tap **Reminder Interval**). Adding/editing/deleting a
  service record always recomputes `next_due_date` from scratch using
  whichever interval currently applies to that customer.
- A customer is **overdue** once `next_due_date` has passed, and **due
  soon** within the next 7 days ("due this week" on the dashboard).
- All dates (`installation_date`, `service_date`, `next_due_date`) are
  stored as UTC-midnight "calendar dates" rather than local timestamps —
  deliberately, so a customer's due date can't shift by a day depending on
  the device's timezone when the row happens to be read back. See
  `CustomerRepository._dateOnly`.
- **Logging a service is the only thing that "marks a reminder as done"** —
  it pushes `next_due_date` forward and clears that customer's
  notification. A daily background task (Workmanager, ~24h period) checks
  for overdue customers and posts/updates a notification per customer,
  grouped into a single summary notification when more than one customer
  is overdue. Notifications are `ongoing` (can't be swiped away) so they
  keep reminding you until a service is actually logged. A **Check
  reminders now** button in Settings runs the same check immediately, for
  testing.

## How backup/restore works

- Sign-in uses `google_sign_in`, scoped only to `drive.appdata` — the app
  can see and manage only files *it* created in the user's Drive, never
  their other files. This requires a Google Cloud/Firebase project with the
  Drive API enabled and an OAuth client registered for this app's package
  name + signing certificate (add `android/app/google-services.json` — see
  `google_sign_in`'s own setup docs). Without that file, the app runs fine
  and Settings just shows "Google Sign-In not set up"; Drive is backup
  only, never required for core functionality.
- **Backup now** exports every `Customer` and `ServiceRecord` row as a
  single timestamped JSON file (`service_reminder_backup_<timestamp>.json`)
  and uploads it to the Drive App Data folder. See
  `lib/services/backup/backup_snapshot.dart` for the exact format.
- **Restore from backup** lists files from the App Data folder by upload
  time, and — after an explicit "this cannot be undone" confirmation —
  **replaces** all local customers and service records with the selected
  backup's contents (not a merge). This is deliberately simple: restoring
  is meant for "get my data back on a new phone" or "undo a mistake", not
  reconciling two divergent datasets.
- An optional **Automatic weekly backup** toggle in Settings arms a second
  Workmanager task (independent of the daily reminder check) that backs up
  silently in the background; it's a no-op if Drive access isn't
  authorized at the time, rather than prompting (there's no UI to prompt
  from in a background task).

## Project layout

```
lib/
  data/           drift database + CustomerRepository (all business logic)
  models/         small value types (due-status classification, etc.)
  providers/      Riverpod wiring
  screens/        UI
  services/       notifications, backup/Drive, reminder scheduling
  widgets/        shared/reusable UI pieces
test/             unit + widget tests, mirroring the lib/ structure
tool/             one-off scripts (currently just app icon generation)
```

Run the test suite with `flutter test`.
