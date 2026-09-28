import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../battle/battle_art.dart';
import '../../battle/battle_data.dart';
import '../../battle/battle_service.dart';
import '../../core/app_state.dart';
import '../../core/sound.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/trace_steps.dart';
import '../../widgets/celebration.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_kit.dart';
import 'battle_result_screen.dart';

/// Art Battle round, same flow as the reference app:
/// * the tiles at the top show every player's drawing live, with a progress
///   bar in their colour under each tile;
/// * you trace your picture step by step (outline steps, then colour steps
///   with a checkerboard), the camera zooming to each step;
/// * → gives a praise sticker and moves on; after the last step you wait:
///   → stays grey and says "Other users haven't finished";
/// * when everyone is done → turns blue and opens "YOU ARE 1st!".
class BattleGameScreen extends StatefulWidget {
  const BattleGameScreen({super.key, required this.match});
  final MatchInfo match;

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen>
    with TickerProviderStateMixin {
  late final BattleTemplate _template = templateById(widget.match.templateId);
  late final int _me = widget.match.mySeat;
  late final String _myItem = _template.itemFor(_me);
  late final List<TraceStep> _steps = battleSteps(_myItem);
  int _step = 0;

  /// My strokes; each stroke's tag is the step it was drawn in.
  List<BStroke> _marks = [];
  final List<List<BStroke>> _undo = [];
  final List<List<BStroke>> _redo = [];
  BStroke? _current;

  late CoverageTracker _tracker = CoverageTracker(_steps[0]);
  final List<double> _stepScores = [];

  final List<Color> _palette = [...kDrawColors];
  Color _color = kDrawColors.first;
  double _width = 0.014;
  bool _eraser = false;

  Praise? _praise;
  bool _busy = false;
  final GlobalKey _menuKey = GlobalKey();
  Timer? _toastTimer;
  String? _toast;
  bool _toastPeople = false;

  // ------------------------------------------------------------ players
  final Map<int, SeatState> _seats = {};
  final Map<int, BattleBot> _bots = {};
  StreamSubscription? _roomSub;
  Timer? _tick;
  Timer? _autoOpen;
  bool _finished = false; // I finished all my steps
  bool _allDone = false; // everyone finished (or left)
  bool _showingResults = false;
  int _myFinishedAt = 0;

  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);
  late final AnimationController _cam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  static const Rect _full = Rect.fromLTWH(-0.04, -0.04, 1.08, 1.08);
  Rect _camFrom = _full;
  Rect _camTo = _full;

  BattleService get _svc => BattleService.instance;
  TraceStep get _cur => _steps[_step];
  bool get _hasInk => _marks.any((m) => m.tag == _step && !m.erase);
  double get _coverage => _finished ? 1 : _tracker.fraction;

  /// How long we wait for a stuck online player after finishing.
  static const int _maxWaitMs = 4 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    for (final p in widget.match.players) {
      _seats[p.seat] = SeatState();
      if (p.bot && p.seat != _me) {
        _bots[p.seat] = BattleBot(
            roomId: widget.match.roomId,
            seat: p.seat,
            itemId: _template.itemFor(p.seat));
      }
    }
    if (widget.match.online) {
      _roomSub = _svc.watchRoom(widget.match.roomId).listen((remote) {
        if (!mounted) return;
        setState(() {
          remote.forEach((seat, st) {
            if (seat == _me || _bots.containsKey(seat)) return;
            _seats[seat] = st;
          });
        });
        _checkAllDone();
      });
      _svc.sendState(widget.match.roomId, _me, _myState());
    }
    _tick = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      if (_bots.isNotEmpty) {
        final elapsed = _svc.now() - widget.match.startAt;
        setState(() {
          _bots.forEach((seat, bot) {
            final st = SeatState();
            bot.update(st, elapsed, widget.match.startAt);
            _seats[seat] = st;
          });
        });
      }
      _checkAllDone();
    });
    // Start on the whole picture, then zoom into the first step.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _moveCamera();
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _tick?.cancel();
    _autoOpen?.cancel();
    _progressTimer?.cancel();
    _toastTimer?.cancel();
    _blink.dispose();
    _cam.dispose();
    _pulse.dispose();
    super.dispose();
  }

  SeatState _myState() {
    final st = SeatState()
      ..step = _finished ? _steps.length : _step
      ..progress = _finished ? 1 : _tracker.fraction
      ..finished = _finished
      ..finishedAt = _myFinishedAt
      ..accuracy = _avgScore();
    st.strokes.addAll(_marks);
    return st;
  }

  double _avgScore() => _stepScores.isEmpty
      ? 0
      : _stepScores.reduce((a, b) => a + b) / _stepScores.length;

  void _showToast(String key, {bool people = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toast = tr(context, key);
      _toastPeople = people;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ------------------------------------------------------------ camera
  Rect _viewFor(TraceStep s) {
    var r = s.bounds;
    final pad = math.max(0.06, 0.18 * math.max(r.width, r.height));
    r = r.inflate(pad);
    const minSide = 0.42;
    if (r.width < minSide || r.height < minSide) {
      r = Rect.fromCenter(
          center: r.center,
          width: math.max(r.width, minSide),
          height: math.max(r.height, minSide));
    }
    return r;
  }

  void _moveCamera() {
    _camFrom = _currentView;
    _camTo = _viewFor(_cur);
    _cam.forward(from: 0);
  }

  Rect get _currentView {
    final t = Curves.easeInOutCubic.transform(_cam.value);
    return Rect.lerp(_camFrom, _camTo, t)!;
  }

  (double, Offset) _transform(Size size) {
    final v = _currentView;
    final s = math.min(size.width / v.width, size.height / v.height);
    final off = size.center(Offset.zero) - v.center * s;
    return (s, off);
  }

  // ------------------------------------------------------------ drawing
  void _snapshot() {
    _undo.add(List.of(_marks));
    _redo.clear();
  }

  void _onStart(Offset p) {
    if (_busy || _showingResults) return;
    _snapshot();
    final m = BStroke(_color, _eraser ? _width * 1.8 : _width,
        erase: _eraser, tag: _step, points: [p]);
    setState(() {
      _marks = [..._marks, m];
      _current = m;
      _tracker.addSegment(p, p, m.width, erase: m.erase);
    });
  }

  void _onUpdate(Offset p) {
    final m = _current;
    if (m == null) return;
    final prev = m.points.last;
    setState(() {
      m.points.add(p);
      _tracker.addSegment(prev, p, m.width, erase: m.erase);
    });
    _sendProgressSoon();
  }

  void _onEnd() {
    final m = _current;
    _current = null;
    if (m == null || !widget.match.online) return;
    _svc.sendStroke(widget.match.roomId, _me, m);
    _sendProgressSoon();
  }

  /// Sends my bar (current step progress) to the other players, at most
  /// every 400 ms while drawing — it can go down as well as up.
  Timer? _progressTimer;
  double _sentProgress = -1;
  void _sendProgressSoon() {
    if (!widget.match.online || _progressTimer != null) return;
    _progressTimer = Timer(const Duration(milliseconds: 400), () {
      _progressTimer = null;
      if (!mounted) return;
      final f = _finished ? 1.0 : _tracker.fraction;
      if ((f - _sentProgress).abs() < 0.01) return;
      _sentProgress = f;
      _svc.sendState(widget.match.roomId, _me, _myState());
    });
  }

  void _syncAll() {
    if (!widget.match.online) return;
    _svc.setStrokes(widget.match.roomId, _me, _marks);
    _svc.sendState(widget.match.roomId, _me, _myState());
  }

  void _recompute() {
    setState(() => _tracker = CoverageTracker.from(
        _cur, _marks.where((m) => m.tag == _step)));
  }

  void _undoAction() {
    if (_undo.isEmpty || _busy) return;
    setState(() {
      _redo.add(_marks);
      _marks = _undo.removeLast();
    });
    _recompute();
    _syncAll();
  }

  void _redoAction() {
    if (_redo.isEmpty || _busy) return;
    setState(() {
      _undo.add(_marks);
      _marks = _redo.removeLast();
    });
    _recompute();
    _syncAll();
  }

  /// Broom: "Clear This Step" dialog, then clears what was drawn in it.
  Future<void> _clearStep() async {
    if (!_marks.any((m) => m.tag == _step) || _busy) return;
    final ok = await showClearStepDialog(context);
    if (!ok || !mounted || _busy) return;
    _snapshot();
    setState(() => _marks = _marks.where((m) => m.tag != _step).toList());
    _recompute();
    _syncAll();
  }

  // ------------------------------------------------------------ steps
  void _onNextTap() {
    if (_showingResults || _busy) return;
    if (_finished) {
      if (_allDone) {
        AppScope.read(context).tap();
        _openResults();
      } else {
        AppScope.read(context).tap();
        _showToast('othersNotFinished', people: true);
      }
      return;
    }
    if (_hasInk) _next();
  }

  Future<void> _next() async {
    final need = _cur.isOutline ? 0.55 : 0.45;
    if (_tracker.fraction < need) {
      Sound.instance.play(Sfx.oops);
      _showToast(_cur.isOutline ? 'strokeWrong' : 'colorMore');
      return;
    }
    AppScope.read(context).tap();
    _stepScores.add(_tracker.fraction);
    final last = _step == _steps.length - 1;
    setState(() {
      _busy = true;
      _praise = last ? kFinalPraise : kStepPraise[_step % kStepPraise.length];
    });
    Sound.instance.play(last ? Sfx.finish : Sfx.praise);
    if (last) {
      setState(() {
        _finished = true;
        _myFinishedAt = _svc.now();
      });
      AppScope.read(context).completeLesson();
    }
    if (widget.match.online) {
      _svc.sendState(widget.match.roomId, _me, _myState());
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (last) {
      setState(() {
        _praise = null;
        _busy = false;
        _undo.clear();
        _redo.clear();
      });
      _checkAllDone();
      if (!_allDone) _showToast('othersNotFinished', people: true);
      return;
    }
    setState(() {
      _praise = null;
      _busy = false;
      _step++;
      _tracker = CoverageTracker(_steps[_step]);
      _undo.clear();
      _redo.clear();
      if (!_cur.isOutline) {
        final c = _cur.color!;
        _palette
          ..remove(c)
          ..insert(0, c);
        _color = c;
        _eraser = false;
        if (_steps[_step - 1].isOutline) _width = 0.05;
      }
    });
    if (widget.match.online) {
      _svc.sendState(widget.match.roomId, _me, _myState());
    }
    _moveCamera();
  }

  // ------------------------------------------------------------ finishing
  void _checkAllDone() {
    if (!_finished || _allDone || _showingResults) return;
    final waitedTooLong = _svc.now() - _myFinishedAt > _maxWaitMs;
    final others = widget.match.players.where((p) => p.seat != _me);
    final done = others.every((p) {
      final st = _seats[p.seat];
      return st != null && (st.finished || st.left);
    });
    if (!done && !waitedTooLong) return;
    setState(() => _allDone = true);
    Sound.instance.play(Sfx.match);
    _pulse.repeat(reverse: true);
    _showToast('allFinishedTap');
    // If nobody taps →, open the results anyway after a while.
    _autoOpen = Timer(const Duration(seconds: 10), () {
      if (mounted) _openResults();
    });
  }

  Future<void> _openResults() async {
    if (_showingResults) return;
    _showingResults = true;
    _autoOpen?.cancel();
    _pulse.stop();
    _seats[_me] = _myState();
    final snapshot = Map<int, SeatState>.from(_seats);
    final s = AppScope.read(context);
    final nav = Navigator.of(context);
    final route = ModalRoute.of(context);

    Uint8List? png;
    try {
      png = await renderBattlePicture(_template, widget.match.players, snapshot,
          size: 900);
      final dir = await getApplicationDocumentsDirectory();
      final name = 'album_${DateTime.now().microsecondsSinceEpoch}.png';
      await File('${dir.path}/$name').writeAsBytes(png);
      s.addToAlbum(_myItem, const [], imagePath: name);
    } catch (_) {}
    if (!mounted) return;

    // Rank: whoever finished first wins; players who left come last.
    int key(BattlePlayer p) {
      final st = snapshot[p.seat] ?? SeatState();
      if (st.finished && !st.left) return st.finishedAt;
      return 0x3FFFFFFFFFFFF - st.step; // 2^50-1 (safe on web too)
    }

    final ranked = [...widget.match.players]
      ..sort((a, b) => key(a).compareTo(key(b)));
    final myRank = ranked.indexWhere((p) => p.seat == _me) + 1;
    final points = (_avgScore() * 100).round().clamp(10, 100);
    final lines = _marks.where((m) => !m.erase).length;
    final seconds = ((_svc.now() - widget.match.startAt) / 1000).round();

    nav.popUntil((r) => r == route);
    nav.pushReplacement(fadeRoute(BattleResultScreen(
      match: widget.match,
      seats: snapshot,
      png: png,
      rank: myRank,
      points: points,
      lines: lines,
      seconds: math.max(0, seconds),
    )));
  }

  // ------------------------------------------------------------ menu
  Future<void> _askLeave() async {
    final quit = await showLeaveDialog(context);
    if (!quit || !mounted) return;
    if (widget.match.online) await _svc.leave(widget.match.roomId, _me);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openMenu() async {
    final s = AppScope.read(context);
    final action = await showDrawMenu(context, _menuKey);
    if (!mounted || action == null) return;
    switch (action) {
      case DrawMenuAction.sound:
        s.setSoundFx(!s.soundFx);
        s.setMusic(s.soundFx);
        s.tap();
        break;
      case DrawMenuAction.exit:
        await _askLeave();
        break;
    }
  }

  Future<void> _pickColor() async {
    AppScope.read(context).tap();
    final c = await showColorPicker(context, _color);
    if (c == null || !mounted) return;
    setState(() {
      if (!_palette.contains(c)) _palette.insert(0, c);
      _color = c;
      _eraser = false;
    });
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final nextLooksOn = _finished ? _allDone : (_hasInk && !_busy);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && !_busy && !_showingResults) _askLeave();
      },
      child: Scaffold(
        backgroundColor: kDrawTopBg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // -------------------------------- player tiles
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final p in widget.match.players) _tile(p),
                      ],
                    ),
                  ),
                  // -------------------------------- toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: [
                        DrawSquareBtn(
                            key: _menuKey,
                            icon: Icons.notes_rounded,
                            onTap: _openMenu),
                        const SizedBox(width: 12),
                        DrawCircleBtn(
                            icon: Icons.cleaning_services_rounded,
                            outlined: true,
                            onTap: _clearStep),
                        const SizedBox(width: 10),
                        DrawCircleBtn(
                            icon: Icons.undo_rounded,
                            enabled: _undo.isNotEmpty && !_busy,
                            onTap: _undoAction),
                        const SizedBox(width: 10),
                        DrawCircleBtn(
                            icon: Icons.redo_rounded,
                            enabled: _redo.isNotEmpty && !_busy,
                            onTap: _redoAction),
                        const Spacer(),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onNextTap,
                          child: AbsorbPointer(
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, child) => Transform.scale(
                                  scale: _allDone
                                      ? 1 + 0.07 * _pulse.value
                                      : 1,
                                  child: child),
                              child: DrawNextBtn(
                                  enabled: nextLooksOn, onTap: () {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: _StepBar(
                        fraction: _coverage,
                        step: _step + 1,
                        total: _steps.length),
                  ),
                  // -------------------------------- canvas
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: LayoutBuilder(builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        Offset norm(Offset p) {
                          final (s, off) = _transform(size);
                          return (p - off) / s;
                        }

                        return GestureDetector(
                          onPanStart: (d) => _onStart(norm(d.localPosition)),
                          onPanUpdate: (d) => _onUpdate(norm(d.localPosition)),
                          onPanEnd: (_) => _onEnd(),
                          onPanCancel: _onEnd,
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_blink, _cam]),
                              builder: (_, __) {
                                final (s, off) = _transform(size);
                                return CustomPaint(
                                  size: size,
                                  painter: _CanvasPainter(
                                    steps: _steps,
                                    marks: _marks,
                                    step: _step,
                                    scale: s,
                                    offset: off,
                                    blink: _blink.value,
                                    showGuide: !_busy && !_finished,
                                    checker: !_finished,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // -------------------------------- brush + colours
                  Container(
                    color: kDrawBottomBg,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: [
                        BrushSizeSlider(
                          value: _width,
                          min: 0.006,
                          max: 0.09,
                          onChanged: (v) => setState(() => _width = v),
                        ),
                        const SizedBox(height: 10),
                        DrawColorBar(
                          color: _color,
                          eraser: _eraser,
                          colors: _palette,
                          onEraser: () {
                            AppScope.read(context).tap();
                            setState(() => _eraser = true);
                          },
                          onBrush: () {
                            AppScope.read(context).tap();
                            setState(() => _eraser = false);
                          },
                          onColor: (c) {
                            AppScope.read(context).tap();
                            setState(() {
                              _color = c;
                              _eraser = false;
                            });
                          },
                          onPicker: _pickColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_toast != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 150,
                  child: Center(
                      child: _Toast(text: _toast!, people: _toastPeople)),
                ),
              if (_praise != null)
                Positioned.fill(
                    child: CelebrationOverlay(
                        key: ValueKey('p$_step$_finished'),
                        praise: _praise!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BattlePlayer p) {
    final isMe = p.seat == _me;
    final st = isMe ? null : _seats[p.seat];
    final item = _template.itemFor(p.seat);
    final total = battleSteps(item).length;
    final strokes = isMe ? _marks : (st?.strokes ?? const <BStroke>[]);
    final progress = isMe
        ? (_finished ? 1.0 : (_step + _tracker.fraction) / total)
        : (st == null
            ? 0.0
            : (st.finished ? 1.0 : (st.step + st.progress) / total));
    final color = kSeatColors[p.seat % kSeatColors.length];
    final label = isMe ? tr(context, 'you') : '${p.seat + 1}';
    const side = 66.0;
    return SizedBox(
      width: side + 10,
      child: Column(
        children: [
          SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2.6),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      size: const Size.square(side - 13),
                      painter: BattleDrawingPainter(item, strokes,
                          version: strokes.length * 100000 +
                              (strokes.isEmpty
                                  ? 0
                                  : strokes.last.points.length)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(label,
                        style: nunito(9,
                            weight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                if (st != null && st.left)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(Icons.logout_rounded,
                        size: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          _SeatBar(fraction: progress, color: color),
        ],
      ),
    );
  }
}

// ================================================================ picture
/// All players' drawings together (2x2 for 4 players, side by side for 2),
/// as a PNG — used on the result page, for Save / Share and My album.
Future<Uint8List> renderBattlePicture(BattleTemplate t,
    List<BattlePlayer> players, Map<int, SeatState> seats,
    {int size = 900}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final w = size;
  final h = players.length > 2 ? size : (size / 1.6).round();
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = Colors.white);
  paintBattlePicture(canvas, Size(w.toDouble(), h.toDouble()), t, players, seats);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void paintBattlePicture(Canvas canvas, Size size, BattleTemplate t,
    List<BattlePlayer> players, Map<int, SeatState> seats) {
  final w = size.width, h = size.height;
  final line = Paint()
    ..color = const Color(0xFF3A3A3A)
    ..strokeWidth = math.max(1, w * 0.003);
  final four = players.length > 2;
  for (final p in players) {
    final col = four ? p.seat % 2 : p.seat;
    final row = four ? p.seat ~/ 2 : 0;
    final cellW = w / 2;
    final cellH = four ? h / 2 : h;
    final rect = Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH)
        .deflate(math.min(cellW, cellH) * 0.05);
    paintBattleDrawingAt(canvas, rect, t.itemFor(p.seat),
        seats[p.seat]?.strokes ?? const <BStroke>[]);
  }
  canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), line);
  if (four) canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), line);
}

// ================================================================ widgets
class _SeatBar extends StatelessWidget {
  const _SeatBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      width: 66,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4A4A4A), width: 1.2),
      ),
      padding: const EdgeInsets.all(1.5),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (_, c) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: f == 0 ? 0 : math.max(6, c.maxWidth * f),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text, required this.people});
  final String text;
  final bool people;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (people) ...[
            const Icon(Icons.people_alt_rounded,
                size: 18, color: Color(0xFF8C9EFF)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3A))),
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar(
      {required this.fraction, required this.step, required this.total});
  final double fraction;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (_, c) {
                final f = fraction.clamp(0.0, 1.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: f == 0 ? 0 : math.max(16, c.maxWidth * f),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3DD16B),
                    borderRadius: BorderRadius.circular(9),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3A3A3A), width: 1.2),
          ),
          child: Text('$step/$total',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E))),
        ),
      ],
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.steps,
    required this.marks,
    required this.step,
    required this.scale,
    required this.offset,
    required this.blink,
    required this.showGuide,
    required this.checker,
  });

  final List<TraceStep> steps;
  final List<BStroke> marks;
  final int step;
  final double scale;
  final Offset offset;
  final double blink;
  final bool showGuide;
  final bool checker;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final cur = steps[step];
    paintBattleDrawing(canvas, steps, marks,
        checkerFor: checker && !cur.isOutline ? step : null);
    if (showGuide && cur.isOutline) {
      final path = Path();
      for (final g in cur.lines) {
        if (g.length < 2) continue;
        path.moveTo(g.first.dx, g.first.dy);
        for (final p in g.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = kGuideGrey.withOpacity(0.35 + 0.65 * blink)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.011
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
