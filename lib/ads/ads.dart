import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/app_config.dart';

/// AdMob placements from the Photo Sketch sheet.
/// Premium players see no ads. Rewarded ads only play when the user taps.
class Ads {
  Ads._();

  static bool Function() isPremium = () => false;

  static InterstitialAd? _interstitial;
  static RewardedAd? _rewarded;
  static AppOpenAd? _appOpen;
  static bool _showing = false;
  static DateTime _lastFullScreen = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get allowed => !isPremium();

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('Ads init failed: $e');
      return;
    }
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
  }

  static void showAppOpen() {
    if (!allowed || _showing) return;
    if (DateTime.now().difference(_lastFullScreen) <
        const Duration(seconds: 30)) {
      return;
    }
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return;
    }
    _appOpen = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        _lastFullScreen = DateTime.now();
        ad.dispose();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        ad.dispose();
        _loadAppOpen();
      },
    );
    ad.show();
  }

  /// After the player leaves a drawing mode and comes back to the lobby.
  static void showInterstitial() {
    if (!allowed || _showing) return;
    if (DateTime.now().difference(_lastFullScreen) <
        const Duration(seconds: 45)) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        _lastFullScreen = DateTime.now();
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// User tapped "Watch ad" (rewarded must be opt-in).
  static void showRewarded() {
    if (!allowed || _showing) return;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return;
    }
    _rewarded = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        _lastFullScreen = DateTime.now();
        ad.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        ad.dispose();
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) {});
  }

  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) =>
            debugPrint('Interstitial failed: $error'),
      ),
    );
  }

  static void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (error) => debugPrint('Rewarded failed: $error'),
      ),
    );
  }

  static void _loadAppOpen() {
    AppOpenAd.load(
      adUnitId: AppConfig.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (error) => debugPrint('App open failed: $error'),
      ),
    );
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!Ads.allowed) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AppConfig.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed: $error');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

class AdNative extends StatefulWidget {
  const AdNative({super.key});

  @override
  State<AdNative> createState() => _AdNativeState();
}

class _AdNativeState extends State<AdNative> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!Ads.allowed) return;
    final ad = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Native failed: $error');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(height: 120, child: AdWidget(ad: ad));
  }
}
