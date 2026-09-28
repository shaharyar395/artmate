import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../battle/battle_data.dart' show BStroke, SeatState;
import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../dt/dt_session.dart';
import '../../widgets/common.dart';
import '../trace_result_screen.dart' show showTellUsDialog;
import 'dt_game_screen.dart';
import '../draw_together_screen.dart';

/// "Perfect Drawing" after a Draw Together round. The shared picture keeps
/// updating while the partner is still drawing ("● Drawing" → "Done").
class DtResultScreen extends StatefulWidget {
  const DtResultScreen({
    super.key,
    required this.session,
    required this.myStrokes,
    required this.points,
    required this.lines,
    required this.seconds,
  });

  final DtSession session;
  final List<BStroke> myStrokes;
  final int points;
  final int lines;
  final int seconds;

  @override
  State<DtResultScreen> createState() => _DtResultScreenState();
}

class _DtResultScreenState extends State<DtResultScreen> {
  bool _saving = false;
  bool _savedToAlbum = false;

  DtSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _s.partnerState.addListener(_onPartner);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPartner());
  }

  @override
  void dispose() {
    _s.partnerState.removeListener(_onPartner);
    _s.dispose();
    super.dispose();
  }

  /// When the partner finishes (or leaves), store the full picture in My album.
  Future<void> _onPartner() async {
    if (!mounted) return;
    setState(() {});
    final p = _s.partnerState.value;
    if (_savedToAlbum || !(p.finished || p.left)) return;
    _savedToAlbum = true;
    final app = AppScope.read(context);
    try {
      final png = await renderDtPng(_s, widget.myStrokes, p, 900);
      final dir = await getApplicationDocumentsDirectory();
      final name = 'album_dt_${DateTime.now().microsecondsSinceEpoch}.png';
      await File('${dir.path}/$name').writeAsBytes(png);
      app.addToAlbum(_s.template.id, const [], imagePath: name);
    } catch (_) {}
  }

  String _time() {
    final s = widget.seconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toast(String key, {bool ok = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.fromLTRB(60, 0, 60, 90),
        content: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: ok ? AppColors.switchGreen : const Color(0xFFE5484D),
              size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(tr(context, key),
                  textAlign: TextAlign.center,
                  style: nunito(13,
                      weight: FontWeight.w600, color: AppColors.textSoft))),
        ]),
      ));
  }

  Future<void> _save() async {
    if (_saving) return;
    AppScope.read(context).tap();
    setState(() => _saving = true);
    try {
      final png = await renderDtPng(
          _s, widget.myStrokes, _s.partnerState.value, 1000);
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(png,
          album: AppConfig.appName,
          name: 'together_${DateTime.now().millisecondsSinceEpoch}');
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
      final png = await renderDtPng(
          _s, widget.myStrokes, _s.partnerState.value, 1000);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/drawn_together.png');
      await f.writeAsBytes(png);
      if (!mounted) return;
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')],
          text: tr(context, 'shareText', {'url': AppConfig.playStoreUrl}),
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted) _toast('saveFailed', ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final p = _s.partnerState.value;
    final total = _s.partnerSteps.isEmpty ? 1 : _s.partnerSteps.length;
    final partnerFrac =
        p.finished ? 1.0 : ((p.step + p.progress) / total).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Row(
                    children: [
                      const BackCircle(),
                      Expanded(
                        child: Center(
                          heightFactor: 1,
                          child: OutlinedText(tr(context, 'perfectDrawing'),
                              size: 28,
                              fill: AppColors.titleBlue,
                              stroke: Colors.white,
                              strokeWidth: 5),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showTellUsDialog(context),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.white,
                      child: Row(children: [
                        _stat(tr(context, 'point'), const Color(0xFFFFC61A),
                            Icons.stars_rounded, '${widget.points} / 100'),
                        _stat(tr(context, 'lines'), const Color(0xFF3A8EF0),
                            Icons.show_chart_rounded, '${widget.lines}'),
                        _stat(tr(context, 'time'), const Color(0xFF3CC76A),
                            Icons.timer_rounded, _time()),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ---------------------------------- live shared picture
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PairPainter(
                                  _s, widget.myStrokes, p.strokes),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Row(children: [
                              _smallBtn(
                                  _saving
                                      ? Icons.hourglass_top_rounded
                                      : Icons.save_alt_rounded,
                                  _save),
                              const SizedBox(width: 8),
                              _smallBtn(Icons.ios_share_rounded, _share),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('${tr(context, 'drawingPartner')} · 1',
                      style: nunito(15,
                          weight: FontWeight.w700, color: AppColors.textSoft)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Emoji(
                            kAvatars[_s.partner.avatar % kAvatars.length],
                            size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_s.partner.name,
                                  style: nunito(16, weight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: partnerFrac,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE6E6E6),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF3DD16B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _badge(p),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Pressable(
                onTap: () {
                  // Back to Draw Together, which shows the Quick Match /
                  // Invite Friend pop-up for this picture again.
                  final t = _s.template;
                  Navigator.of(context).pop();
                  DrawTogetherScreen.replay.value = t;
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1673FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(tr(context, 'drawAgain'),
                      style: nunito(17,
                          weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(SeatState p) {
    final (text, fg, bg) = p.left
        ? (tr(context, 'leftGame'), const Color(0xFF8A8A8A), const Color(0xFFF0F0F0))
        : p.finished
            ? (tr(context, 'doneWord'), const Color(0xFF2E9E57), const Color(0xFFE3F7EA))
            : (tr(context, 'drawingWord'), const Color(0xFFE5484D), const Color(0xFFFDECEC));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: nunito(12, weight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  Widget _smallBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F0FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3A8EF0)),
        ),
      );

  Widget _stat(String h, Color c, IconData icon, String v) => Expanded(
        child: Column(children: [
          Container(
            height: 24,
            color: c,
            alignment: Alignment.center,
            child: Text(h,
                style:
                    nunito(13, weight: FontWeight.w600, color: Colors.white)),
          ),
          SizedBox(
            height: 34,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Text(v, style: nunito(15, weight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}

class _PairPainter extends CustomPainter {
  _PairPainter(this.s, this.mine, this.partner);
  final DtSession s;
  final List<BStroke> mine;
  final List<BStroke> partner;

  @override
  void paint(Canvas canvas, Size size) => paintDtPair(canvas, size.shortestSide,
      session: s, myStrokes: mine, partnerStrokes: partner);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
