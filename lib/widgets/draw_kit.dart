import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_data.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'common.dart';

/// Shared drawing-screen parts (toolbar buttons, brush slider, colour bar,
/// leave dialog, canvas painter), styled like the reference app.

const Color kDrawTopBg = Color(0xFFE8E8E8);
const Color kDrawBottomBg = Color(0xFFE9E9E9);
const Color kGuideGrey = Color(0xFF7E7E7E);

const List<Color> kDrawColors = [
  Color(0xFF000000),
  Color(0xFFFF1E1E),
  Color(0xFF22C55E),
  Color(0xFF5B5BF0),
  Color(0xFFFFA000),
  Color(0xFF800080),
  Color(0xFFFFB6C1),
  Color(0xFF00E5FF),
  Color(0xFFFFD000),
  Color(0xFFB8860B),
  Color(0xFF8D5A3B),
  Color(0xFF9E9E9E),
  Color(0xFFFFFFFF),
];

class DrawSquareBtn extends StatelessWidget {
  const DrawSquareBtn({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppScope.read(context).tap();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 30, color: const Color(0xFF222222)),
      ),
    );
  }
}

class DrawCircleBtn extends StatelessWidget {
  const DrawCircleBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.outlined = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              AppScope.read(context).tap();
              onTap();
            }
          : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: outlined || enabled
              ? Border.all(
                  color: const Color(0xFF3A3A3A), width: outlined ? 1.6 : 1.2)
              : null,
        ),
        child: Icon(icon,
            size: 24,
            color: enabled ? const Color(0xFF2A2A2A) : const Color(0xFFD2D2D2)),
      ),
    );
  }
}

class DrawNextBtn extends StatelessWidget {
  const DrawNextBtn({super.key, required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 80,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.blue : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: enabled ? AppColors.blueDark : const Color(0xFFBDBDBD),
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(Icons.arrow_forward_rounded,
            size: 28,
            color: enabled ? Colors.white : const Color(0xFF7A7A7A)),
      ),
    );
  }
}

/// White pill progress track with the "n/9" badge.
class DrawProgress extends StatelessWidget {
  const DrawProgress({super.key, required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final shown = (done + (done >= total ? 0 : 1)).clamp(1, total);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (_, c) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: c.maxWidth * (done / total).clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF7DD3FC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3A3A3A), width: 1.2),
          ),
          child: Text('$shown/$total',
              style: nunito(17, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Tapered light-blue brush-size slider with a white handle.
class BrushSizeSlider extends StatelessWidget {
  const BrushSizeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.006,
    this.max = 0.06,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 34,
      child: LayoutBuilder(builder: (context, c) {
        const pad = 12.0;
        final w = c.maxWidth - pad * 2;
        final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
        void update(double dx) {
          final nt = ((dx - pad) / w).clamp(0.0, 1.0);
          onChanged(min + (max - min) * nt);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          child: CustomPaint(
            painter: _WedgePainter(),
            child: Stack(
              children: [
                Positioned(
                  left: pad + w * t - 7,
                  top: 3,
                  child: Container(
                    width: 14,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: const Color(0xFF7DC4E4), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WedgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(12, cy - 1.5)
      ..lineTo(size.width - 12, cy - 9)
      ..quadraticBezierTo(size.width - 6, cy, size.width - 12, cy + 9)
      ..lineTo(12, cy + 1.5)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFBFE6F7));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF7DC4E4)
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom white pill: eraser, brush, rainbow picker | scrolling colours.
class DrawColorBar extends StatelessWidget {
  const DrawColorBar({
    super.key,
    required this.color,
    required this.eraser,
    required this.colors,
    required this.onEraser,
    required this.onBrush,
    required this.onColor,
    required this.onPicker,
  });

  final Color color;
  final bool eraser;
  final List<Color> colors;
  final VoidCallback onEraser;
  final VoidCallback onBrush;
  final ValueChanged<Color> onColor;
  final VoidCallback onPicker;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.only(left: 12, right: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEraser,
            child: SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(painter: _EraserPainter(active: eraser)),
            ),
          ),
          GestureDetector(
            onTap: onBrush,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.brush_rounded,
                  size: 30,
                  color: eraser
                      ? const Color(0xFF9A9A9A)
                      : const Color(0xFF3D8BF2)),
            ),
          ),
          GestureDetector(
            onTap: onPicker,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ]),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.contains(color) ? const Color(0xFFFFC400) : color,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFFE0E0E0),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in colors)
                  GestureDetector(
                    onTap: () => onColor(c),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: !eraser && c == color ? 46 : 40,
                        height: !eraser && c == color ? 46 : 40,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: !eraser && c == color
                                  ? const Color(0xFF8E8E8E)
                                  : (c == Colors.white || c.value == 0xFFFFFFFF
                                      ? const Color(0xFFDADADA)
                                      : Colors.transparent),
                              width: !eraser && c == color ? 3.5 : 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EraserPainter extends CustomPainter {
  _EraserPainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4);
    const w = 28.0, h = 15.0;
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        const Radius.circular(3));
    final main = active ? const Color(0xFF3D8BF2) : const Color(0xFF8E8E8E);
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    // Filled tip (right half)
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -h / 2, w / 2, h));
    canvas.drawRRect(rect, Paint()..color = main);
    canvas.restore();
    canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = main);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserPainter old) => old.active != active;
}

/// Colour picker sheet opened from the rainbow button.
Future<Color?> showColorPicker(BuildContext context, Color current) {
  final swatches = <Color>[
    for (var l in const [0.85, 0.7, 0.55, 0.4, 0.25])
      for (var h = 0; h < 360; h += 30)
        HSLColor.fromAHSL(1, h.toDouble(), 0.85, l).toColor(),
    for (var g = 0; g <= 11; g++)
      Color.lerp(Colors.white, Colors.black, g / 11)!,
  ];
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: GridView.count(
          crossAxisCount: 12,
          shrinkWrap: true,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in swatches)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: c.value == current.value
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFE0E0E0),
                        width: c.value == current.value ? 3 : 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// "Do you want to leave?" — returns true when the player taps Quit.
Future<bool> showLeaveDialog(BuildContext context) async {
  final quit = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Emoji('🚪', size: 64),
            const SizedBox(height: 10),
            Text(tr(context, 'leaveTitle'),
                style: nunito(19, weight: FontWeight.w800)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3A8EF0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(context, 'stillDrawing'),
                    style: nunito(17,
                        weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE5484D), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr(context, 'quit'),
                    style: nunito(17,
                        weight: FontWeight.w600,
                        color: const Color(0xFFE5484D))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return quit == true;
}

/// Paints the (blinking) grey guide line and the player's strokes inside a
/// square of [side] placed at [offset].
class GuideCanvasPainter extends CustomPainter {
  GuideCanvasPainter({
    required this.offset,
    required this.side,
    required this.guide,
    required this.guideOpacity,
    required this.strokes,
  });

  final Offset offset;
  final double side;
  final List<Offset>? guide;
  final double guideOpacity;
  final List<BStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final g = guide;
    if (g != null && g.length > 1) {
      final path = Path()..moveTo(g.first.dx * side, g.first.dy * side);
      for (final p in g.skip(1)) {
        path.lineTo(p.dx * side, p.dy * side);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = kGuideGrey.withOpacity(guideOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(3, side * 0.011)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
    paintStrokes(canvas, side, strokes);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =====================================================================
// ≡ menu: Sound / Exit Drawing
// =====================================================================

enum DrawMenuAction { sound, exit }

/// Drop-down card anchored over the ≡ button (identified by [anchorKey]).
Future<DrawMenuAction?> showDrawMenu(
    BuildContext context, GlobalKey anchorKey) {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final pos = box?.localToGlobal(Offset.zero) ?? const Offset(14, 40);
  return showGeneralDialog<DrawMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) {
      final soundOn = AppScope.of(ctx).soundFx;
      Widget row(Widget icon, String label, DrawMenuAction a) => InkWell(
            onTap: () => Navigator.pop(ctx, a),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 30, height: 26, child: icon),
                  const SizedBox(width: 12),
                  Text(label, style: nunito(18, weight: FontWeight.w700)),
                ],
              ),
            ),
          );
      return Stack(
        children: [
          Positioned(
            left: pos.dx - 6,
            top: pos.dy - 4,
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    row(CustomPaint(painter: SpeakerPainter(on: soundOn)),
                        tr(ctx, 'sound'), DrawMenuAction.sound),
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 18,
                        endIndent: 18,
                        color: Color(0xFFDDDDDD)),
                    row(
                        Transform.flip(
                          flipX: true,
                          child: const Icon(Icons.logout_rounded,
                              color: Color(0xFFF03A3A), size: 28),
                        ),
                        tr(ctx, 'exitDrawing'),
                        DrawMenuAction.exit),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        alignment: Alignment.topLeft,
        scale: Tween<double>(begin: 0.9, end: 1).animate(anim),
        child: child,
      ),
    ),
  );
}

/// Green speaker with blue sound waves (on) or a red × (off).
class SpeakerPainter extends CustomPainter {
  SpeakerPainter({required this.on});
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final green = Paint()..color = const Color(0xFF1FC27E);
    // speaker body + cone
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.34, h * 0.26, h * 0.32),
          const Radius.circular(2)))
      ..moveTo(h * 0.22, h * 0.34)
      ..lineTo(h * 0.56, h * 0.08)
      ..lineTo(h * 0.56, h * 0.92)
      ..lineTo(h * 0.22, h * 0.66)
      ..close();
    canvas.drawPath(body, green);

    if (on) {
      final wave = Paint()
        ..color = const Color(0xFF5B8DEF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final c = Offset(h * 0.56, h / 2);
      canvas.drawArc(Rect.fromCircle(center: c, radius: h * 0.24), -0.9, 1.8,
          false, wave);
      canvas.drawArc(Rect.fromCircle(center: c, radius: h * 0.44), -0.9, 1.8,
          false, wave);
    } else {
      final x = Paint()
        ..color = const Color(0xFFF05A5A)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final cx = h * 0.86, cy = h / 2, r = h * 0.13;
      canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), x);
      canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), x);
    }
  }

  @override
  bool shouldRepaint(covariant SpeakerPainter old) => old.on != on;
}

/// "Clear This Step" confirmation (broom button). True when Clear is tapped;
/// tapping outside or × keeps the drawing.
Future<bool> showClearStepDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Emoji('🧹', size: 64),
                const SizedBox(height: 12),
                Text(tr(context, 'clearStepTitle'),
                    style: nunito(17, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(tr(context, 'clearStepSub'),
                    textAlign: TextAlign.center,
                    style: nunito(13,
                        weight: FontWeight.w500, color: AppColors.sub)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3A8EF0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr(context, 'clearWord'),
                        style: nunito(17,
                            weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              iconSize: 20,
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF8A8A8A)),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
