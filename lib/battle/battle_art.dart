import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/trace_catalog.dart';
import '../core/trace_steps.dart';
import 'battle_data.dart';
import 'bot_player.dart' show stableHash;

/// Art Battle uses the Trace Art pictures and the same step-by-step flow:
/// outline steps first, then colour steps (up to 5, so rounds are ~9–11
/// steps like the reference app).
const int kBattleColourSteps = 5;

final Map<String, List<TraceStep>> _stepCache = {};

/// Steps for one picture (identical on every phone, so other players'
/// progress can be shown from their step number alone).
List<TraceStep> battleSteps(String itemId) => _stepCache.putIfAbsent(
    itemId,
    () => buildTraceSteps(traceItemById(itemId),
        maxColour: kBattleColourSteps));

// =====================================================================
// Painting (canvas already scaled to 0..1 art units)
// =====================================================================

void _stroke(Canvas canvas, BStroke s) {
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

/// Grey checkerboard inside [region] (the area to paint).
void paintChecker(Canvas canvas, Path region, double opacity) {
  final b = region.getBounds();
  const cell = 0.028;
  canvas.save();
  canvas.clipPath(region);
  canvas.drawRect(b, Paint()..color = Colors.white);
  final grey = Paint()..color = const Color(0xFFBDBDBD).withOpacity(opacity);
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

/// A player's drawing: colour paint (clipped to each colour step's area)
/// under the traced lines. Each stroke's `tag` is the step it belongs to.
/// With [checkerFor], the areas still to paint show a checkerboard.
void paintBattleDrawing(
    Canvas canvas, List<TraceStep> steps, Iterable<BStroke> strokes,
    {int? checkerFor}) {
  const big = Rect.fromLTWH(-1, -1, 3, 3);
  if (checkerFor != null) {
    for (var i = checkerFor; i < steps.length; i++) {
      final r = steps[i].region;
      if (r != null) paintChecker(canvas, r, i == checkerFor ? 0.75 : 0.35);
    }
  }
  canvas.saveLayer(big, Paint());
  for (var i = 0; i < steps.length; i++) {
    final r = steps[i].region;
    if (r == null) continue;
    final mine = strokes.where((s) => s.tag == i);
    if (mine.isEmpty) continue;
    canvas.save();
    canvas.clipPath(r);
    for (final s in mine) {
      _stroke(canvas, s);
    }
    canvas.restore();
  }
  canvas.restore();

  canvas.saveLayer(big, Paint());
  for (final s in strokes) {
    if (s.tag >= 0 && s.tag < steps.length && steps[s.tag].isOutline) {
      _stroke(canvas, s);
    }
  }
  canvas.restore();
}

/// Paints [strokes] of picture [itemId] fitted into [rect].
void paintBattleDrawingAt(
    Canvas canvas, Rect rect, String itemId, Iterable<BStroke> strokes) {
  final side = math.min(rect.width, rect.height);
  canvas.save();
  canvas.translate(rect.left + (rect.width - side) / 2,
      rect.top + (rect.height - side) / 2);
  canvas.scale(side);
  paintBattleDrawing(canvas, battleSteps(itemId), strokes);
  canvas.restore();
}

class BattleDrawingPainter extends CustomPainter {
  BattleDrawingPainter(this.itemId, this.strokes, {this.version = 0});
  final String itemId;
  final List<BStroke> strokes;
  final int version;

  @override
  void paint(Canvas canvas, Size size) =>
      paintBattleDrawingAt(canvas, Offset.zero & size, itemId, strokes);

  @override
  bool shouldRepaint(covariant BattleDrawingPainter old) =>
      old.itemId != itemId ||
      old.version != version ||
      old.strokes.length != strokes.length ||
      !identical(old.strokes, strokes);
}

// =====================================================================
// Computer player
// =====================================================================

/// Deterministic computer opponent. Every phone in the room simulates the
/// same bot from the same seed, so they all see the same progress. It
/// traces each outline step, then scribbles colour into each area.
class BattleBot {
  BattleBot({required String roomId, required this.seat, required this.itemId})
      : _r = math.Random(stableHash(roomId) ^ (seat * 7919)) {
    final steps = battleSteps(itemId);
    // Some bots are quick, some take their time (1.5–4 minutes in total).
    final pace = 0.75 + _r.nextDouble() * 0.9;
    var t = 2000 + _r.nextInt(2500);
    _ink = const [
      Color(0xFF111111),
      Color(0xFF222222),
      Color(0xFF3A2A1E),
    ][_r.nextInt(3)];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final area = s.bounds.width * s.bounds.height;
      final base = s.isOutline
          ? 5000 + s.samples.length * 18
          : 7000 + area * 30000;
      final dur = ((base + _r.nextInt(5000)) * pace).round();
      _start.add(t);
      _dur.add(dur);
      _paths.add(s.isOutline ? _trace(s) : [_scribble(s)]);
      _colours.add(s.isOutline ? _ink : _tint(s.color!));
      _outline.add(s.isOutline);
      _dip.add(_r.nextDouble() < 0.35);
      t += dur + ((1500 + _r.nextInt(2500)) * pace).round();
    }
    _end = t;
    accuracy = 0.72 + _r.nextDouble() * 0.26;
  }

  final int seat;
  final String itemId;
  final math.Random _r;
  late final Color _ink;
  final List<int> _start = [];
  final List<int> _dur = [];
  final List<List<List<Offset>>> _paths = [];
  final List<Color> _colours = [];
  final List<bool> _outline = [];
  final List<bool> _dip = [];
  late final int _end;
  late final double accuracy;

  int get finishMs => _end;

  Color _tint(Color c) {
    // Kids don't always pick the exact colour.
    if (_r.nextDouble() < 0.7) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + (_r.nextDouble() - 0.5) * 0.2)
            .clamp(0.1, 0.9))
        .toColor();
  }

  List<List<Offset>> _trace(TraceStep s) {
    final ox = (_r.nextDouble() - 0.5) * 0.012;
    final oy = (_r.nextDouble() - 0.5) * 0.012;
    return [
      for (final line in s.lines)
        [
          for (var k = 0; k < line.length; k += 2)
            Offset(line[k].dx + ox + (_r.nextDouble() - 0.5) * 0.006,
                line[k].dy + oy + (_r.nextDouble() - 0.5) * 0.006)
        ]
    ];
  }

  List<Offset> _scribble(TraceStep s) {
    final b = s.bounds;
    final rows = math.max(5, (b.height / 0.025).round());
    final pts = <Offset>[];
    for (var k = 0; k <= rows; k++) {
      final y = b.top + b.height * k / rows;
      final j = (_r.nextDouble() - 0.5) * 0.015;
      pts.add(Offset(k.isEven ? b.left : b.right, y + j));
    }
    return pts;
  }

  /// Fill [st] with what the bot has drawn [elapsed] ms after the start.
  void update(SeatState st, int elapsed, int startAt) {
    st.strokes.clear();
    var done = 0;
    var current = 0.0;
    for (var i = 0; i < _start.length; i++) {
      final s = _start[i];
      if (elapsed <= s) break;
      final f = ((elapsed - s) / _dur[i]).clamp(0.0, 1.0);
      // Now and then the bot goes over the edge and has to fix it, so its
      // bar dips back for a moment (like a real player's).
      current = _dip[i] && f > 0.5 && f < 0.72 ? f - 0.22 : f;
      final lines = _paths[i];
      final width = _outline[i] ? 0.012 : 0.07;
      // Lines are drawn one after another within the step.
      final total = lines.fold<int>(0, (n, l) => n + l.length);
      var budget = (total * f).ceil();
      for (final l in lines) {
        if (budget <= 0) break;
        if (l.isEmpty) continue;
        final n = math.min(l.length, budget);
        st.strokes.add(BStroke(_colours[i], width,
            tag: i, points: l.sublist(0, math.max(1, n))));
        budget -= n;
      }
      if (f >= 1) done++;
    }
    st.step = done;
    st.progress = done >= _start.length ? 1 : (current >= 1 ? 0 : current);
    st.accuracy = accuracy;
    if (elapsed >= _end) {
      st.finished = true;
      st.finishedAt = startAt + _end;
    }
  }
}
