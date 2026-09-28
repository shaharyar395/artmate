import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';

/// Praise shown after each finished step (and at the end).
class Praise {
  const Praise(this.text, this.icon, this.fill, this.ribbon);
  final String text;
  final String icon;
  final Color fill; // text colour
  final Color ribbon; // banner colour
}

const List<Praise> kStepPraise = [
  Praise('NICE START', '🏅', Colors.white, Color(0xFFF0476A)),
  Praise('LOOKING GOOD', '📜', Color(0xFFFF4D6D), Color(0xFFFFB347)),
  Praise('OUTSTANDING', '🏆', Color(0xFFFF7A00), Colors.white),
  Praise('GREAT WORK', '🚩', Colors.white, Color(0xFFE39B1A)),
  Praise('AMAZING', '🌈', Colors.white, Color(0xFFFF3B6B)),
  Praise('AWESOME', '⭐', Colors.white, Color(0xFF7C4DFF)),
  Praise('SUPER', '🚀', Colors.white, Color(0xFF00B8D4)),
  Praise('WELL DONE', '🎉', Colors.white, Color(0xFF34C759)),
  Praise('FANTASTIC', '💎', Colors.white, Color(0xFF3A8EF0)),
  Praise('BRILLIANT', '✨', Color(0xFFFF7A00), Color(0xFFFFE066)),
];

const Praise kFinalPraise =
    Praise('PERFECT!', '👑', Colors.white, Color(0xFFFF9500));

/// Dark overlay with spinning rays, confetti and a sticker that pops in.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.praise});
  final Praise praise;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..forward();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _pop, curve: const Interval(0, 0.3));
  late final Animation<double> _bounce =
      CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
  final List<_Bit> _bits = List.generate(26, (i) => _Bit(math.Random(i * 31)));

  @override
  void dispose() {
    _pop.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.praise;
    return IgnorePointer(
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withOpacity(0.62),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rays
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) => CustomPaint(
                      painter: _RaysPainter(_spin.value * 2 * math.pi)),
                ),
              ),
              // Confetti
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (_, __) =>
                      CustomPaint(painter: _ConfettiPainter(_bits, _pop.value)),
                ),
              ),
              // Sticker
              ScaleTransition(
                scale: _bounce,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: p.ribbon.withOpacity(0.6),
                              blurRadius: 24,
                              spreadRadius: 4),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Emoji(p.icon, size: 78),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Transform.rotate(
                        angle: -0.1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 8),
                          decoration: BoxDecoration(
                            color: p.ribbon,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x55000000),
                                  offset: Offset(0, 4),
                                  blurRadius: 6),
                            ],
                          ),
                          child: OutlinedText(p.text,
                              size: 36,
                              fill: p.fill,
                              stroke: const Color(0xFF3A1A2A),
                              strokeWidth: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final paint = Paint()..color = Colors.white.withOpacity(0.06);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = angle + i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a))
        ..lineTo(c.dx + r * math.cos(a + math.pi / n),
            c.dy + r * math.sin(a + math.pi / n))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.angle != angle;
}

class _Bit {
  _Bit(math.Random r)
      : angle = r.nextDouble() * 2 * math.pi,
        dist = 90 + r.nextDouble() * 110,
        size = 3 + r.nextDouble() * 5,
        color = const [
          Color(0xFFFF4D6D),
          Color(0xFFFFD60A),
          Color(0xFF00E5FF),
          Color(0xFF69F0AE),
          Color(0xFFB388FF),
        ][r.nextInt(5)];
  final double angle;
  final double dist;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = Curves.easeOut.transform(t);
    for (final b in bits) {
      final p = c +
          Offset(math.cos(b.angle), math.sin(b.angle)) * (b.dist * e) +
          Offset(0, 30 * t * t);
      canvas.drawCircle(p, b.size * (1 - 0.3 * t), Paint()..color = b.color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
