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

  /// Height of the bottom ad, so screens leave room for it.
  static final ValueNotifier<double> pageAdHeight = ValueNotifier(0);

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

/// Tracks the visible route so the bottom ad can reload on every page.
class AdRoutes extends NavigatorObserver {
  static final ValueNotifier<String> page = ValueNotifier('/');

  void _set(Route<dynamic>? route) {
    page.value = route?.settings.name ?? '/';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);
}

/// Bottom ad used on every screen after the splash, matching the reference
/// app: "Ad Loading..." until the ad arrives, then a medium native ad with a
/// chevron that closes it on this page.
class CollapsiblePageAd extends StatefulWidget {
  const CollapsiblePageAd({super.key});

  static const double loadingHeight = 36;
  static const double loadedHeight = 280;

  @override
  State<CollapsiblePageAd> createState() => _CollapsiblePageAdState();
}

class _CollapsiblePageAdState extends State<CollapsiblePageAd> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    if (!Ads.allowed) {
      _publish(0);
      return;
    }
    _publish(CollapsiblePageAd.loadingHeight);
    final ad = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted || _closed) return;
          setState(() => _loaded = true);
          _publish(CollapsiblePageAd.loadedHeight);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Page ad failed: $error');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _publish(double height) {
    if (Ads.pageAdHeight.value != height) Ads.pageAdHeight.value = height;
  }

  void _close() {
    setState(() => _closed = true);
    _publish(0);
    _ad?.dispose();
    _ad = null;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Ads.allowed || _closed) return const SizedBox.shrink();
    if (!_loaded || _ad == null) {
      return Container(
        height: CollapsiblePageAd.loadingHeight,
        color: const Color(0xFFE6E6E6),
        alignment: Alignment.center,
        child: Text(
          'Ad Loading...',
          style: const TextStyle(
            color: Color(0xFF8A8A8A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return SizedBox(
      height: CollapsiblePageAd.loadedHeight,
      child: Stack(
        children: [
          Positioned.fill(child: AdWidget(ad: _ad!)),
          Positioned(
            top: 6,
            right: 8,
            child: Material(
              color: const Color(0xCC222222),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _close,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
