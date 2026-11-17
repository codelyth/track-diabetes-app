# 🩸 Track Diabetes

> An Android diabetes tracking application built with Flutter and Firebase.
> Track glucose measurements, HbA1c results, insulin administration records,
> and personalized reminders through a compact, easy-to-use interface.

![Status](https://img.shields.io/badge/Status-In%20Development-orange)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Language-Dart-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Backend-Firebase-DD2C00?logo=firebase&logoColor=white)

## 📌 Project Overview

Track Diabetes helps users organize their daily diabetes-related records
in one place.

The application combines fasting and post-meal glucose measurements,
laboratory HbA1c results, insulin administration records, and recurring
local reminders.

A compact dashboard presents recent records and measurement summaries.
An Android home-screen widget provides quick access to the latest glucose
measurement, today's average, and the next planned reminder.

The project is under active development. Current development and emulator
testing focus on Android. Broader physical-device and release validation
are still pending.

## ✨ Features

### 🔐 Authentication and Account Management

- Email and password registration.
- Sign-in and password reset.
- Persistent authentication state.
- Profile display-name editing.
- Password changes with current-password verification.
- User-specific Firestore records.
- Sign-out with local notification cancellation and widget cleanup.
- Account deletion with password verification and explicit confirmation.
- Resumable deletion flow for interrupted operations.

The account-deletion flow is implemented. Successful deletion and
interruption-recovery testing with a disposable account remain pending.

### 🩸 Glucose Tracking

- Separate fasting and post-meal measurement types.
- Multiple measurements per day.
- Measurement date, time, and optional notes.
- Record editing and deletion.
- Date-range and measurement-type filters.
- Tabular records and measurement details.

### 🧪 HbA1c Tracking

- Laboratory result entry with test date and optional notes.
- Result history with editing and deletion.
- Latest HbA1c result displayed on the dashboard.

### 💉 Insulin Records and Daily Tracking

- Insulin name, category, administered dose, date, and time.
- Preset insulin names and manual name entry.
- Optional notes.
- Record editing and deletion.
- Today's administration records displayed on the dashboard.
- Daily tracking of enabled insulin reminders.
- Separate completed, skipped, and unmarked states.
- Future plans displayed as awaiting their scheduled time.
- Completed status recorded only after saving an administration record.
- Cancellation of the entry form leaves the plan unmarked.
- Duplicate submissions for the same reminder occurrence are rejected.
- Skipped status can be undone.
- Deleting a linked administration record also removes its completion status.

Administration records and completion states are saved together using a
Firestore transaction. These linked operations require connectivity.

Today's unmarked plans are derived from the current enabled reminders.
Changing or disabling a reminder can change those unmarked plans.
Previously saved responses remain available for that date.

The current tracking screen displays today only. It does not maintain a
complete historical log of unanswered reminder occurrences.

### 📊 Dashboard

- Latest glucose measurement.
- Daily, weekly, and monthly measurement summaries.
- Separate fasting and post-meal averages.
- Combined glucose average.
- Glucose chart with a measurement-average reference line.
- Latest HbA1c result.
- Next planned reminder with its date and time.
- Today's insulin administration records.
- Quick navigation through dashboard cards.

Averages are calculated from user-entered records.

### 🔔 Reminders and Notifications

- Fasting glucose, post-meal glucose, and insulin reminders.
- Configurable time and repeat weekdays.
- Reminder creation, editing, deletion, and enable/disable controls.
- Reminder configurations stored in Firestore.
- Local notification scheduling on Android.
- Exact scheduling when the required access is available.
- Approximate scheduling fallback when exact scheduling is unavailable.
- Notification permission controls and test notifications.
- Explicit 24-hour display for upcoming reminder times.
- Notification taps open the corresponding record-entry form.
- Account and current-reminder validation before opening a form.
- Ten-minute snoozing through a notification action.
- Snoozing preserves the reminder's regular recurrence.

Notification interactions do not automatically create glucose or insulin
administration records.

Completed/skipped insulin tracking currently works from the in-app tracking
screen. Connecting those actions to notification buttons is a planned step.

### 🏠 Android Home-Screen Widget

- Compact three-column layout.
- Latest glucose measurement, type, and measurement time.
- Today's combined glucose average and measurement count.
- Next planned reminder, including recognized snoozed reminders.
- Tap-to-open application behavior.
- Updates following observed record and reminder changes.
- Personal information cleared during sign-out.

The widget displays locally saved snapshots. It does not continuously
query Firestore independently while the application is closed.

Background refresh timing is controlled by Android. Relative-time labels
and displayed information may remain unchanged until the next refresh.

### ⚙️ Settings

- Current profile name and email display.
- Profile editing and password changes.
- Notification permission status.
- Exact alarm access status.
- Links to Android notification settings.
- Home-screen widget instructions.
- Sign-out and account-deletion entry points.

## 🛠️ Technology Stack

| Area | Technology |
| --- | --- |
| Application | Flutter |
| Language | Dart |
| UI | Material 3 |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | flutter_local_notifications |
| Time zones | timezone and flutter_timezone |
| Home-screen widget integration | home_widget |
| Native widget | Kotlin and Android XML layouts |
| Charts | Flutter CustomPainter |
| Linked record operations | Firestore transactions |
| Access control | Firestore Security Rules |
| Development | VS Code and Android Studio |
| Version control | Git and GitHub |

## 🗂️ Project Structure

```text
lib/
├── main.dart
├── app.dart
├── firebase_options.dart
├── core/
│   ├── notifications/
│   └── theme/
└── features/
    ├── auth/
    ├── glucose/
    ├── hba1c/
    ├── home/
    ├── insulin/
    ├── reminders/
    └── settings/

android/app/src/main/
├── kotlin/
│   └── com/example/track_diabetes/
│       ├── MainActivity.kt
│       └── DiabetesWidgetProvider.kt
└── res/
    ├── drawable/
    ├── layout/
    └── xml/

test/
firebase.json
firestore.rules
```

Feature modules separate presentation, data access, and domain models
where applicable.

## 🗄️ Data Organization

Application records are stored under the authenticated user's document:

```text
users/{userId}/
├── glucose_readings/
├── hba1c_results/
├── insulin_entries/
├── insulin_occurrences/
└── reminders/

account_deletions/{userId}
```

- `insulin_entries` stores recorded insulin administrations.
- `insulin_occurrences` stores completed or skipped reminder occurrences.
- Deterministic occurrence IDs distinguish each reminder's date and time.
- Linked completion and administration records are created atomically.
- Firestore rules restrict access to the matching authenticated user.
- Rules validate permitted fields, timestamps, and linked records.
- An account-deletion marker blocks new application-record writes.

Reminder configurations are stored in Firestore, while notification
schedules are installed locally on each device.

### Account Deletion

The current implementation works without deployed Cloud Functions.

After password verification and confirmation, the application:

1. Creates a persistent deletion marker.
2. Cancels notifications and clears widget data on the current device.
3. Deletes records from the five application collections in batches.
4. Verifies that those collections are empty.
5. Reauthenticates and deletes the Firebase Authentication account.

If interrupted, the operation can be resumed after reopening the
application and signing in. It does not continue while the application
is closed.

A minimal deletion marker containing a version and request timestamp is
retained under the former user ID to prevent further application-record
writes. It contains no name, email address, or health measurements.

Local notifications already scheduled on another device cannot be
cancelled remotely by this flow. That device performs cleanup when it
opens the application and detects the deletion marker.

New user-data collections must also be added to the deletion flow.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK with a Dart version compatible with `pubspec.yaml`.
- Android Studio and the required Android SDK components.
- An Android emulator or a physical Android device.
- Any NDK or CMake versions requested by the Android build.
- A Firebase project with Authentication and Cloud Firestore enabled.
- Firebase CLI and FlutterFire CLI.

### 1. Clone the Repository

```bash
git clone https://github.com/codelyth/track-diabetes-app.git
cd track-diabetes-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Enable Email/Password authentication and create a Cloud Firestore database
in your Firebase project.

Sign in and activate the FlutterFire CLI:

```bash
firebase login
dart pub global activate flutterfire_cli
```

Configure the Android application:

```bash
dart pub global run flutterfire_cli:flutterfire configure --platforms=android
```

Use your own Firebase project configuration. Generated Firebase
configuration files are excluded from this repository.

### 4. Publish Firestore Rules

Publish the repository's rules to your own project:

```bash
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

Alternatively, copy `firestore.rules` into:

**Firebase Console → Firestore Database → Rules**

Publish the rules before using application data features.

### 5. Run the Application

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID
```

### 6. Configure Notifications

Open the Reminders section and grant notification permission.

For more precise delivery, enable exact alarm access when available.
Check the next planned date and time before testing a reminder.

### 7. Add the Home-Screen Widget

Long-press an empty area of the Android home screen, open the widget
selector, and add **Şeker Takibi**.

Resize the widget to suit the launcher's grid. Open the application
and sign in to populate its data.

## ✅ Development Checks

Format the source code:

```bash
dart format lib
```

Run static analysis:

```bash
flutter analyze
```

Run automated tests:

```bash
flutter test
```

### Manual Validation

Manual emulator checks have covered:

- Basic authentication and data-entry flows.
- Notification delivery and snoozing.
- Compact widget layout and data updates.
- Profile editing and password changes.
- In-app completed/skipped insulin tracking.
- Rejection of account deletion with an incorrect password.

Still pending:

- Successful account deletion using a disposable account.
- Interrupted account-deletion recovery.
- Broader physical-device testing.
- Reboot, time-zone, and daylight-saving scenarios.
- Expanded automated Firestore rule and concurrency tests.

Passing static analysis or widget tests does not verify Android
notification delivery or all Firestore access-control behavior.

## 📱 Runtime Behavior and Limitations

- Reminder times follow the device's configured local time zone.
- Local notifications can run while the application is in the background.
- Approximate scheduling may deliver notifications later than requested.
- Permissions, battery restrictions, and Do Not Disturb settings can affect
  notification delivery and presentation.
- Force-stopping the application can prevent notification delivery.
- Remote reminder changes are synchronized when the application connects
  to Firestore; they are not instantly pushed to a closed application.
- Upcoming reminder cards show the planned recurrence, not proof of delivery.
- Opening a record form from a notification requires connectivity to
  validate the current reminder.
- Initial account-access verification requires a server connection.
- Linked insulin completion and skip actions require connectivity.
- Widget updates may be delayed while the application is closed.
- Account deletion is resumable but is not one atomic operation across
  Firebase Authentication and all Firestore collections.

## 🧭 Roadmap

- [x] Firebase authentication and password reset.
- [x] Glucose tracking and record management.
- [x] HbA1c tracking.
- [x] Insulin administration records.
- [x] Compact dashboard and glucose chart.
- [x] Recurring reminders and local notifications.
- [x] Upcoming reminder display.
- [x] Navigation from notifications to record-entry forms.
- [x] Ten-minute reminder snoozing.
- [x] Compact Android home-screen widget.
- [x] Profile editing and password changes.
- [x] Notification permission settings.
- [x] In-app completed/skipped insulin reminder tracking.
- [x] Resumable account-deletion implementation.
- [ ] Successful account-deletion and interruption-recovery validation.
- [ ] Notification actions linked to insulin completion/skip tracking.
- [ ] Historical tracking of unanswered insulin reminder occurrences.
- [ ] Additional notification and widget privacy controls.
- [ ] Broader physical-device, reboot, and time-zone testing.
- [ ] Expanded automated tests, including Firestore access rules.
- [ ] Release signing and Google Play preparation.

## ℹ️ Scope

Track Diabetes is a personal tracking and reminder application.

It does not calculate insulin doses, recommend treatment, or provide
medical diagnoses. Measurement summaries are calculated from records
entered by the user.

Completed and skipped states reflect user-entered information; they do
not independently verify whether an injection occurred.

## 👩‍💻 Developer
Yaprak Cihantimur · [codelyth](https://github.com/codelyth).
