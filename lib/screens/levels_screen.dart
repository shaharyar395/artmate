import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/levels.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// "Your Level" map: 12 badges on a winding dashed path.
/// A badge unlocks when the player's lessons >= its requirement.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

/// Rows of the map: 1 centre badge, then 2 side-by-side, repeating.
const List<List<int>> _rows = [
  [0], [1, 2], [3], [4, 5], [6], [7, 8], [9], [10, 11]
];

const Color _bg = Color(0xFFFBEDAD);
const Color _strip = Color(0xFFF8E07E);
const Color _labelPurple = Color(0xFF6A1FC9);

class _LevelsScreenState extends State<LevelsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  bool _didScroll = false;

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onBadgeTap(int i, bool unlocked) {
    final lv = kLevels[i];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        content: Text(unlocked
            ? '${tr(context, lv.key)} · ${tr(context, 'levelUnlocked')}'
            : tr(context, 'unlockHint', {'n': '${lv.lessons}'})),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final current = currentLevelIndex(s.lessons);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ------------------------------------------------ scrolling map
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final g = _MapGeometry(w, topInset + 110);

            // Scroll so the current level is visible on open.
            if (!_didScroll && current > 0) {
              _didScroll = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scroll.hasClients) return;
                final target = (g.center(current).dy - c.maxHeight / 2)
                    .clamp(0.0, _scroll.position.maxScrollExtent)
                    .toDouble();
                _scroll.animateTo(target,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic);
              });
            }

            return SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                width: w,
                height: g.totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _MapPainter(g)),
                    ),
                    ..._decorations(g),
                    for (var i = 0; i < kLevels.length; i++)
                      _badgeAt(g, i, s.lessons >= kLevels[i].lessons,
                          i == current, s.avatarIndex),
                  ],
                ),
              ),
            );
          }),
          // ------------------------------------------------ floating header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const BackCircle(),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: OutlinedText(tr(context, 'yourLevel'),
                          size: 32,
                          fill: AppColors.titleBlue,
                          stroke: Colors.white,
                          strokeWidth: 5),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeAt(
      _MapGeometry g, int i, bool unlocked, bool isCurrent, int avatar) {
    final c = g.center(i);
    final d = g.badge;
    final lv = kLevels[i];
    final labelW = d * 1.2;
    return Positioned(
      left: c.dx - labelW / 2,
      top: c.dy - d / 2,
      width: labelW,
      child: GestureDetector(
        onTap: () {
          AppScope.read(context).tap();
          _onBadgeTap(i, unlocked);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: d,
              height: d,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isCurrent)
                    Positioned.fill(
                      child: ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.07).animate(
                            CurvedAnimation(
                                parent: _pulse, curve: Curves.easeInOut)),
                        child: _LevelBadge(
                            level: lv, index: i, unlocked: unlocked, size: d),
                      ),
                    )
                  else
                    _LevelBadge(
                        level: lv, index: i, unlocked: unlocked, size: d),
                  if (isCurrent)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        width: d * 0.36,
                        height: d * 0.36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.selectBlue, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Emoji(kAvatars[avatar % kAvatars.length],
                            size: d * 0.2),
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, -d * 0.16),
              child: Container(
                width: labelW,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrent
                      ? Border.all(color: AppColors.selectBlue, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tr(context, lv.key),
                          style: nunito(16,
                              weight: FontWeight.w800, color: _labelPurple)),
                    ),
                    Text(tr(context, 'lessonsNeeded', {'n': '${lv.lessons}'}),
                        style: nunito(13,
                            weight: FontWeight.w500, color: AppColors.text)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scenery that repeats down the map (swap for PNGs later if you like).
  List<Widget> _decorations(_MapGeometry g) {
    final out = <Widget>[];
    for (var r = 0; r < _rows.length; r += 4) {
      final y0 = g.rowY(r);
      out.addAll([
        Positioned(
            left: g.w * 0.13,
            top: y0 - 10,
            child: const Emoji('🗻', size: 48)),
        Positioned(
            left: g.w * 0.45,
            top: y0 + g.rowH * 0.55,
            child: const Emoji('🍀', size: 26)),
        Positioned(
            right: g.w * 0.08,
            top: y0 + g.rowH * 0.5,
            child: const Emoji('🌿', size: 36)),
        Positioned(
            left: g.w * 0.3,
            top: g.rowY(r + 1) + g.badge * 0.1,
            child: const Emoji('📮', size: 30)),
      ]);
    }
    return out;
  }
}

// ================================================================ geometry
class _MapGeometry {
  _MapGeometry(this.w, this.top)
      : badge = (w * 0.28).clamp(80.0, 130.0).toDouble(),
        rowH = (w * 0.47).clamp(150.0, 230.0).toDouble();

  final double w;
  final double top;
  final double badge;
  final double rowH;

  double rowY(int r) => top + r * rowH + badge / 2;

  double get totalHeight => rowY(_rows.length - 1) + badge + 80;

  Offset center(int levelIndex) {
    for (var r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      final pos = row.indexOf(levelIndex);
      if (pos < 0) continue;
      final x = row.length == 1 ? w * 0.5 : (pos == 0 ? w * 0.27 : w * 0.73);
      return Offset(x, rowY(r));
    }
    return Offset.zero;
  }

  int rowOf(int levelIndex) =>
      _rows.indexWhere((row) => row.contains(levelIndex));
}

// ================================================================ painter
class _MapPainter extends CustomPainter {
  _MapPainter(this.g);
  final _MapGeometry g;

  @override
  void paint(Canvas canvas, Size size) {
    // Soft yellow strips behind the scenery.
    final strip = Paint()..color = _strip.withOpacity(0.75);
    for (var r = 0; r < _rows.length; r++) {
      final y = g.rowY(r);
      final rr = r % 4;
      Rect rect;
      if (rr == 0) {
        rect = Rect.fromLTWH(g.w * 0.45, y - g.badge * 0.85, g.w * 0.6, 16);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), strip);
        rect = Rect.fromLTWH(-20, y + g.badge * 0.05, g.w * 0.5, 28);
      } else if (rr == 1) {
        rect = Rect.fromLTWH(g.w * 0.4, y - g.badge * 0.75, g.w * 0.7, 36);
      } else if (rr == 2) {
        rect = Rect.fromLTWH(-20, y - g.badge * 0.7, g.w * 0.45, 20);
      } else {
        rect = Rect.fromLTWH(g.w * 0.55, y + g.badge * 0.2, g.w * 0.5, 22);
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(14)), strip);
    }

    // Winding path through the levels, in order.
    final path = Path();
    final half = g.badge / 2;
    final edgeL = g.w * 0.035;
    final edgeR = g.w - edgeL;
    final rad = g.rowH * 0.32;
    for (var i = 0; i < kLevels.length - 1; i++) {
      final a = g.center(i);
      final b = g.center(i + 1);
      if (g.rowOf(i) == g.rowOf(i + 1)) {
        path.moveTo(a.dx + half, a.dy);
        path.lineTo(b.dx - half, b.dy);
      } else if (g.rowOf(i) % 2 == 0) {
        // centre -> left badge of next row, via the left edge
        path.moveTo(a.dx - half, a.dy);
        path.lineTo(edgeL + rad, a.dy);
        path.quadraticBezierTo(edgeL, a.dy, edgeL, a.dy + rad);
        path.lineTo(edgeL, b.dy - rad);
        path.quadraticBezierTo(edgeL, b.dy, edgeL + rad, b.dy);
        path.lineTo(b.dx - half, b.dy);
      } else {
        // right badge -> centre of next row, via the right edge
        path.moveTo(a.dx + half, a.dy);
        path.lineTo(edgeR - rad, a.dy);
        path.quadraticBezierTo(edgeR, a.dy, edgeR, a.dy + rad);
        path.lineTo(edgeR, b.dy - rad);
        path.quadraticBezierTo(edgeR, b.dy, edgeR - rad, b.dy);
        path.lineTo(b.dx + half, b.dy);
      }
    }
    // Tail off the last badge.
    final last = g.center(kLevels.length - 1);
    path.moveTo(last.dx + half, last.dy);
    path.lineTo(edgeR - rad, last.dy);
    path.quadraticBezierTo(edgeR, last.dy, edgeR, last.dy + rad);
    path.lineTo(edgeR, size.height);

    final dash = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final ui.PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 14), dash);
        d += 26;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.g.w != g.w || old.g.top != g.top;
}

// ================================================================ badge
class _LevelBadge extends StatelessWidget {
  const _LevelBadge(
      {required this.level,
      required this.index,
      required this.unlocked,
      required this.size});

  final Level level;
  final int index;
  final bool unlocked;
  final double size;

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final ring = unlocked ? level.colors[0] : const Color(0xFFB4AEBB);
    final drawn = CustomPaint(
      size: Size.square(size * 0.72),
      painter: _ShieldPainter(
        colors: unlocked
            ? level.colors
            : const [Color(0xFF7A7A7A), Color(0xFF555555)],
        star: unlocked ? const Color(0xFFFFD43B) : const Color(0xFF8E8E8E),
      ),
    );

    Widget art = ArtSlot(asset: 'level_${index + 1}.png', fallback: drawn);
    if (!unlocked) art = ColorFiltered(colorFilter: _grey, child: art);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        boxShadow: unlocked
            ? [
                BoxShadow(
                    color: level.colors[1].withOpacity(0.45),
                    blurRadius: 12,
                    spreadRadius: 1)
              ]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? [Colors.white, level.colors[0].withOpacity(0.6)]
                : const [Color(0xFF8C8C8C), Color(0xFF6A6A6A)],
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(width: size * 0.72, height: size * 0.72, child: art),
            if (!unlocked)
              Icon(Icons.lock_rounded,
                  size: size * 0.3, color: const Color(0xFFF2F2F2)),
          ],
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter({required this.colors, required this.star});
  final List<Color> colors;
  final Color star;

  Path _shield(double s, double inset) {
    final p = Path();
    final a = inset, b = s - inset;
    final w = b - a;
    p.moveTo(a + w * 0.5, a + w * 0.04);
    p.lineTo(a + w * 0.9, a + w * 0.2);
    p.lineTo(a + w * 0.86, a + w * 0.6);
    p.quadraticBezierTo(a + w * 0.82, a + w * 0.84, a + w * 0.5, a + w * 0.98);
    p.quadraticBezierTo(a + w * 0.18, a + w * 0.84, a + w * 0.14, a + w * 0.6);
    p.lineTo(a + w * 0.1, a + w * 0.2);
    p.close();
    return p;
  }

  Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final ang = -1.5708 + i * 0.6283;
      final pt = Offset(c.dx + rad * math.cos(ang), c.dy + rad * math.sin(ang));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final outer = _shield(s, 0);
    canvas.drawPath(
        outer,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        _shield(s, s * 0.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035
          ..color = Colors.white.withOpacity(0.35));
    canvas.drawPath(
        _star(Offset(s * 0.5, s * 0.5), s * 0.24), Paint()..color = star);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) =>
      old.colors != colors || old.star != star;
}
