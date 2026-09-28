import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'draw_together_screen.dart';
import 'battle/select_room_screen.dart';
import 'buddies_screen.dart';
import 'premium_screen.dart';
import 'profile_screen.dart';
import 'trace_art_screen.dart';

/// Home / lobby: profile pill, gift button, Premium, and the 3 mode banners.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void initState() {
    super.initState();
    // Background music begins when the Lobby shows.
    Sound.instance.startMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
  }

  Future<void> _askNotifications() async {
    final s = AppScope.read(context);
    if (s.askedNotifications) return;
    s.markAskedNotifications();
    await Future.delayed(const Duration(milliseconds: 600));
    await Permission.notification.request();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 12) return 'goodMorning';
    if (h < 18) return 'goodAfternoon';
    return 'goodEvening';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.lobbyBg,
      body: SafeArea(
        child: Column(
          children: [
            // ------------------------------------------------ top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context)
                        .push(fadeRoute(const ProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Emoji(kAvatars[s.avatarIndex % kAvatars.length],
                              size: 34),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(context, _greetingKey()),
                                  style: nunito(12,
                                      weight: FontWeight.w500,
                                      color: AppColors.sub)),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 110),
                                child: Text(s.username,
                                    overflow: TextOverflow.ellipsis,
                                    style: nunito(15,
                                        weight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.selectBlue, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Rotating gift / event button
                  Pressable(
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const BuddiesScreen())),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2D8BFF), Color(0xFF1360E0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: RotationTransition(
                        turns: _spin,
                        child: const ArtSlot(
                          asset: 'lobby_event.png',
                          fallback: Emoji('⭐', size: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Premium
                  Pressable(
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const PremiumScreen())),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.premiumA, AppColors.premiumB],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                            color: const Color(0xFFFFD27A), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                                color: Color(0xFFFFE9B8),
                                shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Emoji('👑', size: 17),
                          ),
                          const SizedBox(width: 8),
                          Text(tr(context, 'premium'),
                              style: nunito(18,
                                  weight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ------------------------------------------------ banners
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _ModeBanner(
                    asset: 'banner_draw_together.png',
                    title: 'DRAW\nTOGETHER',
                    colors: const [Color(0xFFFFE03A), Color(0xFFFFC928)],
                    border: const Color(0xFFFF6AD5),
                    live: true,
                    showDrawNow: true,
                    art: const _EmojiCluster(['🐈‍⬛', '🐱', '✏️']),
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const DrawTogetherScreen())),
                  ),
                  const SizedBox(height: 18),
                  _ModeBanner(
                    asset: 'banner_trace_art.png',
                    title: 'TRACE\nART',
                    colors: const [Color(0xFF63D3FF), Color(0xFFA6ECFF)],
                    border: const Color(0xFF9FDFFF),
                    art: const _EmojiCluster(['🌿', '🐶', '✏️']),
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const TraceArtScreen())),
                  ),
                  const SizedBox(height: 18),
                  _ModeBanner(
                    asset: 'banner_art_battle.png',
                    title: 'ART\nBATTLE',
                    colors: const [Color(0xFFC6F78F), Color(0xFFA5EE68)],
                    border: const Color(0xFF7FDD5E),
                    art: const _BattleArt(),
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const SelectRoomScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    required this.asset,
    required this.title,
    required this.colors,
    required this.border,
    required this.art,
    required this.onTap,
    this.live = false,
    this.showDrawNow = false,
  });

  final String asset;
  final String title;
  final List<Color> colors;
  final Color border;
  final Widget art;
  final VoidCallback onTap;
  final bool live;
  final bool showDrawNow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 4),
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: border.withOpacity(0.55),
                offset: const Offset(0, 5),
                blurRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ArtSlot(
            asset: asset,
            fit: BoxFit.cover,
            fallback: Stack(
              children: [
                Positioned(right: 8, top: 10, bottom: 6, child: art),
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedText(title,
                          size: 30,
                          height: 0.95,
                          strokeWidth: 6,
                          stroke: const Color(0xFF1D4FA6)),
                      if (showDrawNow) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F80E6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFBFE0FF), width: 1.5),
                          ),
                          child: Text('DRAW NOW',
                              style: display(17, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (live)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4C2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text('LIVE',
                              style: display(15,
                                  color: const Color(0xFFFF3B30))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiCluster extends StatelessWidget {
  const _EmojiCluster(this.emojis);
  final List<String> emojis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, bottom: 0, child: Emoji(emojis[0], size: 56)),
          Positioned(right: 30, bottom: 4, child: Emoji(emojis[1], size: 76)),
          Positioned(right: 0, top: 18, child: Emoji(emojis[2], size: 40)),
        ],
      ),
    );
  }
}

/// Placeholder Art Battle art: 3 cards + 2/1/3 podium.
class _BattleArt extends StatelessWidget {
  const _BattleArt();

  Widget _card(String e, double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 46,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 3)
            ],
          ),
          alignment: Alignment.center,
          child: Emoji(e, size: 28),
        ),
      );

  Widget _step(String n, double h, Color c) => Container(
        width: 42,
        height: h,
        color: c,
        alignment: Alignment.center,
        child: OutlinedText(n,
            size: 22, strokeWidth: 4, stroke: const Color(0xFF1D4FA6)),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _card('🥝', -0.15),
              const SizedBox(width: 2),
              _card('💧', 0),
              const SizedBox(width: 2),
              _card('🔥', 0.15),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _step('2', 34, const Color(0xFF4FC3F7)),
              _step('1', 46, const Color(0xFFFFD43B)),
              _step('3', 26, const Color(0xFFE8A15A)),
            ],
          ),
        ],
      ),
    );
  }
}
