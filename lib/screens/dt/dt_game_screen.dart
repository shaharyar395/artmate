import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../battle/battle_data.dart' show BStroke, SeatState, BattlePlayer;
import '../../battle/battle_service.dart';
import '../../battle/bot_player.dart' show stableHash, botName;
import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/dt_catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/trace_art_model.dart';
import '../../core/trace_steps.dart';
import '../../dt/dt_session.dart';
import '../../widgets/celebration.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_kit.dart';
import 'dt_chat.dart';
import 'dt_result_screen.dart';
import 'dt_start.dart';
import '../../core/sound.dart';

/// Draw Together round:
/// 1. "Finding drawing buddies… 1/2 ready" (Cancel) → "Ready to draw! 2/2"
///    → picture card "Starting in 3…".
/// 2. Colour your drawing area by area ("Step n/N"), green bar fills,
///    → appears once you've painted, praise sticker after every step.
/// 3. Result page (partner keeps drawing live there if not done yet).
class DtGameScreen extends StatefulWidget {
  const DtGameScreen({
    super.key,
    required this.template,
    this.quick = false,
    this.joinCode,
    this.presetMatch,
    this.solo = false,
    this.withFriend = false,
  });
  final DtTemplate template;

  /// Quick Match: one shared queue; the room host's picture is used.
  final bool quick;

  /// Join Room: the 4-digit code from a friend. The friend's picture is
  /// used; if no open room has this code the page closes with 'notFound'.
  final String? joinCode;

  /// Already matched in the Lobby (friend joined by room code).
  final MatchInfo? presetMatch;

  /// "I'll draw by myself": no search, a computer buddy takes the other half.
  final bool solo;

  /// Friend from a room code: free text chat is allowed.
  final bool withFriend;

  @override
  State<DtGameScreen> createState() => _DtGameScreenState();
}

enum _Phase { finding, ready, countdown, drawing }

class _DtGameScreenState extends State<DtGameScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.finding;
  late DtTemplate _template = widget.template;
  DtSession? _session;
  int _countdown = 3;
  int _token = 0;

  bool get _joining => widget.joinCode != null;

  /// Partner's pen: last point (in their drawing's 0..1 units) and when it
  /// moved, to show their avatar where they are drawing.
  Offset? _cursor;
  int _cursorAt = 0;
  int _partnerSig = 0;
  bool _tilesOpen = true;

  // drawing state
  int _step = 0;
  List<BStroke> _strokes = [];
  final List<List<BStroke>> _undo = [];
  final List<List<BStroke>> _redo = [];
  BStroke? _current;
  CoverageTracker? _tracker;
  final List<double> _scores = [];
  List<Color> _palette = [];
  Color _color = Colors.black;
  double _width = 0.06;
  bool _eraser = false;
  bool _busy = false;
  Praise? _praise;
  String? _bubble;
  bool _bubbleMine = false;
  Timer? _bubbleTimer;
  final Stopwatch _clock = Stopwatch();
  final GlobalKey _menuKey = GlobalKey();

  late final AnimationController _cam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  static const Rect _full = Rect.fromLTWH(-0.04, -0.04, 1.08, 1.08);
  Rect _camFrom = _full;
  Rect _camTo = _full;

  DtSession get _s => _session!;
  TraceStep get _cur => _s.mySteps[_step];
  bool get _hasInk => _strokes.any((s) => s.tag == _step && !s.erase);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = widget.presetMatch;
      if (m != null) {
        _begin(m);
      } else {
        _find();
      }
    });
  }

  @override
  void dispose() {
    _cam.dispose();
    _bubbleTimer?.cancel();
    _progressTimer?.cancel();
    _session?.chat.removeListener(_onChat);
    _session?.partnerState.removeListener(_onPartner);
    if (!_handedOver) _session?.dispose();
    super.dispose();
  }

  bool _handedOver = false;

  // ------------------------------------------------------------ matching
  Future<void> _find() async {
    final app = AppScope.read(context);
    final svc = BattleService.instance;
    final token = ++_token;
    final code = widget.joinCode;
    setState(() => _phase = _Phase.finding);
    MatchInfo? info;
    if (widget.solo) {
      await Future.delayed(const Duration(milliseconds: 900));
    } else {
      info = await svc.findMatch(
        size: 2,
        templateId: _template.id,
        name: app.username,
        avatar: app.avatarIndex,
        queue: code != null
            ? 'dt_code_$code'
            : (widget.quick ? 'dt_quick' : 'dt_${_template.id}'),
        joinOnly: _joining,
        waitMs: code != null ? BattleService.privateRoomMs : null,
        fillBots: code == null,
      );
    }
    if (!mounted || token != _token) return;
    if (info == null && _joining) {
      Navigator.of(context).pop('notFound');
      return;
    }
    // Nobody online for this picture: a computer buddy joins.
    info ??= BattleService.botMatch(
        size: 2,
        templateId: _template.id,
        name: app.username,
        avatar: app.avatarIndex,
        startAt: svc.now());
    await _begin(info);
  }

  /// "Change" on the Finding buddies page: pick another picture and search
  /// again.
  Future<void> _changePicture() async {
    if (_phase != _Phase.finding || _joining) return;
    final t = await showDtTemplatePicker(context, _template);
    if (t == null || !mounted || _phase != _Phase.finding) return;
    _token++;
    await BattleService.instance.cancelSearch();
    if (!mounted) return;
    setState(() => _template = t);
    _find();
  }

  Future<void> _begin(MatchInfo info) async {
    final svc = BattleService.instance;
    final rnd = math.Random(stableHash(info.roomId));
    final players = [
      for (final p in info.players)
        p.bot
            ? BattlePlayer(
                id: p.id,
                seat: p.seat,
                name: botName(rnd.nextInt(100000)),
                avatar: p.avatar,
                bot: true)
            : p
    ];
    final match = MatchInfo(
      roomId: info.roomId,
      templateId: info.templateId,
      size: 2,
      mySeat: info.mySeat,
      players: players,
      startAt: svc.now() + 4200,
      online: info.online,
    );
    _template = dtTemplateById(info.templateId);
    _session = DtSession(match: match, template: _template)
      ..withFriend = widget.withFriend || _joining;
    _session!.chat.addListener(_onChat);
    _session!.partnerState.addListener(_onPartner);
    _camFrom = _camTo = _full.shift(_myOff);
    _palette = _paletteFor(_s);
    _color = _s.mySteps.isEmpty ? Colors.pink : _s.mySteps.first.color!;
    Sound.instance.play(Sfx.match);
    setState(() => _phase = _Phase.ready);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
    });
    for (var i = 2; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Sound.instance.play(i == 0 ? Sfx.step : Sfx.tick);
      setState(() => _countdown = i);
    }
    _s.start();
    _clock.start();
    setState(() {
      _phase = _Phase.drawing;
      _tracker = CoverageTracker(_cur);
    });
    _moveCamera();
  }

  Future<void> _cancelFind() async {
    _token++;
    await BattleService.instance.cancelSearch();
    if (mounted) Navigator.of(context).pop();
  }

  List<Color> _paletteFor(DtSession s) {
    final base = <Color>[];
    for (final st in s.mySteps) {
      if (!base.contains(st.color)) base.add(st.color!);
    }
    final out = <Color>[];
    for (final c in base) {
      out.add(c);
      final hsl = HSLColor.fromColor(c);
      out.add(hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor());
    }
    out.addAll(const [Color(0xFF000000), Color(0xFFFFFFFF)]);
    return out;
  }

  // ------------------------------------------------------------ partner pen
  void _onPartner() {
    final st = _session?.partnerState.value;
    if (st == null || !mounted) return;
    var sig = st.strokes.length * 100000;
    Offset? last;
    if (st.strokes.isNotEmpty && st.strokes.last.points.isNotEmpty) {
      sig += st.strokes.last.points.length;
      last = st.strokes.last.points.last;
    }
    if (sig != _partnerSig && last != null) {
      _partnerSig = sig;
      _cursor = last;
      _cursorAt = DateTime.now().millisecondsSinceEpoch;
      // Hide the pen avatar again once they stop.
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() {});
      });
    }
    setState(() {}); // partner's drawing shows on the shared canvas
  }

  // ------------------------------------------------------------ chat
  void _onChat() {
    final c = _session?.chat.value;
    if (c == null || !mounted) return;
    _bubbleTimer?.cancel();
    Sound.instance.play(Sfx.chat);
    setState(() {
      _bubble = c.$2;
      _bubbleMine = c.$1 == _s.mySeat;
    });
    _bubbleTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  Future<void> _openChat() async {
    AppScope.read(context).tap();
    await showDtChatSheet(context, _s);
  }

  // ------------------------------------------------------------ camera
  Rect _viewFor(TraceStep s) {
    var r = s.bounds;
    r = r.inflate(math.max(0.05, 0.14 * math.max(r.width, r.height)));
    const minSide = 0.45;
    if (r.width < minSide || r.height < minSide) {
      r = Rect.fromCenter(
          center: r.center,
          width: math.max(r.width, minSide),
          height: math.max(r.height, minSide));
    }
    return r;
  }

  /// Where each drawing sits on the shared canvas (left / right).
  Offset get _myOff => Offset(_s.mySeat == 0 ? 0 : kDtGap, 0);
  Offset get _partnerOff => Offset(_s.mySeat == 0 ? kDtGap : 0, 0);

  void _moveCamera() {
    _camFrom = _view;
    _camTo = _viewFor(_cur).shift(_myOff);
    _cam.forward(from: 0);
  }

  Rect get _view => Rect.lerp(
      _camFrom, _camTo, Curves.easeInOutCubic.transform(_cam.value))!;

  (double, Offset) _transform(Size size) {
    final v = _view;
    final sc = math.min(size.width / v.width, size.height / v.height);
    return (sc, size.center(Offset.zero) - v.center * sc);
  }

  // ------------------------------------------------------------ drawing
  void _start(Offset p) {
    if (_busy || _phase != _Phase.drawing) return;
    _undo.add(List.of(_strokes));
    _redo.clear();
    final st = BStroke(_color, _eraser ? _width * 1.3 : _width,
        erase: _eraser, tag: _step, points: [p]);
    setState(() {
      _strokes = [..._strokes, st];
      _current = st;
      _tracker?.addSegment(p, p, st.width, erase: st.erase);
    });
  }

  void _update(Offset p) {
    final c = _current;
    if (c == null) return;
    final prev = c.points.last;
    setState(() {
      c.points.add(p);
      _tracker?.addSegment(prev, p, c.width, erase: c.erase);
    });
    _sendProgressSoon();
  }

  void _end() {
    final c = _current;
    if (c == null) return;
    _current = null;
    _s.sendStroke(c);
    _sendProgressSoon();
  }

  /// Shares my current-step bar with my partner (it can go down too when I
  /// colour outside or erase), at most every 400 ms.
  Timer? _progressTimer;
  void _sendProgressSoon() {
    if (_progressTimer != null) return;
    _progressTimer = Timer(const Duration(milliseconds: 400), () {
      _progressTimer = null;
      if (!mounted || _session == null || _phase != _Phase.drawing) return;
      _s.sendProgress(_step,
          accuracy: _avg(), progress: _tracker?.fraction ?? 0);
    });
  }

  void _rebuildTracker() {
    setState(() => _tracker = CoverageTracker.from(
        _cur, _strokes.where((s) => s.tag == _step)));
    _s.syncStrokes(_strokes);
    _sendProgressSoon();
  }

  void _undoAction() {
    if (_undo.isEmpty || _busy) return;
    AppScope.read(context).tap();
    _redo.add(_strokes);
    _strokes = _undo.removeLast();
    _rebuildTracker();
  }

  void _redoAction() {
    if (_redo.isEmpty || _busy) return;
    AppScope.read(context).tap();
    _undo.add(_strokes);
    _strokes = _redo.removeLast();
    _rebuildTracker();
  }

  Future<void> _next() async {
    if (!_hasInk || _busy) return;
    final cov = _tracker?.fraction ?? 0;
    if (cov < 0.45) {
      Sound.instance.play(Sfx.oops);
      _showBubbleText(tr(context, 'colorMore'));
      return;
    }
    AppScope.read(context).tap();
    _scores.add(cov);
    final last = _step == _s.mySteps.length - 1;
    setState(() {
      _busy = true;
      _praise = last ? kFinalPraise : kStepPraise[_step % kStepPraise.length];
      Sound.instance.play(last ? Sfx.finish : Sfx.praise);
    });
    _s.sendProgress(_step + 1, finished: last, accuracy: _avg());
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (last) {
      await _finish();
      return;
    }
    setState(() {
      _praise = null;
      _busy = false;
      _step++;
      _undo.clear();
      _redo.clear();
      _tracker = CoverageTracker(_cur);
      _color = _cur.color!;
      _eraser = false;
    });
    _moveCamera();
  }

  double _avg() => _scores.isEmpty
      ? 0
      : _scores.reduce((a, b) => a + b) / _scores.length;

  void _showBubbleText(String t) {
    _bubbleTimer?.cancel();
    setState(() {
      _bubble = t;
      _bubbleMine = true;
    });
    _bubbleTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  Future<void> _finish() async {
    final app = AppScope.read(context);
    app.completeLesson();
    app.addBuddy(
        _s.partner.bot ? 'bot_${_s.partner.name}' : _s.partner.id,
        _s.partner.name,
        _s.partner.avatar);
    final points = (60 + _avg() * 40).round().clamp(0, 100);
    _handedOver = true;
    Navigator.of(context).pushReplacement(fadeRoute(DtResultScreen(
      session: _s,
      myStrokes: _strokes,
      points: points,
      lines: _strokes.where((s) => !s.erase).length,
      seconds: _clock.elapsed.inSeconds,
    )));
  }

  Future<void> _askLeave() async {
    if (_phase == _Phase.finding) {
      await _cancelFind();
      return;
    }
    final quit = await showLeaveDialog(context);
    if (quit && mounted) {
      await _session?.leave();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openMenu() async {
    final app = AppScope.read(context);
    final action = await showDrawMenu(context, _menuKey);
    if (!mounted || action == null) return;
    if (action == DrawMenuAction.sound) {
      app.setSoundFx(!app.soundFx);
        app.setMusic(app.soundFx);
      app.tap();
    } else {
      await _askLeave();
    }
  }

  Future<void> _pickColor() async {
    final c = await showColorPicker(context, _color);
    if (c == null || !mounted) return;
    setState(() {
      if (!_palette.contains(c)) _palette = [c, ..._palette];
      _color = c;
      _eraser = false;
    });
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final ready = _session != null;
    final total = ready ? _s.mySteps.length : 1;
    final frac = _tracker?.fraction ?? 0;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && !_busy) _askLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ---------------------------- top: menu, bar, Step n/N
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 14, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          key: _menuKey,
                          onTap: _openMenu,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.notes_rounded,
                                size: 26, color: Color(0xFF3A3A3A)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _ThinBar(fraction: frac)),
                        const SizedBox(width: 12),
                        Text('Step ${ready ? _step + 1 : 1}/$total',
                            style: nunito(15, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  // ---------------------------- players (camera tiles)
                  if (ready)
                    _PlayerTiles(
                      open: _tilesOpen,
                      myAvatar: AppScope.read(context).avatarIndex,
                      partner: _s.partner,
                      partnerDone: _s.partnerState.value.finished,
                      onToggle: () {
                        AppScope.read(context).tap();
                        setState(() => _tilesOpen = !_tilesOpen);
                      },
                    ),
                  SizedBox(
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hasInkSafe && !_busy ? 1 : 0,
                          child: GestureDetector(
                            onTap: _next,
                            child: Container(
                              width: 58,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                      color: AppColors.blueDark,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ---------------------------- canvas
                  Expanded(
                    child: ready
                        ? LayoutBuilder(builder: (context, c) {
                            final size = Size(c.maxWidth, c.maxHeight);
                            Offset norm(Offset p) {
                              final (sc, off) = _transform(size);
                              return (p - off) / sc - _myOff;
                            }

                            return GestureDetector(
                              onPanStart: (d) =>
                                  _start(norm(d.localPosition)),
                              onPanUpdate: (d) =>
                                  _update(norm(d.localPosition)),
                              onPanEnd: (_) => _end(),
                              onPanCancel: _end,
                              child: ClipRect(
                                child: AnimatedBuilder(
                                  animation: _cam,
                                  builder: (_, __) {
                                    final (sc, off) = _transform(size);
                                    return CustomPaint(
                                      size: size,
                                      painter: _DtPainter(
                                        session: _s,
                                        strokes: _strokes,
                                        partnerStrokes:
                                            _s.partnerState.value.strokes,
                                        myOff: _myOff,
                                        partnerOff: _partnerOff,
                                        cursor: DateTime.now()
                                                        .millisecondsSinceEpoch -
                                                    _cursorAt <
                                                1600
                                            ? _cursor
                                            : null,
                                        cursorEmoji: kAvatars[_s.partner.avatar %
                                            kAvatars.length],
                                        step: _phase == _Phase.drawing
                                            ? _step
                                            : null,
                                        scale: sc,
                                        offset: off,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          })
                        : const SizedBox.expand(),
                  ),
                  // ---------------------------- undo/redo, slider, chat
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 4),
                    child: Row(
                      children: [
                        _Pill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _IconBtn(
                                  icon: Icons.undo_rounded,
                                  enabled: _undo.isNotEmpty,
                                  onTap: _undoAction),
                              Container(
                                  width: 1,
                                  height: 20,
                                  color: const Color(0xFFE3E5E8)),
                              _IconBtn(
                                  icon: Icons.redo_rounded,
                                  enabled: _redo.isNotEmpty,
                                  onTap: _redoAction),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Pill(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: BrushSizeSlider(
                                value: _width,
                                min: 0.01,
                                max: 0.14,
                                onChanged: (v) => setState(() => _width = v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: ready ? _openChat : null,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE3F0FF),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.chat_bubble_rounded,
                                color: Color(0xFF2F86EE), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: DrawColorBar(
                      color: _color,
                      eraser: _eraser,
                      colors: _palette.isEmpty ? kDrawColors : _palette,
                      onEraser: () => setState(() => _eraser = true),
                      onBrush: () => setState(() => _eraser = false),
                      onColor: (c) => setState(() {
                        _color = c;
                        _eraser = false;
                      }),
                      onPicker: _pickColor,
                    ),
                  ),
                ],
              ),
              // ------------------------------ chat bubble
              if (_bubble != null && ready)
                Positioned(
                  top: _tilesOpen ? 150 : 96,
                  left: 16,
                  right: 60,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ChatBubble(
                      text: _bubble!,
                      name: _bubbleMine
                          ? tr(context, 'you')
                          : _s.partner.name,
                      avatar: _bubbleMine
                          ? AppScope.read(context).avatarIndex
                          : _s.partner.avatar,
                    ),
                  ),
                ),
              // ------------------------------ matching overlays
              if (_phase == _Phase.ready || _phase == _Phase.countdown)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: _phase == _Phase.countdown
                        ? _CountdownCard(
                            template: _template, seconds: _countdown)
                        : _FindingCard(
                            ready: true,
                            partnerName: _session?.partner.name,
                            partnerAvatar: _session?.partner.avatar,
                            onCancel: _cancelFind,
                          ),
                  ),
                ),
              // ------------------------------ Finding buddies page
              if (_phase == _Phase.finding)
                Positioned.fill(
                  child: _FindingPage(
                    template: _template,
                    joining: _joining,
                    onBack: _cancelFind,
                    onChange: _joining ? null : _changePicture,
                  ),
                ),
              if (_praise != null)
                Positioned.fill(
                    child: CelebrationOverlay(
                        key: ValueKey('p$_step'), praise: _praise!)),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasInkSafe => _session != null && _phase == _Phase.drawing && _hasInk;
}

// ================================================================ widgets
class _ThinBar extends StatelessWidget {
  const _ThinBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final f = fraction.clamp(0.0, 1.0);
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E6E6),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: c.maxWidth * f,
          decoration: BoxDecoration(
            color: const Color(0xFF3DD16B),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    });
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon,
            color: enabled ? const Color(0xFF3A3A3A) : const Color(0xFFCFCFCF)),
      );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(
      {required this.text, required this.name, required this.avatar});
  final String text;
  final String name;
  final int avatar;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
          scale: v, alignment: Alignment.centerLeft, child: child),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Emoji(kAvatars[avatar % kAvatars.length], size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text('$name: $text',
                  style: nunito(14, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatefulWidget {
  const _FindingCard({
    required this.ready,
    required this.partnerName,
    required this.partnerAvatar,
    required this.onCancel,
  });
  final bool ready;
  final String? partnerName;
  final int? partnerAvatar;
  final VoidCallback onCancel;

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _player(String emoji, String label, bool ok, {bool waiting = false}) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: waiting ? const Color(0xFFF1F1F1) : Colors.transparent,
                  border: waiting
                      ? Border.all(color: const Color(0xFFD6D6D6), width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: waiting
                    ? Text('?',
                        style: nunito(22,
                            weight: FontWeight.w700,
                            color: const Color(0xFFB0B0B0)))
                    : Emoji(emoji, size: 38),
              ),
              if (ok)
                const Positioned(
                  right: 0,
                  bottom: 2,
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.switchGreen, size: 18),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: nunito(12,
                weight: FontWeight.w600,
                color: waiting ? AppColors.sub : AppColors.selectBlue)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 90,
            child: widget.ready
                ? const Emoji('🎉', size: 64)
                : AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final a = _c.value * 2 * math.pi;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final w in [80.0, 60.0])
                                Container(
                                  width: w,
                                  height: 16,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6E7FF3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                          Transform.translate(
                            offset: Offset(22 * math.cos(a), 14 * math.sin(a)),
                            child: const Icon(Icons.search_rounded,
                                size: 40, color: Color(0xFFF5B400)),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Text(
              tr(context, widget.ready ? 'readyToDraw' : 'findingBuddies'),
              style: nunito(18,
                  weight: FontWeight.w800, color: AppColors.selectBlue)),
          const SizedBox(height: 6),
          Text(widget.ready ? '2/2 ${tr(context, 'readyWord')}' : '1/2 ${tr(context, 'readyWord')}',
              style: nunito(14, weight: FontWeight.w600, color: AppColors.textSoft)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _player(kAvatars[s.avatarIndex % kAvatars.length],
                  tr(context, 'you'), true),
              const SizedBox(width: 26),
              widget.ready
                  ? _player(
                      kAvatars[(widget.partnerAvatar ?? 0) % kAvatars.length],
                      widget.partnerName ?? '',
                      true)
                  : _player('', tr(context, 'waiting'), false, waiting: true),
            ],
          ),
          const SizedBox(height: 18),
          if (!widget.ready)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDADADA)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onCancel,
                child: Text(tr(context, 'cancel'),
                    style: nunito(16,
                        weight: FontWeight.w700, color: AppColors.selectBlue)),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.template, required this.seconds});
  final DtTemplate template;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 170,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E6E6), width: 1.5),
            ),
            child: DtTemplatePicture(template: template),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.selectBlue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(tr(context, 'startingIn', {'n': '${math.max(1, seconds)}'}),
                    style: nunito(14,
                        weight: FontWeight.w700, color: AppColors.selectBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Both drawings of a template, finished colours (used on cards).
class DtTemplatePicture extends StatelessWidget {
  const DtTemplatePicture({super.key, required this.template});
  final DtTemplate template;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PairPreviewPainter(template), size: Size.infinite);
}

class _PairPreviewPainter extends CustomPainter {
  _PairPreviewPainter(this.t);
  final DtTemplate t;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width / 2, size.height) * 1.08;
    final top = (size.height - side) / 2;
    final left = size.width / 2 - side;
    paintTraceArtAt(canvas, Rect.fromLTWH(left + side * 0.06, top, side, side), t.leftArt);
    paintTraceArtAt(canvas, Rect.fromLTWH(size.width / 2 - side * 0.06, top, side, side), t.rightArt);
  }

  @override
  bool shouldRepaint(covariant _PairPreviewPainter old) => old.t != t;
}

// ================================================================ painter
/// Gap-free distance between the two drawings on the shared canvas.
const double kDtGap = 1.06;

class _DtPainter extends CustomPainter {
  _DtPainter({
    required this.session,
    required this.strokes,
    required this.partnerStrokes,
    required this.myOff,
    required this.partnerOff,
    required this.cursor,
    required this.cursorEmoji,
    required this.step,
    required this.scale,
    required this.offset,
  });
  final DtSession session;
  final List<BStroke> strokes;
  final List<BStroke> partnerStrokes;
  final Offset myOff;
  final Offset partnerOff;
  final Offset? cursor; // partner pen, in their drawing's units
  final String cursorEmoji;
  final int? step;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    // Partner's drawing (live), then mine.
    canvas.save();
    canvas.translate(partnerOff.dx, partnerOff.dy);
    paintDtDrawing(
        canvas, session.partnerArt, session.partnerSteps, partnerStrokes);
    canvas.restore();
    canvas.save();
    canvas.translate(myOff.dx, myOff.dy);
    paintDtDrawing(canvas, session.myArt, session.mySteps, strokes,
        checkerStep: step);
    canvas.restore();
    canvas.restore();

    // Partner's avatar riding on their pen.
    final c = cursor;
    if (c != null) {
      final p = offset + (c + partnerOff) * scale;
      canvas.drawCircle(p, 17, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          17,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF3A8EF0));
      final tp = TextPainter(
        text: TextSpan(text: cursorEmoji, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// PNG of the shared picture (used by Save / Share on the result page).
Future<Uint8List> renderDtPng(DtSession s, List<BStroke> mine,
    SeatState partner, int size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final side = size.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = Colors.white);
  paintDtPair(canvas, side,
      session: s, myStrokes: mine, partnerStrokes: partner.strokes);
  final img = await rec.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}


// ================================================================ tiles
/// "You" and the partner, like the reference app's camera tiles (camera is
/// off: avatar, name and "Not on camera"). The chevron folds them away.
class _PlayerTiles extends StatelessWidget {
  const _PlayerTiles({
    required this.open,
    required this.myAvatar,
    required this.partner,
    required this.partnerDone,
    required this.onToggle,
  });
  final bool open;
  final int myAvatar;
  final BattlePlayer partner;
  final bool partnerDone;
  final VoidCallback onToggle;

  Widget _tile(BuildContext context, int avatar, String name, bool me) {
    return Container(
      width: 72,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Emoji(kAvatars[avatar % kAvatars.length], size: 34),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nunito(11, weight: FontWeight.w700)),
          if (me)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.videocam_off_outlined,
                  size: 14, color: Color(0xFF3A3A3A)),
            )
          else
            Text(
                partnerDone
                    ? tr(context, 'doneWord')
                    : tr(context, 'notOnCamera'),
                style: nunito(9,
                    weight: FontWeight.w600,
                    color: partnerDone
                        ? AppColors.switchGreen
                        : const Color(0xFF9A9A9A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (open) ...[
              _tile(context, myAvatar, tr(context, 'you'), true),
              _tile(context, partner.avatar, partner.name, false),
            ],
            const Spacer(),
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                    color: Color(0xFFF2F3F5), shape: BoxShape.circle),
                child: Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF3A3A3A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ finding
/// "Finding buddies..." page: the picture (with Change), its name,
/// 👥2 · N steps, You · host and the empty partner slot, and the mascot.
class _FindingPage extends StatefulWidget {
  const _FindingPage({
    required this.template,
    required this.joining,
    required this.onBack,
    required this.onChange,
  });
  final DtTemplate template;
  final bool joining;
  final VoidCallback onBack;
  final VoidCallback? onChange;

  @override
  State<_FindingPage> createState() => _FindingPageState();
}

class _FindingPageState extends State<_FindingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = widget.template;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: BackCircle(onTap: widget.onBack),
            ),
          ),
          const SizedBox(height: 18),
          Text(
              tr(context,
                  widget.joining ? 'joiningRoom' : 'findingBuddiesTitle'),
              style: nunito(22,
                  weight: FontWeight.w800, color: const Color(0xFF3A8EF0))),
          const SizedBox(height: 16),
          Container(
            width: 230,
            height: 230,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ArtSlot(
                    asset: 'tpl_${t.id}.png',
                    fallback: DtTemplatePicture(template: t),
                  ),
                ),
                if (widget.onChange != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ChangeChip(onTap: widget.onChange!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!widget.joining) ...[
            Text(dtTemplateName(t),
                style: nunito(15,
                    weight: FontWeight.w700, color: const Color(0xFF3A3A3A))),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PlayersBadge(),
                const SizedBox(width: 8),
                Text(tr(context, 'stepsCount', {'n': '${dtTotalSteps(t)}'}),
                    style: nunito(13,
                        weight: FontWeight.w600, color: AppColors.textSoft)),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  RingAvatar(avatar: app.avatarIndex, size: 62),
                  const SizedBox(height: 4),
                  Text(tr(context, 'youHost'),
                      style: nunito(12,
                          weight: FontWeight.w700,
                          color: const Color(0xFF1677FF))),
                ],
              ),
              const SizedBox(width: 30),
              Column(
                children: [
                  FadeTransition(
                    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
                    child: const RingAvatar(avatar: null, size: 62),
                  ),
                  const SizedBox(height: 4),
                  Text('Guest',
                      style: nunito(12,
                          weight: FontWeight.w700, color: AppColors.sub)),
                ],
              ),
            ],
          ),
          // Takes the leftover height (shrinks on short screens, no overflow).
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(0, -8 * _c.value), child: child),
                  child: const ArtSlot(
                    asset: 'mascot.png',
                    fallback: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Emoji('🐶', size: 96),
                        Positioned(
                            right: -18, bottom: 6, child: Emoji('🖌️', size: 40)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// White rounded holder for toolbar groups (undo | redo, brush size).
class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
