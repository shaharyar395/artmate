import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui';

import '../battle/battle_data.dart' show BStroke;
import 'trace_art_model.dart';
import 'trace_catalog.dart';

/// One step of the Trace Art flow (the "n/N" counter).
///
/// Outline steps: trace one grey guide line.
/// Colour steps: paint one region of the picture (shown with a checkerboard).
class TraceStep {
  TraceStep.outline(this.lines)
      : partIndex = -1,
        samples = [for (final l in lines) ...l],
        region = null,
        color = null,
        bounds = _boundsOf([for (final l in lines) ...l]);

  TraceStep.colour(Path this.region, Color this.color, this.samples,
      {this.partIndex = -1})
      : lines = const [],
        bounds = region.getBounds();

  /// Index of the drawing part this colour step comes from (-1 if none).
  final int partIndex;

  /// Grey guide lines to trace (outline steps; 1 or more short lines).
  final List<List<Offset>> lines;

  /// Normalized 0..1 points: the guide line (outline) or a grid of points
  /// inside the region (colour). Progress = share of these points covered.
  final List<Offset> samples;

  /// Region to paint, in 0..1 units (colour steps only).
  final Path? region;

  /// Suggested colour for the region (colour steps only).
  final Color? color;

  final Rect bounds;

  bool get isOutline => region == null;

  static Rect _boundsOf(List<Offset> pts) {
    var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
    for (final p in pts) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}

const int kMaxOutlineSteps = 6;
const int kMaxColourSteps = 3;

/// Builds the steps for a picture: its guide lines (short neighbouring lines
/// are grouped so there are at most 6 outline steps), then up to 3 of its
/// larger coloured areas, in drawing order. Usually 7–9 steps in total.
List<TraceStep> buildTraceSteps(TraceItem item,
    {int maxColour = kMaxColourSteps}) {
  final art = item.art;
  final groups = <List<List<Offset>>>[
    for (final p in art.guideParts) [samplePart(p)],
  ];
  int size(List<List<Offset>> g) => g.fold(0, (n, l) => n + l.length);
  while (groups.length > kMaxOutlineSteps) {
    // The first line (main silhouette) always stays its own step.
    var best = 1;
    for (var i = 2; i < groups.length - 1; i++) {
      if (size(groups[i]) + size(groups[i + 1]) <
          size(groups[best]) + size(groups[best + 1])) {
        best = i;
      }
    }
    groups[best] = [...groups[best], ...groups.removeAt(best + 1)];
  }
  final steps = <TraceStep>[for (final g in groups) TraceStep.outline(g)];

  final candidates = <(int, TracePart, Path, double)>[];
  for (var i = 0; i < art.parts.length; i++) {
    final p = art.parts[i];
    final fill = p.fill;
    if (fill == null) continue;
    final c = Color(fill);
    // Skip white-ish fills: painting white on white is pointless.
    if (c.red > 240 && c.green > 240 && c.blue > 240) continue;
    final path =
        parseSvgPath(p.d).transform(Matrix4Scale.scale(1 / 100).storage);
    final b = path.getBounds();
    final area = b.width * b.height;
    if (area < 0.006) continue; // too tiny to colour
    candidates.add((i, p, path, area));
  }
  candidates.sort((a, b) => b.$4.compareTo(a.$4));
  final chosen = candidates.take(maxColour).toList()..sort((a, b) => a.$1.compareTo(b.$1));
  for (final c in chosen) {
    final grid = _gridInside(c.$3);
    if (grid.length < 4) continue;
    steps.add(TraceStep.colour(c.$3, Color(c.$2.fill!), grid, partIndex: c.$1));
  }
  return steps;
}

List<Offset> _gridInside(Path region) {
  final b = region.getBounds();
  const n = 18;
  final pts = <Offset>[];
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= n; j++) {
      final p = Offset(b.left + b.width * (i + 0.5) / (n + 1),
          b.top + b.height * (j + 0.5) / (n + 1));
      if (region.contains(p)) pts.add(p);
    }
  }
  return pts;
}

/// Live score of one step, updated one segment at a time while the player
/// draws (cheap enough for every touch move).
///
/// * Ink near the target (the guide line, or inside the area) covers sample
///   points and fills the bar.
/// * Extra ink away from the target ("drawing outside") is counted too and
///   pulls the bar back down.
/// * The eraser uncovers points and removes extra ink again, so the bar goes
///   back up/down to match what is on the canvas.
class CoverageTracker {
  CoverageTracker(this.step)
      : _covered = List<bool>.filled(step.samples.length, false),
        _cell = step.isOutline ? 0.014 : _colourCell(step) {
    _slack = step.isOutline ? 0.0 : _cell * 1.2;
  }

  final TraceStep step;
  final List<bool> _covered;
  int _count = 0;

  /// Grid cells (key = x * 100000 + y) holding ink outside the target.
  final Set<int> _extra = {};
  final double _cell;
  late final double _slack;

  /// How strongly extra ink counts against the bar.
  static const double _outlinePenalty = 0.7;
  static const double _colourPenalty = 0.8;

  static double _colourCell(TraceStep s) {
    final b = s.bounds;
    return math.max(0.012, math.max(b.width, b.height) / 19);
  }

  /// Share of the step done: covered part minus extra ink, 0..1.
  double get fraction {
    if (_covered.isEmpty) return 0;
    final n = _covered.length;
    final penalty =
        _extra.length * (step.isOutline ? _outlinePenalty : _colourPenalty);
    return ((_count - penalty) / n).clamp(0.0, 1.0);
  }

  /// Share of the target covered, ignoring extra ink.
  double get covered => _covered.isEmpty ? 0 : _count / _covered.length;

  /// Number of grid cells with ink outside the target.
  int get extraCells => _extra.length;

  double _reach(double width) => step.isOutline
      ? math.max(0.035, width * 1.2)
      : math.max(0.02, width * 0.75);

  bool _isOutside(Offset p, double width) {
    if (step.isOutline) {
      // Farther from the guide line than a careful stroke would be.
      final limit = math.max(0.05, width * 1.6);
      return _nearest2(p) > limit * limit;
    }
    final region = step.region!;
    if (region.contains(p)) return false;
    // Just over the edge is fine (the paint is clipped to the area anyway).
    final limit = _slack + width * 0.35;
    return _nearest2(p) > limit * limit;
  }

  double _nearest2(Offset p) {
    var best = double.infinity;
    for (final q in step.samples) {
      final d = (p - q).distanceSquared;
      if (d < best) best = d;
    }
    return best;
  }

  int _key(Offset p) =>
      (p.dx / _cell).floor() * 100000 + (p.dy / _cell).floor();

  void addSegment(Offset a, Offset b, double width, {bool erase = false}) {
    final reach = erase ? math.max(0.02, width * 0.6) : _reach(width);
    final r2 = reach * reach;
    for (var i = 0; i < _covered.length; i++) {
      if (_covered[i] == !erase) continue;
      if (_segDist2(step.samples[i], a, b) <= r2) {
        _covered[i] = !erase;
        _count += erase ? -1 : 1;
      }
    }
    // Walk the segment in half-cell hops to find ink outside the target.
    final len = (b - a).distance;
    final hops = math.max(1, (len / (_cell * 0.5)).ceil());
    for (var k = 0; k <= hops; k++) {
      final p = Offset.lerp(a, b, k / hops)!;
      if (erase) {
        _eraseExtra(p, reach);
      } else if (_isOutside(p, width)) {
        _extra.add(_key(p));
      }
    }
  }

  void _eraseExtra(Offset p, double reach) {
    if (_extra.isEmpty) return;
    final n = (reach / _cell).ceil();
    final cx = (p.dx / _cell).floor();
    final cy = (p.dy / _cell).floor();
    for (var dx = -n; dx <= n; dx++) {
      for (var dy = -n; dy <= n; dy++) {
        _extra.remove((cx + dx) * 100000 + (cy + dy));
      }
    }
  }

  /// Rebuild from scratch (after undo / redo / clear), in drawing order.
  static CoverageTracker from(TraceStep step, Iterable<BStroke> strokes) {
    final t = CoverageTracker(step);
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      for (var k = 0; k < s.points.length; k++) {
        final a = s.points[k];
        final b = k + 1 < s.points.length ? s.points[k + 1] : a;
        t.addSegment(a, b, s.width, erase: s.erase);
      }
    }
    return t;
  }
}

/// Share (0..1) of [step]'s sample points reached by [strokes].
double stepCoverage(TraceStep step, Iterable<BStroke> strokes) {
  if (step.samples.isEmpty) return 0;
  final covered = List<bool>.filled(step.samples.length, false);
  for (final s in strokes) {
    if (s.erase || s.points.isEmpty) continue;
    final reach = step.isOutline
        ? math.max(0.035, s.width * 1.2)
        : math.max(0.02, s.width * 0.75);
    final r2 = reach * reach;
    for (var k = 0; k < s.points.length; k++) {
      final a = s.points[k];
      final b = k + 1 < s.points.length ? s.points[k + 1] : a;
      for (var i = 0; i < step.samples.length; i++) {
        if (covered[i]) continue;
        if (_segDist2(step.samples[i], a, b) <= r2) covered[i] = true;
      }
    }
  }
  return covered.where((c) => c).length / covered.length;
}

double _segDist2(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  var t = len2 == 0 ? 0.0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  final q = a + ab * t;
  return (p - q).distanceSquared;
}

/// Tiny helper so we don't need the vector_math import here.
class Matrix4Scale {
  Matrix4Scale._(this.storage);
  final Float64List storage;

  static Matrix4Scale scale(double s) => Matrix4Scale._(Float64List.fromList([
        s, 0, 0, 0, //
        0, s, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]));
}

/// Draw Together: colour-only steps for one drawing (its filled areas, in
/// drawing order, at most [max]; the largest are kept when there are more).
List<TraceStep> buildColourSteps(TraceArt art, {int max = 11}) {
  final c = <(int, Path, Color, double)>[];
  for (var i = 0; i < art.parts.length; i++) {
    final p = art.parts[i];
    final fill = p.fill;
    if (fill == null) continue;
    final col = Color(fill);
    if (col.red > 245 && col.green > 245 && col.blue > 245) continue;
    final path =
        parseSvgPath(p.d).transform(Matrix4Scale.scale(1 / 100).storage);
    final b = path.getBounds();
    final area = b.width * b.height;
    if (area < 0.004) continue;
    c.add((i, path, col, area));
  }
  var chosen = c;
  if (chosen.length > max) {
    chosen = [...c]..sort((a, b) => b.$4.compareTo(a.$4));
    chosen = chosen.take(max).toList()..sort((a, b) => a.$1.compareTo(b.$1));
  }
  final out = <TraceStep>[];
  for (final x in chosen) {
    final grid = _gridInside(x.$2);
    if (grid.length >= 4) {
      out.add(TraceStep.colour(x.$2, x.$3, grid, partIndex: x.$1));
    }
  }
  return out;
}
