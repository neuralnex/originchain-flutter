# OriginChain

**Know where it came from. Know what changed. Verify what you receive.**

OriginChain is a cross-platform digital provenance app. It fingerprints files on the user's device, records signed provenance commitments on Solana, and lets recipients inspect a file's registered history. Original files stay local unless the user explicitly uploads a shareable copy.

<p align="left">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img alt="Firebase Authentication" src="https://img.shields.io/badge/Firebase_Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Google Sign-In" src="https://img.shields.io/badge/Google_Sign--In-4285F4?style=for-the-badge&logo=google&logoColor=white">
  <img alt="Cloud Firestore" src="https://img.shields.io/badge/Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Firebase Storage" src="https://img.shields.io/badge/Firebase_Storage-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Firebase Cloud Messaging" src="https://img.shields.io/badge/Cloud_Messaging-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Firebase App Check" src="https://img.shields.io/badge/App_Check-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Firebase Crashlytics" src="https://img.shields.io/badge/Crashlytics-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Solana" src="https://img.shields.io/badge/Solana-9945FF?style=for-the-badge&logo=solana&logoColor=white">
  <img alt="Anchor" src="https://img.shields.io/badge/Anchor-333333?style=for-the-badge&logo=anchor&logoColor=white">
  <img alt="Solana Mobile Wallet Adapter" src="https://img.shields.io/badge/Solana_Mobile_MWA-9945FF?style=for-the-badge&logo=solana&logoColor=white">
  <img alt="SHA-256 and Ed25519" src="https://img.shields.io/badge/SHA--256%20%7C%20Ed25519-Cryptography-6E7781?style=for-the-badge">
  <img alt="Python" src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white">
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white">
  <img alt="Neon Object Storage" src="https://img.shields.io/badge/Neon_Object_Storage-00E599?style=for-the-badge&logo=neon&logoColor=black">
  <img alt="Amazon S3 API" src="https://img.shields.io/badge/S3--compatible_API-569A31?style=for-the-badge&logo=amazons3&logoColor=white">
  <img alt="SQLite" src="https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white">
  <img alt="Dio HTTP client" src="https://img.shields.io/badge/Dio_HTTP_Client-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img alt="Firebase Hosting" src="https://img.shields.io/badge/Firebase_Hosting-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white">
</p>

## Product principles

- **Fingerprint locally.** SHA-256 is computed on the selected file; registration does not upload its bytes.
- **Ask before sharing.** Uploading a copy to private Neon Object Storage is a separate, explicit action.
- **Keep evidence portable.** A signed manifest and Solana commitment can be checked independently of the app account.
- **Describe results carefully.** A match means the bytes match a registered version. No match does not establish that a file is false.
- **Let the platform sponsor fees.** The backend pays Solana transaction fees; users sign their own provenance.

## Core capabilities

| Area | Current implementation |
| --- | --- |
| Home | Folders, owned work, and received work views |
| Library | File-type filters, folder management, asset grouping, and version history |
| Register | On-device fingerprinting, signed manifests, duplicate detection, optional file upload, and sponsored devnet registration |
| Verify | Public record lookup, publisher signature checks, Solana receipt checks, local file comparison, and version story |
| Accounts | Guest sessions, email/password, password reset, and Google sign-in through Firebase Auth |
| Wallet | Optional Android Mobile Wallet Adapter connection; secure device identity fallback on iOS and web |
| API | FastAPI services for file sharing, account-scoped records/folders, received work, and sponsored Solana transactions |

The registry currently uses Solana devnet.

## Architecture

```text
Flutter app (Android, iOS, web)
  ├── Firebase Auth: guest, email/password, Google
  ├── Firestore: signed manifests and app projections
  ├── SQLite: local fingerprints and preferences
  ├── Solana: publisher signatures and provenance commitments
  └── FastAPI backend
       ├── Firebase token validation
       ├── sponsored Solana transaction preparation and submission
       └── short-lived S3-compatible upload/download URLs
            └── Neon Object Storage: optional shared file copies
```

Firebase account IDs are not publisher signing keys. Firestore indexes are application views; the signed manifest and verified Solana transaction provide provenance evidence. The chain does not prove that content is truthful or establish legal ownership.

## OriginChain API

The hosted API provides interactive OpenAPI documentation at `/docs`, a ReDoc reference at `/redoc`, and a service health endpoint at `/health` on its configured API domain.

API operations are grouped into records, folders, received work, Solana registry transactions, and file sharing. Protected operations use a Firebase ID token as a bearer token. Public verification endpoints do not require an OriginChain account.

## Technology

| Layer | Technologies |
| --- | --- |
| App | Flutter, Dart, Material 3 |
| Authentication | Firebase Auth, Google Sign-In, anonymous guest accounts |
| App data | Cloud Firestore, SQLite (`sqflite`) |
| File sharing | FastAPI, Neon Object Storage, S3-compatible API, Dio |
| Provenance | SHA-256, Ed25519, Solana, Anchor |
| Hosting | Firebase Hosting, container deployment, Docker |
| Other Flutter packages | `crypto`, `cryptography`, `file_picker`, `flutter_secure_storage`, `share_plus`, `url_launcher` |

## Requirements

- Flutter SDK and Dart SDK compatible with `pubspec.yaml`
- Firebase project configured for Android, iOS, and web
- Firebase CLI and FlutterFire CLI for Firebase configuration/deployment
- Python 3.12+ for the API
- Anchor and Solana CLI for program development/deployment
- A container hosting service and Neon Object Storage bucket for hosted API/file sharing

## Run the app

```bash
flutter pub get
flutter run -d chrome
flutter run -d <android-device-id>
flutter run -d <ios-device-id>
```

The deployed API origin is configured with `ORIGINCHAIN_API_URL`. To use a local API:

```bash
flutter run -d chrome \
  --dart-define=ORIGINCHAIN_API_URL=http://localhost:8080
```

## Firebase and Google sign-in setup

1. In Firebase Console, open **Authentication → Sign-in method** and enable **Anonymous**, **Email/Password**, and **Google** providers.
2. Add the Android SHA-1 signing fingerprints to the Firebase Android app. For local debug builds, retrieve the fingerprint with `cd android && ./gradlew signingReport`.
3. Refresh the Android `google-services.json` after enabling Google sign-in and adding the Android signing fingerprints.
4. Add the iOS Firebase app with bundle ID `tech.originchain.originchain`; download `GoogleService-Info.plist`, add it to `ios/Runner`, and configure the Google reversed client ID URL scheme as described in the [Google Sign-In iOS setup](https://pub.dev/packages/google_sign_in).
5. For web, add the deployed Hosting domain and any local development domains to Firebase Authentication's authorized domains.
6. Refresh the FlutterFire configuration after changing registered Firebase apps or platforms:

```bash
flutterfire configure
```

Google sign-in on a guest account links the Google credential to that Firebase UID. Signing into an existing account from a guest session does not merge separate Firebase user data.

## Run the API locally

```bash
cp backend/.env.example backend/.env
# Fill in Neon, Firebase Admin, and Solana sponsor settings in backend/.env.
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
set -a && source .env && set +a
uvicorn app.main:app --reload --port 8080
```

Keep `.env`, Firebase service-account JSON, and Solana sponsor secrets out of Git. The API independently validates Firebase ID tokens and owns the fee-payer key. Its limits and environment variables are documented in [`backend/.env.example`](backend/.env.example).

## Deploy

Build and deploy the Flutter web client to Firebase Hosting:

```bash
flutter build web --release
firebase deploy --only hosting
```

Deploy the API from the `backend/` directory using the repository Dockerfile. Configure Neon credentials, Firebase Admin credentials, `SOLANA_FEE_PAYER_SECRET_KEY`, the devnet RPC URL, and the deployed Firebase Hosting origin in the hosting environment. The sponsor secret must remain server-side and funded with devnet SOL.

The Anchor program is deployed to devnet at `EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB`. Its upgrade authority is a separate Solana deployment key; the platform fee-payer key is not the upgrade authority.

## Repository layout

```text
lib/                 Flutter application and platform services
backend/             FastAPI API and Docker deployment
programs/             Anchor Solana program
specs/                Protocol and manifest specifications
infrastructure/       Firebase and deployment configuration
```

## Security notes

- Never commit `.env` files, Firebase service-account keys, wallet seed phrases, or sponsor secrets.
- Do not place private signing keys in Firestore or Neon.
- A wallet signature proves control of a signing key for that message; it does not prove a legal identity or copyright ownership.
- Public verification is accountless. File downloads require a valid share record and use expiring URLs.
- Review the community-maintained Flutter Solana packages and pin versions before making them security-critical.
