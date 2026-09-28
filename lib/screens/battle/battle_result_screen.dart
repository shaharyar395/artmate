import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../battle/battle_data.dart';
import '../../battle/battle_service.dart';
import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../settings_screen.dart' show showRateForUsDialog;
import '../trace_result_screen.dart' show showTellUsDialog;
import 'battle_game_screen.dart' show paintBattlePicture;

/// "YOU ARE 1st!" page after an Art Battle round: Point / Lines / Time,
/// everyone's drawings together, Save / Share and Draw Again.
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({
    super.key,
    required this.match,
    required this.seats,
    required this.png,
    required this.rank,
    required this.points,
    required this.lines,
    required this.seconds,
  });
  final MatchInfo match;
  final Map<int, SeatState> seats;
  final Uint8List? png;
  final int rank; // 1-based
  final int points;
  final int lines;
  final int seconds;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  static bool _askedRating = false; // once per app launch
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!_askedRating) {
      _askedRating = true;
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          showRateForUsDialog(context);
        }
      });
    }
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
    final png = widget.png;
    if (_saving || png == null) return;
    AppScope.read(context).tap();
    setState(() => _saving = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(png,
          album: AppConfig.appName,
          name: 'art_battle_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) _toast('savedGallery');
    } catch (_) {
      if (mounted) _toast('saveFailed', ok: false);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _share() async {
    final png = widget.png;
    if (png == null) return;
    AppScope.read(context).tap();
    final box = context.findRenderObject() as RenderBox?;
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/art_battle.png');
      await f.writeAsBytes(png);
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

  void _back() {
    AppScope.read(context).tap();
    Navigator.of(context).pop(); // back to Select Template
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final rank = widget.rank.clamp(1, 4);
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            // ---------------------------------------- header
            Row(
              children: [
                BackCircle(onTap: () => Navigator.of(context).pop()),
                Expanded(
                  child: Center(
                    heightFactor: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: OutlinedText(tr(context, 'youAre$rank'),
                          size: 28,
                          fill: AppColors.titleBlue,
                          stroke: Colors.white,
                          strokeWidth: 5),
                    ),
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
                        value: '${widget.points} / 100'),
                    _Stat(
                        header: tr(context, 'lines'),
                        color: const Color(0xFF3A8EF0),
                        icon: Icons.show_chart_rounded,
                        iconColor: const Color(0xFF3A8EF0),
                        value: '${widget.lines}'),
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
            // ---------------------------------------- everyone's drawings
            AspectRatio(
              aspectRatio: widget.match.players.length > 2 ? 1 : 1.6,
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
                  child: widget.png != null
                      ? Image.memory(widget.png!, fit: BoxFit.contain)
                      : CustomPaint(
                          painter: _PicturePainter(widget.match, widget.seats),
                          child: const SizedBox.expand(),
                        ),
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
            const SizedBox(height: 18),
            Pressable(
              onTap: _back,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1673FF),
                  borderRadius: BorderRadius.circular(8),
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

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.match, this.seats);
  final MatchInfo match;
  final Map<int, SeatState> seats;

  @override
  void paint(Canvas canvas, Size size) => paintBattlePicture(
      canvas, size, templateById(match.templateId), match.players, seats);

  @override
  bool shouldRepaint(covariant _PicturePainter old) => false;
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value,
                        style: nunito(16, weight: FontWeight.w700)),
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
