import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../battle/battle_data.dart' show BStroke;
import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/trace_catalog.dart';
import '../core/trace_steps.dart';
import '../widgets/celebration.dart';
import '../widgets/draw_kit.dart';
import '../core/sound.dart';

/// What the drawing page returns when the picture is finished.
class TraceResult {
  TraceResult({
    required this.item,
    required this.png,
    required this.points,
    required this.lines,
    required this.seconds,
  });
  final TraceItem item;
  final Uint8List png;
  final int points;
  final int lines;
  final int seconds;
}

class _Mark {
  _Mark(this.stroke, this.step);
  final BStroke stroke;
  final int step;
}

/// Trace Art drawing page, same flow as the reference app:
/// * each step zooms to its area;
/// * outline steps show a blinking grey line to trace;
/// * colour steps show a checkerboard region to paint (paint stays inside);
/// * the green bar fills as you cover the step, → turns blue once you draw;
/// * → shows a praise sticker and moves to the next step;
/// * after the last step the result page opens.
class TraceCanvasScreen extends StatefulWidget {
  const TraceCanvasScreen({super.key, required this.item});
  final TraceItem item;

  @override
  State<TraceCanvasScreen> createState() => _TraceCanvasScreenState();
}

class _TraceCanvasScreenState extends State<TraceCanvasScreen>
    with TickerProviderStateMixin {
  late final List<TraceStep> _steps = buildTraceSteps(widget.item);
  int _step = 0;

  List<_Mark> _marks = [];
  final List<List<_Mark>> _undo = [];
  final List<List<_Mark>> _redo = [];
  _Mark? _current;

  late CoverageTracker _tracker = CoverageTracker(_steps[0]);
  double get _coverage => _tracker.fraction;
  final List<double> _stepScores = [];

  final List<Color> _palette = [...kDrawColors];
  Color _color = kDrawColors.first;
  double _width = 0.014;
  bool _eraser = false;

  Praise? _praise;
  bool _busy = false;
  final GlobalKey _menuKey = GlobalKey();
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _toastTimer;
  String? _toast;

  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);
  late final AnimationController _cam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  static const Rect _full = Rect.fromLTWH(-0.04, -0.04, 1.08, 1.08);
  Rect _camFrom = _full;
  Rect _camTo = _full;

  TraceStep get _cur => _steps[_step];
  bool get _hasInk =>
      _marks.any((m) => m.step == _step && !m.stroke.erase);

  @override
  void initState() {
    super.initState();
    // Start with the whole picture, then zoom into the first step.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _moveCamera();
    });
  }

  @override
  void dispose() {
    _blink.dispose();
    _cam.dispose();
    _toastTimer?.cancel();
    super.dispose();
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

  /// scale (px per art unit) and offset for a canvas of [size].
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

  void _start(Offset p) {
    if (_busy) return;
    _snapshot();
    final m = _Mark(
        BStroke(_color, _eraser ? _width * 1.8 : _width,
            erase: _eraser, points: [p]),
        _step);
    setState(() {
      _marks = [..._marks, m];
      _current = m;
      _tracker.addSegment(p, p, m.stroke.width, erase: m.stroke.erase);
    });
  }

  void _update(Offset p) {
    final m = _current;
    if (m == null) return;
    final prev = m.stroke.points.last;
    setState(() {
      m.stroke.points.add(p);
      _tracker.addSegment(prev, p, m.stroke.width, erase: m.stroke.erase);
    });
  }

  void _end() {
    _current = null;
  }

  void _recompute() {
    setState(() => _tracker = CoverageTracker.from(
        _cur, _marks.where((m) => m.step == _step).map((m) => m.stroke)));
  }

  void _undoAction() {
    if (_undo.isEmpty || _busy) return;
    setState(() {
      _redo.add(_marks);
      _marks = _undo.removeLast();
    });
    _recompute();
  }

  void _redoAction() {
    if (_redo.isEmpty || _busy) return;
    setState(() {
      _undo.add(_marks);
      _marks = _redo.removeLast();
    });
    _recompute();
  }

  /// Broom: clears what was drawn in the current step.
  Future<void> _clearStep() async {
    if (!_marks.any((m) => m.step == _step) || _busy) return;
    final ok = await showClearStepDialog(context);
    if (!ok || !mounted || _busy) return;
    _snapshot();
    setState(() => _marks = _marks.where((m) => m.step != _step).toList());
    _recompute();
  }

  // ------------------------------------------------------------ steps
  Future<void> _next() async {
    if (!_hasInk || _busy) return;
    final need = _cur.isOutline ? 0.55 : 0.45;
    if (_coverage < need) {
      Sound.instance.play(Sfx.oops);
      _showToast(_cur.isOutline ? 'strokeWrong' : 'colorMore');
      return;
    }
    final s = AppScope.read(context);
    s.tap();
    _stepScores.add(_coverage);
    final last = _step == _steps.length - 1;
    setState(() {
      _busy = true;
      _praise = last ? kFinalPraise : kStepPraise[_step % kStepPraise.length];
      Sound.instance.play(last ? Sfx.finish : Sfx.praise);
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (last) {
      try {
        await _finish();
      } catch (_) {
        if (mounted) {
          setState(() {
            _busy = false;
            _praise = null;
          });
          _showToast('saveFailed');
        }
      }
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
        // Colour step: suggest the region's colour and a thicker brush.
        final c = _cur.color!;
        _palette
          ..remove(c)
          ..insert(0, c);
        _color = c;
        _eraser = false;
        if (_steps[_step - 1].isOutline) _width = 0.05;
      }
    });
    _moveCamera();
  }

  void _showToast(String key) {
    _toastTimer?.cancel();
    setState(() => _toast = tr(context, key));
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _finish() async {
    final s = AppScope.read(context);
    final png = await _renderPng(900);
    final lines = _marks
        .where((m) => !m.stroke.erase && _steps[m.step].isOutline)
        .length;
    final avg = _stepScores.isEmpty
        ? 0.0
        : _stepScores.reduce((a, b) => a + b) / _stepScores.length;
    final points = (avg * 100).round().clamp(10, 100);

    // Save to My album.
    String? path;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      path = 'album_$id.png';
      await File('${dir.path}/$path').writeAsBytes(png);
    } catch (_) {}
    s.addToAlbum(widget.item.id, const [], imagePath: path);
    s.completeLesson();

    if (!mounted) return;
    Navigator.of(context).pop(TraceResult(
      item: widget.item,
      png: png,
      points: points,
      lines: lines,
      seconds: _clock.elapsed.inSeconds,
    ));
  }

  Future<Uint8List> _renderPng(int size) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final sz = size.toDouble();
    canvas.drawRect(Rect.fromLTWH(0, 0, sz, sz), Paint()..color = Colors.white);
    canvas.scale(sz);
    _paintLayers(canvas, _steps, _marks, checkerFor: null);
    final img = await rec.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  // ------------------------------------------------------------ menu
  Future<void> _askLeave() async {
    final quit = await showLeaveDialog(context);
    if (quit && mounted) Navigator.of(context).pop(true);
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
    final stepHasUndo = _undo.isNotEmpty;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && !_busy) _askLeave();
      },
      child: Scaffold(
        backgroundColor: kDrawTopBg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // -------------------------------- toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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
                            enabled: stepHasUndo,
                            onTap: _undoAction),
                        const SizedBox(width: 10),
                        DrawCircleBtn(
                            icon: Icons.redo_rounded,
                            enabled: _redo.isNotEmpty,
                            onTap: _redoAction),
                        const Spacer(),
                        DrawNextBtn(enabled: _hasInk && !_busy, onTap: _next),
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
                          onPanStart: (d) => _start(norm(d.localPosition)),
                          onPanUpdate: (d) => _update(norm(d.localPosition)),
                          onPanEnd: (_) => _end(),
                          onPanCancel: _end,
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_blink, _cam]),
                              builder: (_, __) {
                                final (s, off) = _transform(size);
                                return CustomPaint(
                                  size: size,
                                  painter: _TracePainter(
                                    steps: _steps,
                                    marks: _marks,
                                    step: _step,
                                    scale: s,
                                    offset: off,
                                    blink: _blink.value,
                                    showGuide: !_busy,
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
                  top: 112,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDADADA)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 6)
                        ],
                      ),
                      child: Text(_toast!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF3A3A3A))),
                    ),
                  ),
                ),
              if (_praise != null)
                Positioned.fill(
                    child: CelebrationOverlay(
                        key: ValueKey(_step), praise: _praise!)),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================ widgets
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

// ================================================================ painting
void _drawStroke(Canvas canvas, BStroke s) {
  if (s.points.isEmpty) return;
  final paint = Paint()
    ..color = s.color
    ..strokeWidth = s.width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;
  if (s.points.length == 1) {
    canvas.drawCircle(
        s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
    return;
  }
  final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
  for (var i = 1; i < s.points.length; i++) {
    path.lineTo(s.points[i].dx, s.points[i].dy);
  }
  canvas.drawPath(path, paint);
}

void _drawChecker(Canvas canvas, Path region, double opacity) {
  final b = region.getBounds();
  const cell = 0.028;
  canvas.save();
  canvas.clipPath(region);
  canvas.drawRect(b, Paint()..color = Colors.white);
  final grey = Paint()
    ..color = const Color(0xFFBDBDBD).withOpacity(opacity);
  var row = 0;
  for (var y = b.top; y < b.bottom; y += cell, row++) {
    var col = 0;
    for (var x = b.left; x < b.right; x += cell, col++) {
      if ((row + col).isEven) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), grey);
      }
    }
  }
  canvas.restore();
}

/// Paint layer (colour, clipped per region) under the outline layer.
/// Canvas must already be in 0..1 art units.
void _paintLayers(Canvas canvas, List<TraceStep> steps, List<_Mark> marks,
    {int? checkerFor}) {
  const big = Rect.fromLTWH(-1, -1, 3, 3);

  if (checkerFor != null) {
    for (var i = checkerFor; i < steps.length; i++) {
      final r = steps[i].region;
      if (r != null) _drawChecker(canvas, r, i == checkerFor ? 0.75 : 0.35);
    }
  }

  // Colour paint, each stroke kept inside its region.
  canvas.saveLayer(big, Paint());
  for (var i = 0; i < steps.length; i++) {
    final r = steps[i].region;
    if (r == null) continue;
    final mine = marks.where((m) => m.step == i);
    if (mine.isEmpty) continue;
    canvas.save();
    canvas.clipPath(r);
    for (final m in mine) {
      _drawStroke(canvas, m.stroke);
    }
    canvas.restore();
  }
  canvas.restore();

  // The player's outline lines on top.
  canvas.saveLayer(big, Paint());
  for (final m in marks) {
    if (steps[m.step].isOutline) _drawStroke(canvas, m.stroke);
  }
  canvas.restore();
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.steps,
    required this.marks,
    required this.step,
    required this.scale,
    required this.offset,
    required this.blink,
    required this.showGuide,
  });

  final List<TraceStep> steps;
  final List<_Mark> marks;
  final int step;
  final double scale;
  final Offset offset;
  final double blink;
  final bool showGuide;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final cur = steps[step];
    _paintLayers(canvas, steps, marks, checkerFor: cur.isOutline ? null : step);

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
