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

The application combines fasting and post-meal glucose tracking,
laboratory HbA1c results, insulin administration records, and recurring
local reminders. A compact dashboard provides quick access to recent
records, measurement averages, and upcoming reminders.

The project is under active development. Current development and emulator
testing focus on Android.

## ✨ Features

### 🔐 Authentication

- Email and password registration.
- Sign-in and password reset.
- Persistent authentication state.
- Sign-out with cancellation of scheduled local notifications.
- User-specific Firestore records.

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

### 💉 Insulin Records

- Insulin name, category, dose, administration date, and time.
- Preset insulin names and manual name entry.
- Optional notes.
- Record editing and deletion.
- Today's administration records displayed on the dashboard.

### 📊 Dashboard

- Latest glucose measurement.
- Daily, weekly, and monthly measurement summaries.
- Separate fasting and post-meal averages.
- Combined glucose average.
- Glucose chart with a measurement-average reference line.
- Latest HbA1c result.
- Next planned reminder with its date and time.
- Quick navigation through dashboard cards.

### 🔔 Reminders and Notifications

- Fasting glucose, post-meal glucose, and insulin tracking reminders.
- Configurable time and repeat weekdays.
- Reminder creation, editing, deletion, and enable/disable controls.
- Reminder settings stored in Firestore.
- Local notification scheduling on Android.
- Exact scheduling when permission is available.
- Approximate scheduling when exact scheduling is unavailable.
- Notification permission controls and test notifications.
- Explicit 24-hour time display for upcoming reminders.
- Notification taps open the corresponding record-entry form.
- Account and reminder validation before opening a form.

Reminder notifications do not automatically create glucose or insulin records.

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
| Charts | Flutter CustomPainter |
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
    └── reminders/

test/
android/
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
└── reminders/
```

Firestore Security Rules restrict access to the matching authenticated
user and validate the permitted fields and values.

Reminder configurations are stored in Firestore, while notification
schedules are installed locally on each device.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK with a compatible Dart SDK.
- Android Studio and the required Android SDK components.
- An Android emulator or a physical Android device.
- A Firebase project with Authentication and Cloud Firestore enabled.

### 1. Clone the repository

```bash
git clone https://github.com/codelyth/track-diabetes-app.git
cd track-diabetes-app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Enable Email/Password authentication and create a Cloud Firestore database
in your Firebase project.

Install the Firebase CLI, sign in, and activate the FlutterFire CLI:

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

### 4. Publish Firestore rules

Copy the contents of `firestore.rules` into:

**Firebase Console → Firestore Database → Rules**

Publish the rules before using the application's data features.

### 5. Run the application

```bash
flutter devices
flutter run -d <device-id>
```

### 6. Configure notifications

Open the Reminders section and grant notification permission.

For more precise delivery, enable exact alarm access when available.
Check the next planned date and time before testing a reminder.

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

Notification delivery also requires device testing. Passing static
analysis or widget tests does not verify Android notification delivery.

## 📱 Notification Behavior

- Reminder times follow the device's configured local time zone.
- Scheduled local notifications can run while the application is in
  the background.
- Approximate scheduling may deliver notifications later than the selected time.
- Notification visibility, sound, and delivery can be affected by device
  permissions, battery restrictions, and Do Not Disturb settings.
- Force-stopping the application can prevent notification delivery.
- Remote reminder changes are synchronized when the application connects
  to Firestore; they are not instantly pushed to a closed application.
- Upcoming reminder cards show the planned recurrence, not confirmation
  that a notification was delivered.
- Opening a record form from a notification requires connectivity to
  validate the current reminder.

## 🧭 Roadmap

- [x] Firebase authentication and password reset.
- [x] Glucose tracking and record management.
- [x] HbA1c tracking.
- [x] Insulin administration records.
- [x] Compact dashboard and glucose chart.
- [x] Recurring reminders and local notifications.
- [x] Upcoming reminder display.
- [x] Navigation from notifications to record-entry forms.
- [ ] Reminder snoozing.
- [ ] Home-screen widgets.
- [ ] Profile and application settings.
- [ ] Additional notification privacy controls.
- [ ] Broader physical-device, reboot, and time-zone testing.
- [ ] Expanded automated tests, including Firestore access rules.
- [ ] Release signing and Google Play preparation.

## ℹ️ Scope

Track Diabetes is a personal tracking and reminder application.

It does not calculate insulin doses, recommend treatment, or provide
medical diagnoses. Measurement summaries are calculated from the records
entered by the user.

## 👩‍💻 Developer

Developed by [Yaprak Cihantimur · codelyth](https://github.com/codelyth).