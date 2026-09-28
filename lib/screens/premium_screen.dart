import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ads.dart';
import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/trace_art_data.dart';
import '../core/trace_art_model.dart';
import '../premium/premium_service.dart';
import '../widgets/common.dart';

/// Premium plans page: Yearly (Save 90%) / Weekly, Continue → store payment
/// sheet (tap outside it to close), Cancel Anytime, Privacy | Terms,
/// Restore Purchase.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  String _plan = AppConfig.premiumYearlyId;
  bool _processing = false;
  bool _restoring = false;
  StreamSubscription<PurchaseEvent>? _sub;

  PremiumService get _svc => PremiumService.instance;

  @override
  void initState() {
    super.initState();
    _sub = _svc.events.stream.listen(_onEvent);
    if (_svc.products.isEmpty) {
      _svc.init(AppScope.read(context)).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(PurchaseEvent e) {
    if (!mounted) return;
    if (e.pending) return; // keep "Processing…"
    setState(() => _processing = false);
    if (e.ok && !e.restored) {
      _showThanks();
    } else if (e.message != null) {
      _toast(tr(context, 'purchaseFailed'));
    }
  }

  // ------------------------------------------------------------ prices
  (String, String) _yearlyTexts() {
    final p = _svc.product(AppConfig.premiumYearlyId);
    if (p == null) {
      final perWeek = AppConfig.fallbackYearlyAmount / 52;
      return (
        tr(context, 'justPerYear', {'p': AppConfig.fallbackYearlyPrice}),
        '${AppConfig.fallbackCurrency} ${perWeek.toStringAsFixed(2)}/ ${tr(context, 'weekShort')}'
      );
    }
    final perWeek = p.rawPrice / 52;
    return (
      tr(context, 'justPerYear', {'p': p.price}),
      '${p.currencyCode} ${perWeek.toStringAsFixed(2)}/ ${tr(context, 'weekShort')}'
    );
  }

  (String, String) _weeklyTexts() {
    final p = _svc.product(AppConfig.premiumWeeklyId);
    final price = p?.price ?? AppConfig.fallbackWeeklyPrice;
    return (price, '$price/ ${tr(context, 'weekShort')}');
  }

  // ------------------------------------------------------------ actions
  Future<void> _continue() async {
    if (_processing) return;
    final app = AppScope.read(context);
    app.tap();
    if (app.isPremium) {
      _toast(tr(context, 'alreadyPremium'));
      return;
    }
    setState(() => _processing = true);
    // Like the reference app: show "Processing…" briefly, then the sheet.
    final results = await Future.wait([
      _svc.buy(_plan),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final r = results.first as BuyResult;
    if (r == BuyResult.started) {
      // The Google Play sheet is open. Tapping outside it closes it; the
      // purchase stream then reports "cancelled" and resets the button.
      return;
    }
    if (AppConfig.billingTestMode) {
      final bought = await showTestPaymentSheet(
        context,
        planTitle: tr(context,
            _plan == AppConfig.premiumYearlyId ? 'yearly' : 'weekly'),
        price: _plan == AppConfig.premiumYearlyId
            ? _yearlyTexts().$1
            : _weeklyTexts().$1,
        reason: _svc.lastProblem,
      );
      if (!mounted) return;
      setState(() => _processing = false);
      if (bought == true) _svc.grantTestPremium(_plan);
      return;
    }
    setState(() => _processing = false);
    _toast(tr(context,
        r == BuyResult.productNotFound ? 'productNotFound' : 'storeUnavailable'));
  }

  Future<void> _restore() async {
    if (_restoring) return;
    AppScope.read(context).tap();
    setState(() => _restoring = true);
    final found = await _svc.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    _toast(tr(context, found ? 'restoreSuccess' : 'nothingToRestore'));
  }

  Future<void> _openUrl(String url) async {
    AppScope.read(context).tap();
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(70, 0, 70, 110),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(children: [
          const Emoji('🎨', size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                textAlign: TextAlign.center,
                style: nunito(13,
                    weight: FontWeight.w600, color: AppColors.textSoft)),
          ),
        ]),
      ));
  }

  Future<void> _showThanks() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Emoji('👑', size: 60),
          const SizedBox(height: 8),
          Text(tr(context, 'welcomePremium'),
              textAlign: TextAlign.center,
              style: nunito(20, weight: FontWeight.w800)),
          const SizedBox(height: 16),
          PrimaryButton(label: 'OK', onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final (yMain, ySide) = _yearlyTexts();
    final (wMain, wSide) = _weeklyTexts();
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: 250 + top, child: const _HeaderArt()),
              // ------------------------------ title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppConfig.appName,
                      style: nunito(30,
                          weight: FontWeight.w900,
                          color: const Color(0xFF1F7BE8))),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFE27A), Color(0xFFFFC93C)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tr(context, 'premium'),
                        style: nunito(16,
                            weight: FontWeight.w700,
                            color: const Color(0xFF7A4A00))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(tr(context, 'premiumSub'),
                    style: nunito(13,
                        weight: FontWeight.w500, color: AppColors.sub)),
              ),
              const SizedBox(height: 16),
              // ------------------------------ features
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(children: [
                  _feature('🚫', tr(context, 'featNoAds')),
                  _feature('🖼️', tr(context, 'featNewContent')),
                  _feature('🧑‍💼', tr(context, 'featSupport')),
                ]),
              ),
              const SizedBox(height: 14),
              // ------------------------------ plans
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  _PlanCard(
                    title: tr(context, 'yearly'),
                    main: yMain,
                    side: ySide,
                    badge: tr(context, 'save90'),
                    selected: _plan == AppConfig.premiumYearlyId,
                    onTap: () =>
                        setState(() => _plan = AppConfig.premiumYearlyId),
                  ),
                  const SizedBox(height: 10),
                  _PlanCard(
                    title: tr(context, 'weekly'),
                    main: wMain,
                    side: wSide,
                    selected: _plan == AppConfig.premiumWeeklyId,
                    onTap: () =>
                        setState(() => _plan = AppConfig.premiumWeeklyId),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // ------------------------------ continue
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _continue,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _processing
                          ? const Color(0xFF3F8BF5)
                          : const Color(0xFF1673FF),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: _processing
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 10),
                            Text(tr(context, 'processing'),
                                style: nunito(17,
                                    weight: FontWeight.w600,
                                    color: Colors.white)),
                          ])
                        : Text(
                            app.isPremium
                                ? tr(context, 'premiumActive')
                                : tr(context, 'continue'),
                            style: nunito(17,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(tr(context, 'cancelAnytime'),
                    style: nunito(13,
                        weight: FontWeight.w600, color: AppColors.textSoft)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
                child: Text(tr(context, 'subDisclaimer'),
                    textAlign: TextAlign.center,
                    style: nunito(11,
                        weight: FontWeight.w500,
                        color: const Color(0xFFA0A0A0))),
              ),
              if (!app.isPremium)
                Center(
                  child: _link(tr(context, 'watchAd'), () {
                    app.tap();
                    Ads.showRewarded();
                  }),
                ),
              // ------------------------------ links
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(children: [
                  _link(tr(context, 'privacy'),
                      () => _openUrl(AppConfig.privacyPolicyUrl)),
                  Text('  |  ',
                      style: nunito(12, color: const Color(0xFF1F7BE8))),
                  _link(tr(context, 'terms'),
                      () => _openUrl(AppConfig.termsUrl)),
                  const Spacer(),
                  _restoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : _link(tr(context, 'restorePurchase'), _restore),
                ]),
              ),
            ],
          ),
          // ------------------------------ close
          Positioned(
            top: top + 10,
            right: 14,
            child: GestureDetector(
              onTap: () {
                app.tap();
                Navigator.of(context).maybePop();
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(String emoji, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Emoji(emoji, size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: nunito(15,
                  weight: FontWeight.w600, color: const Color(0xFF2A2A2A))),
        ]),
      );

  Widget _link(String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Text(text,
            style: nunito(13,
                weight: FontWeight.w600, color: const Color(0xFF1F7BE8))),
      );
}

// ================================================================ widgets
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.main,
    required this.side,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String main;
  final String side;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppScope.read(context).tap();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE6F1FF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? const Color(0xFF1F7BE8)
                      : const Color(0xFFE3E6EA),
                  width: selected ? 2 : 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        selected
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2DBE5A), size: 20)
                            : Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF9A9A9A),
                                      width: 1.5),
                                ),
                              ),
                        const SizedBox(width: 8),
                        Text(title,
                            style: nunito(16,
                                weight: FontWeight.w700,
                                color: selected
                                    ? const Color(0xFF1F7BE8)
                                    : const Color(0xFF2A2A2A))),
                      ]),
                      const SizedBox(height: 4),
                      Text(main,
                          style: nunito(13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF3A3A3A))),
                    ],
                  ),
                ),
                Text(side,
                    style: nunito(12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF3A3A3A))),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              right: 10,
              top: -9,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC61A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: nunito(11,
                        weight: FontWeight.w800,
                        color: const Color(0xFF3A2A00))),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sky-blue header with a fan of drawing cards and sparkles.
class _HeaderArt extends StatelessWidget {
  const _HeaderArt();

  static const _cards = [
    // outer cards first so the middle one is painted on top
    ('dt_food_icecream_a', -0.42, -0.62, 0.10),
    ('anime_cat_ear_girl', 0.42, 0.62, 0.10),
    ('animal_penguin', -0.22, -0.30, 0.02),
    ('trending_cat_fish', 0.22, 0.30, 0.02),
    ('cartoon_bow_bunny', 0.0, 0.0, -0.02),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      final cardW = w * 0.3;
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7FB9FF), Color(0xFFCFE6FF), Colors.white],
            stops: [0, 0.7, 1],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final sp in const [
              Offset(0.12, 0.35),
              Offset(0.85, 0.28),
              Offset(0.5, 0.18),
              Offset(0.25, 0.8),
              Offset(0.78, 0.82),
            ])
              Positioned(
                left: sp.dx * w,
                top: sp.dy * h,
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 16),
              ),
            for (final (id, x, angle, drop) in _cards)
              Positioned(
                left: w / 2 + x * w - cardW / 2,
                top: h * 0.3 + drop * h + (x.abs() * h * 0.12),
                child: Transform.rotate(
                  angle: angle * 0.5,
                  child: Container(
                    width: cardW,
                    height: cardW * 1.2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: CustomPaint(
                        painter: _ArtPainter(kTraceArt[id]!)),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);
  final TraceArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    paintTraceArtAt(
        canvas,
        Rect.fromLTWH((size.width - side) / 2, (size.height - side) / 2,
            side, side),
        art);
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.art != art;
}

// ================================================================ test sheet
/// Look-alike of the Google Play purchase sheet, used only in test mode.
/// Tapping outside closes it (returns null), like the real one.
Future<bool?> showTestPaymentSheet(
  BuildContext context, {
  required String planTitle,
  required String price,
  String? reason,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: const Color(0xFF202124),
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.play_arrow_rounded,
                  color: Color(0xFF34A853), size: 22),
              const SizedBox(width: 4),
              Text('Google Play',
                  style: nunito(14,
                      weight: FontWeight.w600, color: const Color(0xFFE8EAED))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9AB00),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('TEST MODE',
                    style: nunito(10,
                        weight: FontWeight.w900, color: Colors.black)),
              ),
            ]),
            const SizedBox(height: 18),
            Text('${AppConfig.appName} Premium ($planTitle)',
                style: nunito(18,
                    weight: FontWeight.w700, color: const Color(0xFFE8EAED))),
            const SizedBox(height: 4),
            Text(price,
                style: nunito(15,
                    weight: FontWeight.w600, color: const Color(0xFFBDC1C6))),
            const SizedBox(height: 14),
            Text(
                'This is a test sheet — no money is charged. The real Google '
                'Play payment sheet opens when the app is installed from '
                'Google Play and the subscriptions exist in Play Console.',
                style: nunito(12,
                    weight: FontWeight.w500, color: const Color(0xFF9AA0A6))),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason,
                  style: nunito(11,
                      weight: FontWeight.w500, color: const Color(0xFFF28B82))),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8AB4F8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Subscribe (test)',
                    style: nunito(15,
                        weight: FontWeight.w700,
                        color: const Color(0xFF202124))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
