# Apex Scheduler — App Store / Play Store launch checklist

Bundle ID: **`com.wisense.apex`**

## Before first Mac build

- [ ] Apple Developer Program enrolled ($99/yr)
- [ ] Google Play Console account ($25 one-time)
- [ ] Flutter stable installed on M1 Mac (`flutter doctor -v`)
- [ ] Xcode installed, license accepted
- [ ] CocoaPods: `sudo gem install cocoapods`

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
**Subtitle:** Shift scheduling for hourly teams  
**Category:** Business / Productivity  
**Description:** Multi-tenant shift calendar, availability, swap requests, time clock, and owner billing for restaurants, retail, gyms, and clinics.

## Privacy

- Collects: email, name, work schedule data, optional push token
- Third parties: Supabase (auth/database), Firebase (push), Stripe (owner subscription only)
- Host a privacy policy URL before submission

## Verify locally

```bash
flutter analyze
flutter test
./scripts/build_release.sh ios
./scripts/build_release.sh android
```
