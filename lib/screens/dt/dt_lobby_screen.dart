import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../battle/battle_data.dart' show BattlePlayer;
import '../../battle/battle_service.dart';
import '../../core/app_state.dart';
import '../../core/dt_catalog.dart';
import '../../core/sound.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'dt_game_screen.dart';
import 'dt_start.dart';

/// "Lobby" (Invite Friend): the picture with Change, You · host and an
/// empty "+ Invite" slot, the 4-digit ROOM CODE with share, "Got a friend
/// nearby? Share", Let's draw! and I'll draw by myself.
///
/// When the friend enters the code in Join Room they appear in the slot and
/// the round starts for both of you.
class DtLobbyScreen extends StatefulWidget {
  const DtLobbyScreen({super.key, required this.template});
  final DtTemplate template;

  @override
  State<DtLobbyScreen> createState() => _DtLobbyScreenState();
}

class _DtLobbyScreenState extends State<DtLobbyScreen>
    with SingleTickerProviderStateMixin {
  late DtTemplate _template = widget.template;
  final String _code = '${1000 + math.Random().nextInt(9000)}';
  int _token = 0;
  MatchInfo? _match;
  BattlePlayer? _friend;
  bool _leaving = false;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  BattleService get _svc => BattleService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wait());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Waits in the private room for a friend (renews every 2 minutes).
  Future<void> _wait() async {
    if (!_svc.isOnline) return; // offline: nobody can join
    final app = AppScope.read(context);
    final token = ++_token;
    final info = await _svc.findMatch(
      size: 2,
      templateId: _template.id,
      name: app.username,
      avatar: app.avatarIndex,
      queue: 'dt_code_$_code',
      waitMs: BattleService.privateRoomMs,
      fillBots: false,
    );
    if (!mounted || token != _token || _leaving) return;
    if (info == null) {
      // Nobody came yet (or a network error returned at once): keep the
      // room open, without hammering the server in a tight loop.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || token != _token || _leaving) return;
      _wait();
      return;
    }
    final friend = info.players.firstWhere((p) => p.seat != info.mySeat,
        orElse: () => info.players.last);
    Sound.instance.play(Sfx.match);
    setState(() {
      _match = info;
      _friend = friend;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(tr(context, 'friendJoined', {'name': friend.name}))));
    // The friend's phone is already starting: start together.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted && !_leaving) _start(info);
  }

  Future<void> _stopWaiting() async {
    _token++;
    await _svc.cancelSearch();
  }

  void _start(MatchInfo info) {
    _leaving = true;
    Navigator.of(context).pushReplacement(fadeRoute(DtGameScreen(
      template: _template,
      presetMatch: info,
      withFriend: true,
    )));
  }

  Future<void> _change() async {
    if (_match != null) return;
    final t = await showDtTemplatePicker(context, _template);
    if (t == null || !mounted || t.id == _template.id) return;
    await _stopWaiting();
    if (!mounted) return;
    setState(() => _template = t);
    _wait();
  }

  void _share() {
    AppScope.read(context).tap();
    Share.share(tr(context, 'shareCode', {'code': _code}));
  }

  Future<void> _letsDraw() async {
    final m = _match;
    if (m != null) {
      _start(m);
      return;
    }
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SlotDialog(),
    );
    if (choice == true && mounted) {
      // Fill them now: match with anyone online on this picture.
      _leaving = true;
      await _stopWaiting();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          fadeRoute(DtGameScreen(template: _template)));
    }
  }

  Future<void> _drawAlone() async {
    AppScope.read(context).tap();
    _leaving = true;
    await _stopWaiting();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        fadeRoute(DtGameScreen(template: _template, solo: true)));
  }

  Future<void> _back() async {
    _leaving = true;
    await _stopWaiting();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    BackCircle(onTap: _back),
                    Expanded(
                      child: Center(
                        heightFactor: 1,
                        child: OutlinedText(tr(context, 'lobby'),
                            size: 26,
                            fill: AppColors.titleBlue,
                            stroke: Colors.white,
                            strokeWidth: 5),
                      ),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  children: [
                    // ------------------------------ picture + players
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8EAED)),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 130,
                                  height: 110,
                                  child: ArtSlot(
                                    asset: 'tpl_${_template.id}.png',
                                    fallback:
                                        DtTemplatePicture(template: _template),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(dtTemplateName(_template),
                                          style: nunito(17,
                                              weight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      const PlayersBadge(),
                                      const SizedBox(height: 10),
                                      if (_match == null)
                                        ChangeChip(onTap: _change),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEDEFF2)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _slot(
                                    RingAvatar(
                                        avatar: app.avatarIndex,
                                        size: 58,
                                        host: true),
                                    tr(context, 'youHost'),
                                    const Color(0xFF1677FF)),
                                const SizedBox(width: 26),
                                _friend != null
                                    ? _slot(
                                        RingAvatar(
                                            avatar: _friend!.avatar,
                                            size: 58,
                                            check: true),
                                        _friend!.name,
                                        const Color(0xFF3A3A3A))
                                    : GestureDetector(
                                        onTap: _share,
                                        child: _slot(
                                            const _DashedPlus(),
                                            tr(context, 'invite'),
                                            AppColors.sub),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ------------------------------ room code
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr(context, 'roomCodeCaps'),
                                    style: nunito(13,
                                        weight: FontWeight.w800,
                                        color: const Color(0xFF2A2A2A))),
                                const SizedBox(height: 2),
                                Text(tr(context, 'roomCodeShare'),
                                    style: nunito(11,
                                        weight: FontWeight.w600,
                                        color: AppColors.sub)),
                              ],
                            ),
                          ),
                          for (final ch in _code.split(''))
                            Container(
                              width: 28,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(ch,
                                  style: nunito(20,
                                      weight: FontWeight.w900,
                                      color: const Color(0xFF1677FF))),
                            ),
                          IconButton(
                            onPressed: _share,
                            icon: const Icon(Icons.reply_rounded,
                                textDirection: TextDirection.rtl,
                                color: Color(0xFF1677FF)),
                          ),
                        ],
                      ),
                    ),
                    if (!_svc.isOnline) ...[
                      const SizedBox(height: 10),
                      Text(tr(context, 'onlineNeeded'),
                          textAlign: TextAlign.center,
                          style: nunito(12,
                              weight: FontWeight.w600, color: AppColors.sub)),
                    ],
                  ],
                ),
              ),
              // ------------------------------ bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8EAED)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                            color: Color(0xFFF1F2F4), shape: BoxShape.circle),
                        child: const Icon(Icons.person_rounded,
                            color: Color(0xFF8A8F98), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(context, 'friendNearby'),
                                style: nunito(14, weight: FontWeight.w800)),
                            Text(tr(context, 'sendCode'),
                                style: nunito(12,
                                    weight: FontWeight.w600,
                                    color: AppColors.sub)),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: _share,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tr(context, 'shareShort'),
                              style: nunito(14,
                                  weight: FontWeight.w800,
                                  color: const Color(0xFF1677FF))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                      scale: _friend != null ? 1 + 0.03 * _pulse.value : 1,
                      child: child),
                  child: BlueButton(
                      label: tr(context, 'letsDraw'), onTap: _letsDraw),
                ),
              ),
              TextButton(
                onPressed: _drawAlone,
                child: Text(tr(context, 'drawMyself'),
                    style: nunito(14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF1677FF))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(Widget avatar, String label, Color color) {
    return Column(
      children: [
        avatar,
        const SizedBox(height: 4),
        Text(label,
            style: nunito(12, weight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _DashedPlus extends StatelessWidget {
  const _DashedPlus();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _DashedCirclePainter(const Color(0xFF6FA8F5)),
        child: const Center(
          child: Icon(Icons.add_rounded, size: 30, color: Color(0xFF1677FF)),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a,
          math.pi / n * 0.9, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => false;
}

/// "1 slot still open — Pick how to start": Fill them now / Wait for friends.
class _SlotDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget option(Widget icon, String label, bool value) => Expanded(
          child: GestureDetector(
            onTap: () {
              AppScope.read(context).tap();
              Navigator.pop(context, value);
            },
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 10),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: nunito(12, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 34, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'slotOpen'),
                    style: nunito(18, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr(context, 'pickHow'),
                    style: nunito(13,
                        weight: FontWeight.w600, color: AppColors.sub)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    option(
                        const Icon(Icons.groups_rounded,
                            size: 44, color: Color(0xFF1677FF)),
                        tr(context, 'fillNow'),
                        true),
                    const SizedBox(width: 12),
                    option(
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CustomPaint(
                              painter: _DashedCirclePainter(
                                  const Color(0xFF1677FF))),
                        ),
                        tr(context, 'waitFriends'),
                        false),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF8A8A8A)),
            ),
          ),
        ],
      ),
    );
  }
}
