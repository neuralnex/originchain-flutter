# OriginChain

OriginChain is a Flutter app for registering and verifying the provenance of digital assets. Android, iOS, and web are targets of this shared Flutter client.

## Product boundaries

- Hash files on the device. Upload originals only when the user explicitly chooses to store or share them.
- Use Firebase for app identity, synchronization, and notifications. Firebase records are searchable projections, not canonical provenance evidence.
- Use Solana for provenance commitments. A Firebase UID is not a publisher signing identity.
- The OriginChain platform covers all Solana transaction and network fees. Users must not be asked to pay them.
- Keep wallet connection optional and platform-aware. Android wallet handoff and iOS wallet connection need separate paths.

## Mobile development

Open this repository in VS Code and use the Flutter and Dart extensions.

```sh
flutter pub get
flutter run -d chrome       # Web
flutter run                 # Android or iOS device
flutter build web --release --dart-define=ORIGINCHAIN_API_URL=https://originchain-flutter.onrender.com
```

Local fingerprints and preferences use SQLite on Android and iOS. Web uses SQLite compiled to WebAssembly in a browser worker via `sqflite_common_ffi_web`. That web companion is currently documented as experimental. If its version changes, rerun `dart run sqflite_common_ffi_web:setup` to refresh `web/sqlite3.wasm` and `web/sqflite_sw.js`.

Firebase is configured for Android, iOS, and web through `lib/firebase_options.dart` and initialized when the app starts. To regenerate the configuration after changing Firebase apps or platforms, run `flutterfire configure` from the project root.

## Firebase Hosting

Hosting serves the Flutter web release from `build/web`, uses an SPA rewrite for Flutter routes, and builds the web bundle before deployment. The Firebase CLI project alias is set to the configured project.

```sh
firebase login
firebase deploy --only hosting
```

The web app URL will be printed after deployment. Firebase Hosting site setup and deployment still require your Google account to have Hosting access on this Firebase project.

## File sharing with Firestore and Neon

Enable **Anonymous** in Firebase Authentication, create the Firestore database, and deploy the included rules with `firebase deploy --only firestore:rules`. Publishing creates a public Firestore record containing the signed SHA-256 manifest. The Register screen explicitly uploads the selected original to a private Neon bucket; the recipient's share page can issue a short-lived download link and locally verify the downloaded copy against the manifest.

The first share creates a device signing key in platform secure storage. This is a self-issued device identity; it does not prove a legal name, ownership, or wallet identity. Key recovery and linking the signing identity to a wallet/account are future work. On web, secure storage uses the package's experimental WebCrypto implementation and is tied to the hosting origin.

The FastAPI bridge in `backend/` issues short-lived S3-compatible upload/download URLs. The app sends bytes directly to Neon, then the API streams the stored object through SHA-256 and checks its size against the signed manifest before attaching the object key to Firestore. Neon credentials stay on the server. A shared download link is available to anyone holding the share record URL while its signed download URL remains valid.

### Configure Neon and the API

Create a private Neon Object Storage bucket and obtain its S3 endpoint, region, access key, and secret. Neon documents the S3-compatible endpoint and credentials in its [Object Storage setup guide](https://neon.com/docs/storage/get-started). Keep credentials in a local untracked env file for development or a secret manager in Cloud Run. Never place them in Flutter build defines, Firebase config, or the repository.

```sh
cp backend/.env.example backend/.env
# Fill in the Neon endpoint, region, credentials, and bucket in backend/.env.
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
set -a && source .env && set +a
uvicorn app.main:app --reload --port 8080
```

Set `ORIGINCHAIN_API_URL` to the API origin when running Flutter, for example `flutter run -d chrome --dart-define=ORIGINCHAIN_API_URL=http://localhost:8080`. For web, include the Hosting origin in `CORS_ORIGINS`. Deploy the `backend/` Dockerfile to Cloud Run with unauthenticated HTTP enabled (the API verifies Firebase ID tokens itself), a runtime service account with Firestore access, and the Neon values supplied as Secret Manager environment variables. The API currently limits uploads to 100 MiB by default; tune `MAX_FILE_BYTES` to your needs.

### Deploy the API on Render

Create or configure the Render web service with `backend/` as its root directory and the included Dockerfile. Set the health check path to `/health`. Add `AWS_ENDPOINT_URL_S3`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `NEON_BUCKET`, `CORS_ORIGINS`, `MAX_FILE_BYTES`, and `SIGNED_URL_TTL_SECONDS` as Render environment variables. Set `CORS_ORIGINS` to the Firebase Hosting origin. Firebase Admin also needs credentials on Render; add a Firebase service-account JSON as a Render secret file and set `GOOGLE_APPLICATION_CREDENTIALS` to its mounted path. Never place that JSON or Neon credentials in the repo. The provided Render service URL is configured into Firebase's Hosting build.

## Current foundation

- Three Flutter targets: Android, iOS, and web, with five shared navigation areas: Home, Library, Register, Verify, and Profile.
- First-run guest onboarding and light, dark, and system appearance modes. The appearance preference and onboarding choice are saved in SQLite.
- Registration computes a SHA-256 fingerprint on device. Users can explicitly upload the selected file to a private Neon bucket, publish a signed manifest to Firestore, and share a link. Recipients receive a short-lived Neon download URL and can compare the file locally.
- Solana RPC is configured for devnet. Android can connect through the community Flutter Mobile Wallet Adapter package; the wallet remains user-custodied and the app never imports private keys.
- iOS and web wallet connections still need their own adapter. The Flutter MWA package currently documents Android support only.
- Solana registry commits, platform-sponsored fees, persistent account sign-in, key recovery, and verified publisher identities are not implemented yet. The Solana fee payer must be a platform-controlled backend signer; no payer key belongs in this client.

## Planned app areas

- Onboarding and authentication
- Home and activity
- Asset library
- Asset registration
- Public verification
- Profile, identity, wallet, security, and privacy settings

## Planned architecture

Keep UI, domain behavior, and infrastructure separate. Firebase and Solana integrations should sit behind services/repositories so protocol rules do not depend on a mobile vendor SDK. Local file hashing and an offline operation queue are part of the mobile core. A FastAPI service will validate requests and coordinate registry/indexing work; it must independently enforce authentication and authorization.

The canonical protocol and manifest schema should be defined before production Solana registration is implemented.
