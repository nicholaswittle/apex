# Launching Apex Scheduler without a Mac

You do **not** need a Mac to launch on **Google Play** or to run the app in **production on Android phones**. You **do** need macOS somewhere in the pipeline for **TestFlight / App Store** — but that can be **cloud CI**, not a laptop on your desk.

---

## What you can do right now (Windows or Linux)

| Task | Mac required? | How |
|------|---------------|-----|
| Backend (Supabase, Stripe, Firebase console) | No | Browser only |
| Android development & testing | No | Flutter on Windows/Linux + Android phone or emulator |
| Play Store release (`.aab`) | No | Build on Linux CI or local Windows/Linux |
| Web version smoke test | No | `flutter run -d chrome` |
| App Store / TestFlight | Yes * | *Use GitHub Actions macOS runner or Codemagic — not your own Mac |

---

## Recommended path: Android first, iOS via cloud later

### Phase 1 — Ship Android (no Mac)

1. **Install Flutter** on your current PC  
   https://docs.flutter.dev/get-started/install

2. **Create signing keystore** (one time):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

3. **Configure signing**

```bash
cp android/key.properties.example android/key.properties
# Edit key.properties with keystore path and passwords
```

4. **Add Firebase Android config**

   - Firebase Console → Add Android app → package `com.wisense.apex`
   - Download `google-services.json` → `android/app/google-services.json`

5. **Set env vars** (copy `.env.local.example` → `.env.local`)

6. **Build release bundle**

```bash
flutter pub get
./scripts/build_release.sh android
```

Output: `build/app/outputs/bundle/release/app-release.aab`

7. **Upload to Play Console** → Internal testing → add testers → promote when ready.

**Or use GitHub Actions** (see below) — pushes to your branch can produce the `.aab` automatically.

---

### Phase 2 — iOS without owning a Mac

Apple still requires an **Apple Developer account** ($99/yr) and an **iOS build signed with Xcode tools**. You never have to open Xcode on your own machine if you use cloud build:

#### Option A — GitHub Actions (macOS runner)

Workflow: `.github/workflows/build-ios.yml` (included in this repo)

Requirements:

- Apple Developer Program enrolled
- App Store Connect **API key** (.p8) stored as GitHub secrets
- Signing certificate + provisioning profile OR automatic signing via Fastlane Match

High-level steps:

1. Create App Store Connect app for `com.wisense.apex`
2. Add GitHub secrets: `APPLE_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`
3. Push to `main` → workflow builds `.ipa` → uploads to TestFlight

#### Option B — Codemagic (easiest for Flutter + no Mac)

1. Connect GitHub repo at https://codemagic.io  
2. Use Flutter template, bundle ID `com.wisense.apex`  
3. Add environment variables (Supabase, Stripe) as `--dart-define`  
4. Connect Apple Developer → Codemagic handles certificates  
5. Build → TestFlight in one click  

Codemagic’s free tier is enough for early TestFlight builds.

#### Option C — Buy/rent a Mac later

When you get a Mac, follow `docs/LAUNCH_CHECKLIST.md` — nothing in the app blocks local Xcode builds.

---

## Day-to-day development without a Mac

```bash
# Clone repo, install deps
flutter pub get
cp .env.local.example .env.local   # fill Supabase + Stripe keys

# Run on connected Android phone (USB debugging on)
./scripts/run_dev.sh

# Or Chrome for UI checks (no push notifications on web)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Use a **physical Android device** for the full experience (push notifications).

---

## CI in this repo

| Workflow | Runner | Purpose |
|----------|--------|---------|
| `ci.yml` | Ubuntu | `flutter analyze` + `flutter test` on every PR |
| `build-android.yml` | Ubuntu | Release `.aab` (manual trigger; optional signing secrets) |
| `build-ios.yml` | macOS | Compile iOS (manual trigger; scaffold for TestFlight later) |

---

## Checklist: no-Mac minimum for Jigsy's pilot

- [ ] Supabase `FIREBASE_SERVICE_ACCOUNT_JSON` secret configured (push)
- [ ] Firebase Android `google-services.json` in repo (gitignored) or CI secret
- [ ] Android keystore created + `key.properties` configured
- [ ] `./scripts/build_release.sh android` succeeds
- [ ] Play Console internal track uploaded
- [ ] Privacy policy hosted (URL from `docs/PRIVACY_POLICY.md`)
- [ ] 3+ staff test on Android for one pay period

**iOS can wait** until you use Codemagic or GitHub macOS CI — the app code is already iOS-ready.

---

## FAQ

**Can I test iOS at all without a Mac?**  
Not on a real iPhone easily. Use Android for pilot; add iOS via TestFlight when cloud CI is set up.

**Will push notifications work on Android without a Mac?**  
Yes — Firebase Android only needs `google-services.json` and Supabase `FIREBASE_SERVICE_ACCOUNT_JSON`.

**Do I need a Mac for Apple push (APNs)?**  
No. Upload the APNs `.p8` key in **Firebase Console** (browser). No Xcode required.

**What should I buy first — Mac or Android test phone?**  
An **Android phone** (~$200) or use any Android you have. Cheaper and enough to validate launch with Jigsy's team.
