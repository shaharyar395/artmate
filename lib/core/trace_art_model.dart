import 'dart:math' as math;
import 'dart:ui';

/// One vector part of a Trace Art drawing (SVG path in a 0..100 box).
class TracePart {
  const TracePart(this.d,
      {this.fill, this.stroke = 0xFF000000, this.w = 2.2, this.guide = true});

  /// SVG path data using absolute M L H V C Q Z commands.
  final String d;
  final int? fill;
  final int? stroke; // null = no outline
  final double w;

  /// True when this part is one of the tracing steps.
  final bool guide;
}

class TraceArt {
  const TraceArt({required this.parts, this.neon = false});
  final List<TracePart> parts;
  final bool neon;

  List<TracePart> get guideParts => parts.where((p) => p.guide).toList();
}

// =====================================================================
// SVG path parsing (absolute M L H V C Q Z only)
// =====================================================================
final Map<String, Path> _pathCache = {};

/// Path in 0..100 units.
Path parseSvgPath(String d) {
  final cached = _pathCache[d];
  if (cached != null) return cached;
  final path = Path();
  final tokens = RegExp(r'[MLHVCQZmlhvcqz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = 'M';
  double x = 0, y = 0;
  double num() => double.parse(tokens[i++]);
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++].toUpperCase();
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        x = num();
        y = num();
        path.moveTo(x, y);
        cmd = 'L'; // implicit lineto after moveto
        break;
      case 'L':
        x = num();
        y = num();
        path.lineTo(x, y);
        break;
      case 'H':
        x = num();
        path.lineTo(x, y);
        break;
      case 'V':
        y = num();
        path.lineTo(x, y);
        break;
      case 'C':
        final x1 = num(), y1 = num(), x2 = num(), y2 = num();
        x = num();
        y = num();
        path.cubicTo(x1, y1, x2, y2, x, y);
        break;
      case 'Q':
        final x1 = num(), y1 = num();
        x = num();
        y = num();
        path.quadraticBezierTo(x1, y1, x, y);
        break;
      default:
        i++; // unknown token, skip
    }
  }
  _pathCache[d] = path;
  return path;
}

/// Points along a part's line, normalized to 0..1 (for stroke checking and
/// drawing the grey guide).
List<Offset> samplePart(TracePart part, {double spacing = 1.2}) {
  final pts = <Offset>[];
  for (final m in parseSvgPath(part.d).computeMetrics()) {
    final n = math.max(2, (m.length / spacing).ceil());
    for (var k = 0; k <= n; k++) {
      final t = m.getTangentForOffset(m.length * k / n);
      if (t != null) pts.add(t.position / 100);
    }
  }
  return pts;
}

// =====================================================================
// Painting
// =====================================================================

/// Paints a whole drawing into [size] (square area, centred).
void paintTraceArt(Canvas canvas, Size size, TraceArt art,
    {double strokeScale = 1}) {
  final side = math.min(size.width, size.height);
  canvas.save();
  canvas.translate((size.width - side) / 2, (size.height - side) / 2);
  canvas.scale(side / 100);
  for (final p in art.parts) {
    final path = parseSvgPath(p.d);
    if (p.fill != null) {
      canvas.drawPath(path, Paint()..color = Color(p.fill!));
    }
    if (p.stroke != null) {
      final color = Color(p.stroke!);
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.w * strokeScale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      if (art.neon) {
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.w * 3.2
              ..strokeCap = StrokeCap.round
              ..color = color.withOpacity(0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6));
        canvas.drawPath(path, base);
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.w * 0.35
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xCCFFFFFF));
      } else {
        canvas.drawPath(path, base);
      }
    }
  }
  canvas.restore();
}

/// Paints [art] into [rect] (square area recommended).
void paintTraceArtAt(Canvas canvas, Rect rect, TraceArt art) {
  canvas.save();
  canvas.translate(rect.left, rect.top);
  paintTraceArt(canvas, rect.size, art);
  canvas.restore();
}
