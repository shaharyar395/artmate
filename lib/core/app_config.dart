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

  /// Google's sample units fill immediately and are labeled "Test Ad".
  /// The sheet units are still pending in AdMob, so they return no ad.
  /// Set this to false only after those units are approved, and put the live
  /// app id back in AndroidManifest.xml (com.google.android.gms.ads.APPLICATION_ID).
  static const bool useTestAds = true;

  static const String _liveAdmobAppId =
      'ca-app-pub-9297250663056879~2541710847';
  static const String _liveInterstitialAdUnitId =
      'ca-app-pub-9297250663056879/8070203844';
  static const String _liveBannerAdUnitId =
      'ca-app-pub-9297250663056879/2655983228';
  static const String _liveRewardedAdUnitId =
      'ca-app-pub-9297250663056879/6483547591';
  static const String _liveAppOpenAdUnitId =
      'ca-app-pub-9297250663056879/3637892402';
  static const String _liveNativeAdUnitId =
      'ca-app-pub-9297250663056879/2324810737';

  static const String _testAdmobAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  static String get admobAppId =>
      useTestAds ? _testAdmobAppId : _liveAdmobAppId;
  static String get interstitialAdUnitId =>
      useTestAds ? _testInterstitialAdUnitId : _liveInterstitialAdUnitId;
  static String get bannerAdUnitId =>
      useTestAds ? _testBannerAdUnitId : _liveBannerAdUnitId;
  static String get rewardedAdUnitId =>
      useTestAds ? _testRewardedAdUnitId : _liveRewardedAdUnitId;
  static String get appOpenAdUnitId =>
      useTestAds ? _testAppOpenAdUnitId : _liveAppOpenAdUnitId;
  static String get nativeAdUnitId =>
      useTestAds ? _testNativeAdUnitId : _liveNativeAdUnitId;

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
  static const String buildTag = '1.0.0 · build 2026-09-28g';

  /// How long the splash loading bar runs.
  static const Duration splashDuration = Duration(milliseconds: 2800);
}
