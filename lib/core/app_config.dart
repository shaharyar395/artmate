/// Everything brand-specific lives here so you can rename / rebrand in one place.
class AppConfig {
  /// Display name (also used in share text, feedback subject).
  static const String appName = 'Sketchmate';

  /// Two-tone wordmark on the splash screen (first part white, second yellow).
  static const String wordmarkPart1 = 'SKETCH';
  static const String wordmarkPart2 = 'MATE';
  static const String tagline = 'Draw together';

  /// Must match applicationId in android/app/build.gradle.kts and the
  /// package_name in android/app/google-services.json (Firebase).
  static const String androidPackage =
      'com.mob.sketchmate.app.artworkout.learn.how.to.draw.drawing.draw.drawing.paint';

  /// Firebase Realtime Database used for online matches (project
  /// artmate-photo-sketch). Copy the exact URL from Firebase console →
  /// Realtime Database (top of the Data tab) if yours is in another region,
  /// e.g. https://artmate-photo-sketch-default-rtdb.europe-west1.firebasedatabase.app
  static const String firebaseDatabaseUrl =
      'https://artmate-photo-sketch-default-rtdb.firebaseio.com';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const String marketUrl = 'market://details?id=$androidPackage';

  static const String feedbackEmail = 'occessstudio599@gmail.com';
  static const String privacyPolicyUrl =
      'https://sites.google.com/view/mob-apps-inc/privacy-policy';
  /// The sheet only lists a privacy policy, so Terms opens that same page.
  static const String termsUrl = privacyPolicyUrl;

  /// AdMob (Android), from the Photo Sketch integration sheet.
  static const String admobAppId = 'ca-app-pub-9297250663056879~2541710847';
  static const String interstitialAdUnitId =
      'ca-app-pub-9297250663056879/8070203844';
  static const String bannerAdUnitId =
      'ca-app-pub-9297250663056879/2655983228';
  static const String rewardedAdUnitId =
      'ca-app-pub-9297250663056879/6483547591';
  static const String appOpenAdUnitId =
      'ca-app-pub-9297250663056879/3637892402';
  static const String nativeAdUnitId =
      'ca-app-pub-9297250663056879/2324810737';

  /// Premium subscription product IDs — create these in Google Play Console
  /// (Monetize > Subscriptions) with exactly these IDs.
  static const String premiumYearlyId = 'premium_yearly';
  static const String premiumWeeklyId = 'premium_weekly';

  /// When the real Google Play sheet can't open (app not installed from
  /// Play, or subscriptions not created yet), show a look-alike TEST payment
  /// sheet so the flow can be tried. Set to false before publishing.
  static const bool billingTestMode = true;

  /// Shown only until the store returns real, localized prices.
  static const String fallbackYearlyPrice = 'Rs 2,800.00';
  static const double fallbackYearlyAmount = 2800;
  static const String fallbackWeeklyPrice = 'Rs 270.00';
  static const double fallbackWeeklyAmount = 270;
  static const String fallbackCurrency = 'PKR';

  /// Draw Together chat: "Say something..." is always shown with friends
  /// who joined by room code. With random online partners it is shown when
  /// this is true (like the reference app); set false for emoji & phrases
  /// only. Messages are always filtered (rude words, links, phone numbers).
  static const bool allowTextChatWithStrangers = true;

  /// Shown at the bottom of Settings, so you can check that every test
  /// phone runs the same build. Change it whenever you ship a new build.
  static const String buildTag = '1.0.0 · build 2026-09-28f';

  /// How long the splash loading bar runs.
  static const Duration splashDuration = Duration(milliseconds: 2800);
}
