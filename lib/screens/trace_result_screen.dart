import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'trace_canvas_screen.dart';
import 'trace_preview_screen.dart';

/// "Perfect Drawing" page shown after finishing a Trace Art picture.
class TraceResultScreen extends StatefulWidget {
  const TraceResultScreen({super.key, required this.result});
  final TraceResult result;

  @override
  State<TraceResultScreen> createState() => _TraceResultScreenState();
}

class _TraceResultScreenState extends State<TraceResultScreen> {
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _titleKey() {
    final p = widget.result.points;
    if (p >= 85) return 'perfectDrawing';
    if (p >= 65) return 'greatDrawing';
    return 'goodDrawing';
  }

  String _time() {
    final s = widget.result.seconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toast(String key, {bool ok = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.fromLTRB(60, 0, 60, 80),
        duration: const Duration(milliseconds: 1800),
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: ok ? AppColors.switchGreen : const Color(0xFFE5484D),
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr(context, key),
                  textAlign: TextAlign.center,
                  style: nunito(13,
                      weight: FontWeight.w600, color: AppColors.textSoft)),
            ),
          ],
        ),
      ));
  }

  Future<void> _save() async {
    if (_saving) return;
    AppScope.read(context).tap();
    setState(() => _saving = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(widget.result.png,
          album: AppConfig.appName,
          name: 'drawing_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) _toast('savedGallery');
    } catch (_) {
      if (mounted) _toast('saveFailed', ok: false);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _share() async {
    AppScope.read(context).tap();
    final box = context.findRenderObject() as RenderBox?;
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/my_drawing.png');
      await f.writeAsBytes(widget.result.png);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(f.path, mimeType: 'image/png')],
        text: tr(context, 'shareText', {'url': AppConfig.playStoreUrl}),
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) _toast('saveFailed', ok: false);
    }
  }

  void _drawAgain() {
    AppScope.read(context).tap();
    Navigator.of(context).pushReplacement(
        fadeRoute(TracePreviewScreen(item: widget.result.item)));
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final r = widget.result;
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            // ---------------------------------------- header
            Row(
              children: [
                const BackCircle(),
                Expanded(
                  child: Center(
                    heightFactor: 1,
                    child: OutlinedText(tr(context, _titleKey()),
                        size: 28,
                        fill: AppColors.titleBlue,
                        stroke: Colors.white,
                        strokeWidth: 5),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    AppScope.read(context).tap();
                    showTellUsDialog(context);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5A623),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.question_mark_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ---------------------------------------- stats
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.white,
                child: Row(
                  children: [
                    _Stat(
                        header: tr(context, 'point'),
                        color: const Color(0xFFFFC61A),
                        icon: Icons.stars_rounded,
                        iconColor: const Color(0xFFF5A623),
                        value: '${r.points}'),
                    _Stat(
                        header: tr(context, 'lines'),
                        color: const Color(0xFF3A8EF0),
                        icon: Icons.show_chart_rounded,
                        iconColor: const Color(0xFF3A8EF0),
                        value: '${r.lines}'),
                    _Stat(
                        header: tr(context, 'time'),
                        color: const Color(0xFF3CC76A),
                        icon: Icons.timer_rounded,
                        iconColor: const Color(0xFF3CC76A),
                        value: _time()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---------------------------------------- drawing
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFDCE6EC),
                        offset: Offset(0, 4),
                        blurRadius: 4),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Image.memory(r.png, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---------------------------------------- save / share
            Row(
              children: [
                Expanded(
                  child: _SoftButton(
                    icon: Icons.save_alt_rounded,
                    label: tr(context, 'save'),
                    busy: _saving,
                    onTap: _save,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SoftButton(
                    icon: Icons.ios_share_rounded,
                    label: tr(context, 'shareShort'),
                    onTap: _share,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              Container(
                height: 90,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            Pressable(
              onTap: _drawAgain,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1673FF),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(tr(context, 'drawAgain'),
                    style: nunito(18,
                        weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.header,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.value,
  });
  final String header;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 24,
            color: color,
            alignment: Alignment.center,
            child: Text(header,
                style:
                    nunito(13, weight: FontWeight.w600, color: Colors.white)),
          ),
          SizedBox(
            height: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(value, style: nunito(16, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFD9ECFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 20, color: const Color(0xFF3A8EF0)),
            const SizedBox(width: 8),
            Text(label,
                style: nunito(16,
                    weight: FontWeight.w600, color: const Color(0xFF3A8EF0))),
          ],
        ),
      ),
    );
  }
}

// ================================================================ help
/// "Tell Us What You Need" sheet: Feedback / Request Feature / Report Bug.
Future<void> showTellUsDialog(BuildContext context) {
  Future<void> mail(String subjectKey) async {
    final subject = Uri.encodeComponent(
        '${tr(context, subjectKey)} - ${AppConfig.appName}');
    try {
      await launchUrl(
          Uri.parse('mailto:${AppConfig.feedbackEmail}?subject=$subject'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget option(BuildContext ctx, IconData icon, Color color, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.pop(ctx);
          mail(key);
        },
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(tr(context, key),
                  style: nunito(15, weight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF8A8A8A)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Emoji('💬', size: 56),
            const SizedBox(height: 8),
            Text(tr(context, 'tellUsTitle'),
                style: nunito(20, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr(context, 'tellUsSub'),
                textAlign: TextAlign.center,
                style: nunito(15,
                    weight: FontWeight.w500, color: AppColors.sub)),
            const SizedBox(height: 16),
            option(ctx, Icons.grid_view_rounded, const Color(0xFF3A8EF0),
                'feedback'),
            option(ctx, Icons.lightbulb_outline_rounded,
                const Color(0xFFF5A623), 'requestFeature'),
            option(ctx, Icons.warning_amber_rounded, const Color(0xFFF0476A),
                'reportBug'),
          ],
        ),
      ),
    ),
  );
}
