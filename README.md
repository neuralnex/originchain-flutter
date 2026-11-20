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
flutter build web --release
```

Local fingerprints and preferences use SQLite on Android and iOS. Web uses SQLite compiled to WebAssembly in a browser worker via `sqflite_common_ffi_web`. That web companion is currently documented as experimental. If its version changes, rerun `dart run sqflite_common_ffi_web:setup` to refresh `web/sqlite3.wasm` and `web/sqflite_sw.js`.

Firebase is configured for Android, iOS, and web through `lib/firebase_options.dart` and initialized when the app starts. To regenerate the configuration after changing Firebase apps or platforms, run `flutterfire configure` from the project root. Firebase Auth, Firestore, Storage, Messaging, and App Check still need their feature-specific setup before use.

## Firebase Hosting

Hosting serves the Flutter web release from `build/web`, uses an SPA rewrite for Flutter routes, and builds the web bundle before deployment. The Firebase CLI project alias is set to the configured project.

```sh
firebase login
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run
firebase deploy --only hosting
```

The web app URL will be printed after deployment. Firebase Hosting site setup and deployment still require your Google account to have Hosting access on this Firebase project.

## Current foundation

- Three Flutter targets: Android, iOS, and web, with five shared navigation areas: Home, Library, Register, Verify, and Profile.
- First-run guest onboarding and light, dark, and system appearance modes. The appearance preference and onboarding choice are saved in SQLite.
- Registration currently computes a SHA-256 fingerprint on device and stores its summary in SQLite. This is a local fingerprint only; it does not publish a manifest or submit a Solana transaction.
- Solana RPC is configured for devnet. Android can connect through the community Flutter Mobile Wallet Adapter package; the wallet remains user-custodied and the app never imports private keys.
- iOS and web wallet connections still need their own adapter. The Flutter MWA package currently documents Android support only.
- Sponsored transactions, the OriginChain registry program, signed provenance manifests, file sharing, sign-in, public verification, and Firebase synchronization are not implemented yet. The Solana fee payer must be a platform-controlled backend signer; no payer key belongs in this client.

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
