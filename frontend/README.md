# SkillTrack Pro — Frontend (Flutter)

This folder contains the SkillTrack Pro mobile app.

## Tech

- Flutter (Material 3)
- `go_router` for routing
- `http` for API calls
- `flutter_secure_storage` for token storage

## Prerequisites

- Flutter (stable)
- Android Studio / Android SDK (for Android) or Xcode (for iOS)

## Setup

```bash
cd frontend
flutter pub get
```

## Configure API base URL

The app reads the API base URL from a compile-time define:

- `API_BASE_URL`

Default is `http://10.0.2.2:3000` (Android emulator -> host machine).

Examples:

Android emulator (default):

```bash
flutter run
```

iOS simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Physical device (replace with your PC LAN IP):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

## Run

```bash
cd frontend
flutter run
```

## Windows note (symlinks)

Some Flutter plugins require symlink support on Windows.

If you see: “Building with plugins requires symlink support”, enable Developer Mode:

```bash
start ms-settings:developers
```

Then turn on **Developer Mode**, and retry `flutter run`.

## App structure

- `lib/app/` — router + auth controller
- `lib/screens/` — UI screens (learner/mentor/admin)
- `lib/services/` — API client + services (UI-only, no business rules)
- `lib/ui/` — shared UI helpers

## Troubleshooting

- If you can login but lists are empty, run backend seed: `cd backend && npm run seed`.
- If API calls fail on a physical device, set `API_BASE_URL` to your machine LAN IP and ensure firewall allows the port.
