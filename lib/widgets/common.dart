import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_state.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../core/theme.dart';

/// Shows `assets/images/<asset>` if you added it, otherwise [fallback].
class ArtSlot extends StatelessWidget {
  const ArtSlot(
      {super.key,
      required this.asset,
      required this.fallback,
      this.fit = BoxFit.contain});

  final String asset;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/$asset',
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// Emoji rendered at a fixed size (placeholder art).
class Emoji extends StatelessWidget {
  const Emoji(this.char, {super.key, this.size = 40});
  final String char;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(char, style: TextStyle(fontSize: size, height: 1.1));
}

/// Text with a thick outline — used for "Profile", "Setting", banners, etc.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 30,
    this.fill = Colors.white,
    this.stroke = const Color(0xFF1C4EA0),
    this.strokeWidth = 5,
    this.height,
    this.align = TextAlign.left,
  });

  final String text;
  final double size;
  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final double? height;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Text(text,
          textAlign: align,
          style: GoogleFonts.lilitaOne(
            fontSize: size,
            height: height,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          )),
      Text(text,
          textAlign: align,
          style: GoogleFonts.lilitaOne(
              fontSize: size, height: height, color: fill)),
    ]);
  }
}

/// Big blue "Continue" button with the darker 3-D bottom edge.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.enabled = true});

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final face = enabled ? AppColors.blue : AppColors.disabled;
    final edge = enabled ? AppColors.blueDark : AppColors.disabledDark;
    return GestureDetector(
      onTap: enabled
          ? () {
              AppScope.read(context).tap();
              onPressed();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: edge,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: nunito(19,
                  weight: FontWeight.w700,
                  color: enabled ? Colors.white : AppColors.textSoft)),
        ),
      ),
    );
  }
}

/// Round black back button used on Profile / Setting.
class BackCircle extends StatelessWidget {
  const BackCircle({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppScope.read(context).tap(Sfx.back);
        (onTap ?? () => Navigator.of(context).maybePop())();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A), shape: BoxShape.circle),
        child: const Icon(Icons.arrow_back_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }
}

/// Blue circular check badge / empty radio circle.
class SelectMark extends StatelessWidget {
  const SelectMark({super.key, required this.selected, this.size = 28});
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.selectBlue : Colors.white,
        border: Border.all(
            color: selected ? Colors.white : AppColors.radio,
            width: selected ? 2.5 : 2),
      ),
      child: selected
          ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.66)
          : null,
    );
  }
}

/// Flag rendered from an emoji inside a small rounded rectangle.
class FlagBox extends StatelessWidget {
  const FlagBox(this.flag, {super.key, this.width = 54, this.height = 38});
  final String flag;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: Text(flag, style: const TextStyle(fontSize: 60, height: 1)),
        ),
      ),
    );
  }
}

/// Soft pastel brush strokes behind the onboarding screens / splash.
class BrushBackground extends StatelessWidget {
  const BrushBackground(
      {super.key, required this.child, this.base = Colors.white, this.dark = false});
  final Widget child;
  final Color base;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // Always fill the whole screen, whatever size the content is.
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: base,
      child: CustomPaint(
        painter: _BrushPainter(dark: dark),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _BrushPainter extends CustomPainter {
  _BrushPainter({required this.dark});
  final bool dark;

  void _stroke(Canvas c, Size s, double x, double y, double w, double h,
      double angle, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    c.save();
    c.translate(s.width * x, s.height * y);
    c.rotate(angle);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: s.width * w, height: s.height * h),
            const Radius.circular(80)),
        paint);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (dark) {
      final c = Colors.white.withOpacity(0.07);
      _stroke(canvas, size, 0.15, 0.25, 0.9, 0.08, -0.5, c);
      _stroke(canvas, size, 0.85, 0.55, 0.9, 0.07, -0.6, c);
      _stroke(canvas, size, 0.35, 0.85, 1.0, 0.09, -0.4, c);
    } else {
      _stroke(canvas, size, 0.1, 0.22, 0.7, 0.12, -0.7,
          const Color(0xFF8FE3EE).withOpacity(0.18));
      _stroke(canvas, size, 0.9, 0.62, 0.55, 0.10, -1.0,
          const Color(0xFFFFE680).withOpacity(0.22));
      _stroke(canvas, size, 0.75, 0.9, 0.7, 0.10, -0.8,
          const Color(0xFFFFE680).withOpacity(0.18));
    }
  }

  @override
  bool shouldRepaint(covariant _BrushPainter old) => old.dark != dark;
}

/// 3-segment onboarding progress bar.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.total = 3});
  final int step; // 1-based
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
            height: 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                  begin: i < step - 1 ? 1.0 : 0.0,
                  end: i < step ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE2E4E8),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.progress),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Shared layout for the 4 onboarding screens.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.canContinue,
    required this.onContinue,
    this.step,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool canContinue;
  final VoidCallback onContinue;
  final int? step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrushBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: StepProgress(step: step!),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, step != null ? 22 : 18, 20, 0),
                child: Text(title, style: nunito(26, weight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(subtitle,
                    style: nunito(16,
                        weight: FontWeight.w500, color: AppColors.sub)),
              ),
              Expanded(child: child),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: PrimaryButton(
                  label: tr(context, 'continue'),
                  enabled: canContinue,
                  onPressed: onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fade + slight upward slide page route (matches the app's transitions).
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Slide in from the right (used when opening a game mode from the lobby).
Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(tr(context, 'comingSoon')),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
}

/// Simple scale-down on press.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, required this.onTap, this.pressedScale = 0.97});
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        AppScope.read(context).tap();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
