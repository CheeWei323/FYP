# TravelGuard MY

TravelGuard MY is a final-year project supporting Malaysian travellers with personalised travel preparation requirements, readiness tracking, AI-assisted packing and destination route planning.

Supported destinations: Australia, Japan, South Korea, the United Kingdom and the United States.

## Features

- **Traveller:** Account registration and verification, saved trips, requirement checklists, readiness scores, packing lists, reminders and saved driving/walking route plans.
- **System Administrator:** User role management, destination availability and administrative activity.
- **Content Manager:** Travel rule creation, editing, publication status and official-source references.
- **Tourism Data Analyst:** Aggregate destination, purpose, completion and requirement analytics; saved reports and Excel exports.

## Technology

Flutter/Dart, Firebase Authentication, Cloud Firestore, Node.js/Express, Render, Gemini API and Google Maps Platform.

Requirement selection uses destination, purpose and duration to match approved rules. Readiness measures completed applicable requirements. Analysts receive aggregate results through the authenticated backend.

## Setup

Install dependencies from the project root:

```powershell
flutter pub get
npm --prefix backend ci
```

Configure Firebase Authentication and Firestore, including the required destination and travel-rule records.

Create a local `backend/.env` containing:

```dotenv
GEMINI_API_KEY=your_backend_key
GOOGLE_MAPS_SERVER_KEY=your_server_maps_key
FIREBASE_PROJECT_ID=your_firebase_project_id
GOOGLE_APPLICATION_CREDENTIALS=C:/path/outside/repository/analytics-reader.json
MAPS_API_KEY=your_android_maps_key
```

Keep real credentials and service-account files outside Git. The Android Maps key and backend Maps key require their respective restrictions.

## Run and build

Start the backend from its directory:

```powershell
cd backend
node server.mjs
```

From the project root:

```powershell
flutter run
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

The app uses the configured hosted backend. Another backend can be selected using `--dart-define=BACKEND_URL=https://your-backend.example`.

## Testing

```powershell
dart analyze lib test
flutter test
npm --prefix backend test
```

Tests cover requirement matching, trip safeguards, authentication, route handling and analytics. Formal objective measurements and testing evidence are documented separately in the project report.

## Scope

Readiness reflects self-reported preparation completion, not immigration clearance. Reminders use local Android notifications. Route planning preserves the traveller’s stop order. External services require network access and valid configuration.