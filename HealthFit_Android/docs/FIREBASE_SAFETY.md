# Firebase safety — Android + iOS shared backend

## Hard rules

1. **Do not deploy** `firestore.rules`, `storage.rules`, indexes, or Cloud Functions from the Android workstream unless a dual-platform review is done.
2. Android **reads/writes only** collections/fields already used by the shipping iOS app.
3. Phase 1 keeps **workout session cloud writes disabled** (local catalog only) until schema parity is checked against iOS `WorkoutSession`.
4. Play Billing entitlements stay on-device until an entitlement sync strategy that iOS already understands is agreed.
5. Register a **new Android app** in Firebase Console (`com.healthfit.android`) — this does **not** change iOS config. Download `google-services.json` into `app/` (gitignored).

## Shared project

- Project ID: `healthfit-30d87`
- Same Auth users can sign in on both platforms with email/password (and Google when wired).
- Storage / Pulse / Coach paths remain iOS-owned until Android feature phases land.

## Adding the Android app in Console (safe)

1. Firebase Console → Project settings → Add app → Android
2. Package name: `com.healthfit.android` (debug: `com.healthfit.android.debug` as second app if needed)
3. Download `google-services.json` → `HealthFit_Android/app/google-services.json`
4. **Do not** touch Security Rules or Functions.
