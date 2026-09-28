import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'battle_template_screen.dart';

/// Art Battle > "Select Room": 4 Players or 2 Players.
class SelectRoomScreen extends StatelessWidget {
  const SelectRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: Column(
          children: [
            BattleHeader(title: tr(context, 'selectRoom')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _RoomCard(
                    color: const Color(0xFFFBE8B1),
                    edge: const Color(0xFFE6CD86),
                    icon: const _QuadIcon(),
                    label: tr(context, 'players4'),
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const BattleTemplateScreen(size: 4))),
                  ),
                  const SizedBox(height: 18),
                  _RoomCard(
                    color: const Color(0xFFD7F7CF),
                    edge: const Color(0xFFB4E2A7),
                    icon: const _DuoIcon(),
                    label: tr(context, 'players2'),
                    onTap: () => Navigator.of(context)
                        .push(slideRoute(const BattleTemplateScreen(size: 2))),
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

/// Back button + blue outlined title, shared by the Art Battle screens.
class BattleHeader extends StatelessWidget {
  const BattleHeader({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          BackCircle(onTap: onBack),
          Expanded(
            child: Center(
              heightFactor: 1,
              child: OutlinedText(title,
                  size: 30,
                  fill: AppColors.titleBlue,
                  stroke: Colors.white,
                  strokeWidth: 5),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.color,
    required this.edge,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final Color edge;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 22),
            Text(label, style: display(28, color: const Color(0xFF222222))),
          ],
        ),
      ),
    );
  }
}

class _QuadIcon extends StatelessWidget {
  const _QuadIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Expanded(
            child: Row(children: [
              Expanded(child: Center(child: Emoji('💗', size: 28))),
              Expanded(child: Center(child: Emoji('🌙', size: 28))),
            ]),
          ),
          Expanded(
            child: Row(children: [
              Expanded(child: Center(child: Emoji('⭐', size: 28))),
              Expanded(child: Center(child: Emoji('👻', size: 28))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DuoIcon extends StatelessWidget {
  const _DuoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: DiagonalPainter(),
        child: const Stack(
          children: [
            Positioned(left: 8, top: 6, child: Emoji('👻', size: 30)),
            Positioned(right: 8, bottom: 6, child: Emoji('⭐', size: 30)),
          ],
        ),
      ),
    );
  }
}

/// Thin diagonal line (bottom-left to top-right) used on 2-player cards.
class DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
        Offset(size.width * 0.06, size.height * 0.94),
        Offset(size.width * 0.94, size.height * 0.06),
        Paint()
          ..color = const Color(0xFFE3E6EA)
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
