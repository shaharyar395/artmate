# Draw Together — Flutter app (Phase 1)

Recreates the flow from the reference recording:

Splash (loading bar) → Choose your language → age → "what brings you in" → interests → Lobby → Profile → Settings (Language · Share · Rate · Feedback · Policy · Check for update)

## 1. Run it (Windows, macOS or Linux)

You need Flutter 3.22 or newer (`flutter --version`).

```bash
cd draw_together
flutter create --org com.occess --project-name draw_together --platforms android,ios .
flutter pub get
flutter run
```

`flutter create .` only adds the `android/` and `ios/` folders. It leaves `lib/` alone.

## 2. Android setup (one time)

**`android/app/src/main/AndroidManifest.xml`**: add these lines above `<application ...>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="market"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
</queries>
```

**`android/app/build.gradle`** (or `build.gradle.kts`): set `applicationId` to match `AppConfig.androidPackage`, and use `minSdk 21` or higher.

**iOS only** (if you build for iPhone): in `ios/Podfile`, inside `post_install`, add `'PERMISSION_NOTIFICATIONS=1'` to `GCC_PREPROCESSOR_DEFINITIONS`.

## 3. Branding and artwork

- **Name, package ID, feedback email and policy URL:** all in `lib/core/app_config.dart`.
- **Artwork:** placeholders are emoji. Put your own PNGs into `assets/images/` using the names in `assets/images/README.txt` and they replace the emoji automatically.
- **Colors:** in `lib/core/theme.dart`, sampled from the recording.
- **Text:** 8 languages in `lib/core/strings.dart` (en, es, pt, fr, de, vi, id, hi).

## 4. What works

| Screen | Functionality |
|---|---|
| Splash | Animated loading bar. Goes to onboarding on first launch, straight to the Lobby after that |
| Language | 8 languages with flags. Applied on Continue and saved |
| Age / Purpose / Interests | 3-step progress bar. Continue stays disabled until you choose (interests need at least 1) |
| Lobby | Greeting by time of day and username (tap to open Profile), spinning event button, Premium button, 3 mode banners (Draw Together LIVE / Trace Art / Art Battle). Asks for notification permission once |
| Profile | Tap the avatar to change it, tap the name to rename. Live "Spent time" counter, lessons, level (arrow opens the levels list), My buddies, My album / Favorite tabs, Sort by Newest/Oldest menu, empty album with Draw Now |
| Setting | Toggles for Turn off messages, Music, Sound Fx and Vibrate (all saved; Sound Fx and Vibrate affect every tap), Language (blue screen, apply with the green check), Share (system share sheet), Rate 5 stars (star sheet, then Play Store or feedback email), Feedback (email), Policy (browser), Check for update (Play Store) |

Placeholders for the next phase: the banner games, Premium, the event button and Draw Now show "Coming soon!".

## Project layout

```
lib/
  main.dart
  core/     app_config · theme · strings (i18n) · catalog (onboarding data) · app_state (saved settings)
  widgets/  common.dart (buttons, outlined titles, art slots, onboarding scaffold)
  screens/  splash · lobby · profile · settings · language
            onboarding/ language_select · age · purpose · interests
```
