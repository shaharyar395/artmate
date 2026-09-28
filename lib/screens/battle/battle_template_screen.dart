import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../battle/battle_data.dart';
import '../../battle/battle_service.dart';
import '../../core/app_state.dart';
import '../../core/trace_catalog.dart';
import '../../widgets/trace_item_art.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'battle_game_screen.dart';
import 'select_room_screen.dart';
import '../../core/sound.dart';

/// "Select Template": pick a card, then matchmaking runs.
class BattleTemplateScreen extends StatefulWidget {
  const BattleTemplateScreen({super.key, required this.size});
  final int size; // 4 or 2

  @override
  State<BattleTemplateScreen> createState() => _BattleTemplateScreenState();
}

enum _Phase { idle, searching, matched }

class _BattleTemplateScreenState extends State<BattleTemplateScreen> {
  _Phase _phase = _Phase.idle;
  int _searchToken = 0;

  Future<void> _play(BattleTemplate t) async {
    if (_phase != _Phase.idle) return;
    final s = AppScope.read(context);
    final svc = BattleService.instance;
    final token = ++_searchToken;
    setState(() => _phase = _Phase.searching);

    MatchInfo? info = await svc.findMatch(
      size: widget.size,
      templateId: t.id,
      name: s.username,
      avatar: s.avatarIndex,
    );
    if (!mounted || token != _searchToken || _phase != _Phase.searching) {
      return; // cancelled
    }
    // Nobody could be matched online -> play with computer players.
    info ??= BattleService.botMatch(
        size: widget.size,
        templateId: t.id,
        name: s.username,
        avatar: s.avatarIndex,
        startAt: svc.now());

    Sound.instance.play(Sfx.match);
    setState(() => _phase = _Phase.matched);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted || token != _searchToken) return;
    final match = info;
    await Navigator.of(context)
        .push(fadeRoute(BattleGameScreen(match: match)));
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  Future<void> _cancel() async {
    _searchToken++;
    setState(() => _phase = _Phase.idle);
    await BattleService.instance.cancelSearch();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final templates = templatesForSize(widget.size);
    return PopScope(
      canPop: _phase == _Phase.idle,
      onPopInvoked: (didPop) {
        if (!didPop && _phase == _Phase.searching) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.settingsBg,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  BattleHeader(
                    title: tr(context, 'selectTemplate'),
                    onBack: () {
                      if (_phase == _Phase.searching) {
                        _cancel();
                      } else if (_phase == _Phase.idle) {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: templates.length,
                      itemBuilder: (context, i) => Pressable(
                        pressedScale: 0.94,
                        onTap: () => _play(templates[i]),
                        child: BattleTemplateCard(template: templates[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_phase == _Phase.searching)
              Positioned.fill(child: _SearchingOverlay(onCancel: _cancel)),
            if (_phase == _Phase.matched)
              const Positioned.fill(child: _MatchedOverlay()),
          ],
        ),
      ),
    );
  }
}

/// White card showing the template's characters (2x2 or diagonal pair).
class BattleTemplateCard extends StatelessWidget {
  const BattleTemplateCard(
      {super.key, required this.template, this.highlightSeat});
  final BattleTemplate template;
  final int? highlightSeat;

  Widget _cell(int seat, double size) {
    final item = traceItemById(template.itemFor(seat));
    final hl = highlightSeat == seat;
    return Container(
      decoration: hl
          ? BoxDecoration(
              color: kSeatColors[seat].withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.06),
      child: TraceItemArt(item: item, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFFD8E1E8), offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth;
        if (template.size == 4) {
          const line = BorderSide(color: Color(0xFFEDEFF2), width: 1.2);
          return Column(
            children: [
              Expanded(
                child: Row(children: [
                  Expanded(
                      child: Container(
                          decoration: const BoxDecoration(
                              border: Border(right: line, bottom: line)),
                          child: _cell(0, side * 0.46))),
                  Expanded(
                      child: Container(
                          decoration:
                              const BoxDecoration(border: Border(bottom: line)),
                          child: _cell(1, side * 0.46))),
                ]),
              ),
              Expanded(
                child: Row(children: [
                  Expanded(
                      child: Container(
                          decoration:
                              const BoxDecoration(border: Border(right: line)),
                          child: _cell(2, side * 0.46))),
                  Expanded(child: _cell(3, side * 0.46)),
                ]),
              ),
            ],
          );
        }
        return CustomPaint(
          painter: DiagonalPainter(),
          child: Stack(
            children: [
              Positioned(
                  left: 4,
                  top: 4,
                  width: side * 0.48,
                  height: side * 0.44,
                  child: _cell(0, side * 0.32)),
              Positioned(
                  right: 4,
                  bottom: 4,
                  width: side * 0.48,
                  height: side * 0.44,
                  child: _cell(1, side * 0.32)),
            ],
          ),
        );
      }),
    );
  }
}

// ================================================================ overlays
class _SearchingOverlay extends StatefulWidget {
  const _SearchingOverlay({required this.onCancel});
  final VoidCallback onCancel;

  @override
  State<_SearchingOverlay> createState() => _SearchingOverlayState();
}

class _SearchingOverlayState extends State<_SearchingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  int _dots = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 450),
        (_) => setState(() => _dots = (_dots + 1) % 4));
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.62),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBDE9FF),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: RotationTransition(
                        turns: _c, child: const Emoji('🌍', size: 120)),
                  ),
                  // Magnifier sweeping around the globe
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final a = _c.value * 2 * math.pi;
                      return Transform.translate(
                        offset: Offset(30 * math.cos(a), 30 * math.sin(a)),
                        child: const Emoji('🔍', size: 56),
                      );
                    },
                  ),
                  const Positioned(
                      left: 6, top: 40, child: Emoji('🇵🇰', size: 28)),
                  const Positioned(
                      right: 10, top: 18, child: Emoji('🇺🇸', size: 24)),
                  const Positioned(
                      right: 0, bottom: 50, child: Emoji('🇧🇷', size: 22)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(tr(context, 'findingPlayers'),
                textAlign: TextAlign.center,
                style: nunito(28, weight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 18),
            Text('${tr(context, 'searching')}${'.' * _dots}',
                style: nunito(17, weight: FontWeight.w600, color: Colors.white)),
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }

}

class _MatchedOverlay extends StatelessWidget {
  const _MatchedOverlay();

  @override
  Widget build(BuildContext context) {
    final words = tr(context, 'matched').split('\n');
    return Container(
      color: Colors.black.withOpacity(0.7),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.3, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Transform.rotate(
          angle: -0.08,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedText(words.first,
                  size: 40,
                  fill: const Color(0xFF8BFF2E),
                  stroke: const Color(0xFF16330A),
                  strokeWidth: 6,
                  align: TextAlign.center),
              OutlinedText(words.length > 1 ? words[1] : '',
                  size: 72,
                  fill: const Color(0xFF8BFF2E),
                  stroke: const Color(0xFF16330A),
                  strokeWidth: 8,
                  align: TextAlign.center),
              Opacity(
                opacity: 0.35,
                child: OutlinedText(words.length > 1 ? words[1] : '',
                    size: 48,
                    fill: Colors.transparent,
                    stroke: const Color(0xFF8BFF2E),
                    strokeWidth: 2,
                    align: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
