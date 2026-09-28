import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'lobby_screen.dart';
import 'onboarding/language_select_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppConfig.splashDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      })
      ..forward();
  }

  void _next() {
    if (!mounted) return;
    final state = AppScope.read(context);
    Navigator.of(context).pushReplacement(fadeRoute(
        state.onboarded ? const LobbyScreen() : const LanguageSelectScreen()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.splashBlue,
        body: BrushBackground(
          base: AppColors.splashBlue,
          dark: true,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // App icon
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const ArtSlot(
                    asset: 'app_logo.png',
                    fallback: Center(child: Emoji('🎨', size: 62)),
                  ),
                ),
                const SizedBox(height: 26),
                // Two-tone wordmark
                const ArtSlot(
                  asset: 'wordmark.png',
                  fallback: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedText(AppConfig.wordmarkPart1,
                          size: 48, strokeWidth: 8),
                      OutlinedText(AppConfig.wordmarkPart2,
                          size: 48,
                          strokeWidth: 8,
                          fill: Color(0xFFFFD43B)),
                    ],
                  ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(tr(context, 'tagline'),
                    style: nunito(21,
                        weight: FontWeight.w900, color: Colors.white)),
                const Spacer(flex: 5),
                // Loading bar
                SizedBox(
                  width: 232,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: Curves.easeInOut.transform(_c.value),
                        minHeight: 5,
                        backgroundColor: Colors.white.withOpacity(0.45),
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(tr(context, 'loading'),
                    style: nunito(16,
                        weight: FontWeight.w700, color: Colors.white)),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
