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
flutter run -d chrome       # Web; the Render API URL is the default
flutter run                 # Android or iOS device
flutter build web --release
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

The Library calls the authenticated `GET /v1/records` endpoint, which returns only the current Firebase user's records. Records sharing an `assetId` are grouped into version history. Registering a changed file from an asset creates a signed manifest that names the prior `versionId` and submits the Anchor `append_version` instruction; a matching file is rejected locally without consuming a sponsored transaction.

### Configure Neon and the API

Create a private Neon Object Storage bucket and obtain its S3 endpoint, region, access key, and secret. Neon documents the S3-compatible endpoint and credentials in its [Object Storage setup guide](https://neon.com/docs/storage/get-started). Keep credentials in a local untracked env file for development or Render environment secrets. Never place them in Flutter build defines, Firebase config, or the repository.

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

Set `ORIGINCHAIN_API_URL` to the API origin when running Flutter against a local API, for example `flutter run -d chrome --dart-define=ORIGINCHAIN_API_URL=http://localhost:8080`. For web, include the Hosting origin in `CORS_ORIGINS`. The API currently limits uploads to 100 MiB by default; tune `MAX_FILE_BYTES` to your needs.

### Deploy the API on Render

The Render web service uses `backend/` and the included Dockerfile, with health check path `/health`. Configure `AWS_ENDPOINT_URL_S3`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `NEON_BUCKET`, `CORS_ORIGINS`, `MAX_FILE_BYTES`, and `SIGNED_URL_TTL_SECONDS`. Set `CORS_ORIGINS` to the Firebase Hosting origin. Firebase Admin also needs credentials on Render; add a Firebase service-account JSON as a Render secret file and set `GOOGLE_APPLICATION_CREDENTIALS` to its mounted path. Never place that JSON or Neon credentials in the repo.

For platform-sponsored registration, add `SOLANA_FEE_PAYER_SECRET_KEY` as a Render secret, plus `SOLANA_RPC_URL=https://api.devnet.solana.com`, `ORIGINCHAIN_PROGRAM_ID=EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB`, `SOLANA_USER_DAILY_LIMIT=10`, and `SOLANA_GLOBAL_DAILY_LIMIT=100`. The sponsor key must be funded with devnet SOL and held only by the platform backend. The API caps registrations at 10 per Firebase UID per UTC day and 100 total per UTC day. `/health` reports whether the sponsor secret is configured.

The Anchor registry is deployed on Solana devnet at `EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB`. Version 1 anchors SHA-256 digests of the file and the minified UTF-8 JSON from `jsonEncode(manifest.toJson())`; the signed manifest itself stays in Firestore. To rebuild it, ensure Anchor, Solana CLI, Rust and the SBF toolchain are installed, then run:

```sh
anchor build
anchor program deploy --provider.cluster devnet --provider.wallet ~/.config/solana/originchain-devnet.json
```

This deployment wallet is the program upgrade authority. Never use a user's wallet as the app sponsor.

## Current foundation

- Three Flutter targets: Android, iOS, and web, with five shared navigation areas: Home, Library, Register, Verify, and Profile.
- First-run guest onboarding and light, dark, and system appearance modes. The appearance preference and onboarding choice are saved in SQLite.
- Registration computes a SHA-256 fingerprint on device. Users can explicitly upload the selected file to a private Neon bucket, publish a signed manifest to Firestore, and share a link. Recipients receive a short-lived Neon download URL and can compare the file locally.
- The Anchor registry is deployed on devnet. Registration uses a device-held Ed25519 publisher identity and a Render-held fee payer; the client cannot select arbitrary programs or transfers for sponsorship.
- Public verification checks the manifest signature and asks the backend to validate the matching confirmed Solana transaction. File bytes remain separate in Neon and are downloaded only through an expiring link.
- Android wallet connection through Mobile Wallet Adapter remains optional; registration works on web, iOS, and Android with the device publisher identity. Key recovery and verified real-world identities remain future work.

## Planned app areas

- Onboarding and authentication
- Home and activity
- Asset library
- Asset registration
- Public verification
- Profile, identity, wallet, security, and privacy settings

## Planned architecture

Keep UI, domain behavior, and infrastructure separate. Firebase and Solana integrations should sit behind services/repositories so protocol rules do not depend on a mobile vendor SDK. Local file hashing and an offline operation queue are part of the mobile core. A FastAPI service will validate requests and coordinate registry/indexing work; it must independently enforce authentication and authorization.

Before mainnet, finalize the protocol and manifest canonicalization, add key recovery and authenticated account linking, deploy a new program ID after a security review, provision and monitor the production sponsor wallet, and load-test the API quotas.
