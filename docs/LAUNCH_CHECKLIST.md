# Apex Scheduler — App Store / Play Store launch checklist

Bundle ID: **`com.wisense.apex`**

> **No Mac?** See **[docs/LAUNCH_WITHOUT_MAC.md](LAUNCH_WITHOUT_MAC.md)** — ship Android first, build iOS in GitHub Actions or Codemagic.

## Before first build

- [ ] Apple Developer Program enrolled ($99/yr) — needed for iOS only
- [ ] Google Play Console account ($25 one-time) — **no Mac required**
- [ ] Flutter installed on your PC (Windows/Linux) or use GitHub Actions
- [ ] Mac + Xcode — **optional** if using cloud CI for iOS (see `LAUNCH_WITHOUT_MAC.md`)

## Firebase (push notifications)

1. Create Firebase project (or reuse WiSense project)
2. Add **iOS app** with bundle ID `com.wisense.apex`
3. Add **Android app** with package `com.wisense.apex`
4. Download configs:
   - `ios/Runner/GoogleService-Info.plist`
   - `android/app/google-services.json`
5. Enable **Cloud Messaging** in Firebase console
6. Apple: upload APNs key (.p8) in Firebase → Project settings → Cloud Messaging

Or run FlutterFire CLI from project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
```

## Supabase + Stripe (runtime)

Pass at build/run time (see `scripts/run_dev.sh`):

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Auth + data |
| `SUPABASE_ANON_KEY` | Public anon key |
| `STRIPE_PUBLISHABLE_KEY` | Owner billing Payment Sheet |

## iOS — TestFlight

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities**
   - Team: your Apple Developer team
   - Bundle ID: `com.wisense.apex`
   - Enable **Push Notifications**
3. For release archive: set `Runner.entitlements` `aps-environment` to **production**
4. Build from CLI:

```bash
./scripts/build_release.sh ios
```

5. Xcode → **Product → Archive** → Distribute to App Store Connect
6. App Store Connect: create app, privacy policy URL, screenshots, age rating 4+

## Android — Play Store

1. Create upload keystore (once):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copy `android/key.properties.example` → `android/key.properties` and fill in paths/passwords

3. Build:

```bash
./scripts/build_release.sh android
```

4. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console

## Store listing copy (starter)

**Name:** Apex Scheduler  
**Subtitle:** Staff scheduling for Jigsy's Brewpub  
**Category:** Business / Productivity  
**Description:** Shift calendar, availability, swap requests, time clock, and owner billing for small hospitality teams.

## Supabase Edge Function secrets

Configure in Supabase Dashboard → Project Settings → Edge Functions:

| Secret | Used by |
|--------|---------|
| `STRIPE_SECRET_KEY` | `create-payment-intent`, `stripe-webhook` |
| `STRIPE_WEBHOOK_SECRET` | `stripe-webhook` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | `send-push-notification` |

Register the Stripe webhook endpoint:

```
https://<project-ref>.supabase.co/functions/v1/stripe-webhook
```

Events: `payment_intent.succeeded`, `invoice.payment_failed`, `customer.subscription.deleted`

## Privacy

- Collects: email, name, work schedule data, optional push token
- Third parties: Supabase (auth/database), Firebase (push), Stripe (owner subscription only)
- Host privacy policy before submission: see **[docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md)**

## Verify locally

```bash
flutter analyze
flutter test
./scripts/build_release.sh ios
./scripts/build_release.sh android
```
