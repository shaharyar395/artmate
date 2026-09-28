import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/trace_catalog.dart';
import '../widgets/common.dart';
import '../widgets/trace_item_art.dart';
import 'battle/select_room_screen.dart' show BattleHeader;
import 'trace_canvas_screen.dart';
import 'trace_result_screen.dart';

/// Trace Art > Preview: big picture, short loading, then "Draw Now".
class TracePreviewScreen extends StatefulWidget {
  const TracePreviewScreen({super.key, required this.item});
  final TraceItem item;

  @override
  State<TracePreviewScreen> createState() => _TracePreviewScreenState();
}

class _TracePreviewScreenState extends State<TracePreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late final AnimationController _shimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _drawNow() async {
    final result = await Navigator.of(context)
        .push<Object?>(fadeRoute(TraceCanvasScreen(item: widget.item)));
    if (!mounted) return;
    if (result is TraceResult) {
      // Finished: show the result page in place of the preview.
      Navigator.of(context)
          .pushReplacement(fadeRoute(TraceResultScreen(result: result)));
    } else if (result == true) {
      Navigator.of(context).pop(); // "Quit" goes back to the list
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: Column(
          children: [
            BattleHeader(title: tr(context, 'preview')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.item.isNeon
                        ? const Color(0xFF0B0B0F)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFDCE6EC),
                          offset: Offset(0, 4),
                          blurRadius: 4),
                    ],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Center(
                      child: TraceItemArt(item: widget.item, size: 200)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loading
                  ? _Skeleton(key: const ValueKey('sk'), anim: _shimmer)
                  : Padding(
                      key: const ValueKey('btn'),
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Pressable(
                        onTap: _drawNow,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1673FF),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(tr(context, 'drawNow'),
                              style: nunito(19,
                                  weight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.anim});
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final c = Color.lerp(
            const Color(0xFFE6E9EC), const Color(0xFFF3F5F7), anim.value)!;
        Widget bar(double w, double h) => Container(
              width: w,
              height: h,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(6)),
            );
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  bar(40, 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(double.infinity, 10), bar(120, 10)],
                    ),
                  ),
                ],
              ),
              bar(double.infinity, 36),
            ],
          ),
        );
      },
    );
  }
}
