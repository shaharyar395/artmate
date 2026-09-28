import 'dart:math' as math;
import 'dart:ui';

// =====================================================================
// Templates
// =====================================================================

/// A template card: 4 pictures (4 Players) or 2 pictures (2 Players).
/// Seat N draws the Trace Art picture [items][N] with the step-by-step
/// tracing flow (outline steps, then colour steps).
class BattleTemplate {
  final String id;
  final List<String> items; // Trace Art item ids (trace_catalog.dart)
  const BattleTemplate(this.id, this.items);
  int get size => items.length;
  String itemFor(int seat) => items[seat % items.length];
}

/// 4 Players: themed sets of four pictures (like the reference app's cards).
const List<BattleTemplate> kTemplates4 = [
  BattleTemplate('q1', ['animal_bear', 'cartoon_waffle_bear', 'cartoon_lion_hug', 'beginner_tiger']),
  BattleTemplate('q2', ['animal_chick', 'animal_duckling', 'animal_rooster', 'beginner_chick']),
  BattleTemplate('q3', ['animal_bunny', 'beginner_bunny', 'cartoon_bow_bunny', 'anime_cloud_bunny']),
  BattleTemplate('q4', ['animal_kitten', 'cartoon_hood_kitty', 'halloween_witch_kitty', 'trending_cat_fish']),
  BattleTemplate('q5', ['animal_dolphin', 'animal_beluga', 'beginner_whale', 'animal_pufferfish']),
  BattleTemplate('q6', ['animal_penguin', 'trending_coconut_penguin', 'xmas_santa_penguin', 'animal_kiwi_bird']),
  BattleTemplate('q7', ['animal_fawn', 'animal_fennec_fox', 'anime_spirit_fox', 'xmas_reindeer']),
  BattleTemplate('q8', ['animal_parakeet', 'animal_canary', 'animal_mockingbird', 'animal_turtle']),
  BattleTemplate('q9', ['beginner_octopus', 'beginner_starfish', 'beginner_submarine', 'animal_snail']),
  BattleTemplate('q10', ['xmas_snowman', 'xmas_gingerbread', 'xmas_santa', 'xmas_tree']),
  BattleTemplate('q11', ['halloween_ghost', 'halloween_ghost_puppy', 'halloween_pumpkin_bunny', 'beginner_pumpkin']),
  BattleTemplate('q12', ['cartoon_avocado_buddy', 'cartoon_jelly_blob', 'cartoon_fuzzy_monster', 'cartoon_space_alien']),
];

/// 2 Players: pairs of pictures.
const List<BattleTemplate> kTemplates2 = [
  BattleTemplate('d1', ['animal_bear', 'cartoon_waffle_bear']),
  BattleTemplate('d2', ['animal_bunny', 'beginner_bunny']),
  BattleTemplate('d3', ['animal_chick', 'animal_duckling']),
  BattleTemplate('d4', ['animal_kitten', 'cartoon_hood_kitty']),
  BattleTemplate('d5', ['animal_dolphin', 'beginner_whale']),
  BattleTemplate('d6', ['animal_penguin', 'xmas_santa_penguin']),
  BattleTemplate('d7', ['animal_fawn', 'animal_fennec_fox']),
  BattleTemplate('d8', ['xmas_snowman', 'xmas_gingerbread']),
  BattleTemplate('d9', ['halloween_ghost', 'beginner_pumpkin']),
  BattleTemplate('d10', ['beginner_octopus', 'beginner_starfish']),
  BattleTemplate('d11', ['animal_turtle', 'animal_snail']),
  BattleTemplate('d12', ['cartoon_cloud_puppy', 'halloween_ghost_puppy']),
];

List<BattleTemplate> templatesForSize(int size) =>
    size == 4 ? kTemplates4 : kTemplates2;

BattleTemplate templateById(String id) {
  for (final t in [...kTemplates4, ...kTemplates2]) {
    if (t.id == id) return t;
  }
  return kTemplates4.first;
}

// =====================================================================
// Strokes
// =====================================================================

/// A drawn stroke in normalized 0..1 coordinates.
class BStroke {
  BStroke(this.color, this.width,
      {this.erase = false, this.tag = -1, List<Offset>? points})
      : points = points ?? <Offset>[];

  /// Optional step/region index (Draw Together), -1 when unused.
  final int tag;
  final Color color;
  final double width; // fraction of canvas side
  final bool erase;
  final List<Offset> points;

  String encode() {
    final b = StringBuffer()
      ..write(color.value.toRadixString(16))
      ..write('|')
      ..write(width.toStringAsFixed(4))
      ..write('|')
      ..write(erase ? 1 : 0)
      ..write('|');
    for (var i = 0; i < points.length; i++) {
      if (i > 0) b.write(';');
      b
        ..write(points[i].dx.toStringAsFixed(3))
        ..write(',')
        ..write(points[i].dy.toStringAsFixed(3));
    }
    if (tag >= 0) b.write('|$tag');
    return b.toString();
  }

  static BStroke? decode(String s) {
    try {
      final parts = s.split('|');
      if (parts.length < 4) return null;
      final st = BStroke(Color(int.parse(parts[0], radix: 16)),
          double.parse(parts[1]),
          erase: parts[2] == '1',
          tag: parts.length > 4 ? int.tryParse(parts[4]) ?? -1 : -1);
      if (parts[3].isNotEmpty) {
        for (final p in parts[3].split(';')) {
          final xy = p.split(',');
          st.points.add(Offset(double.parse(xy[0]), double.parse(xy[1])));
        }
      }
      return st;
    } catch (_) {
      return null;
    }
  }
}

/// Paints strokes (normalized) into a square of [side] at the canvas origin.
void paintStrokes(Canvas canvas, double side, Iterable<BStroke> strokes,
    {double widthScale = 1}) {
  canvas.saveLayer(Rect.fromLTWH(0, 0, side, side), Paint());
  for (final s in strokes) {
    if (s.points.isEmpty) continue;
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = math.max(1, s.width * side * widthScale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;
    if (s.points.length == 1) {
      canvas.drawCircle(s.points.first * side, paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill);
      continue;
    }
    final path = Path()
      ..moveTo(s.points.first.dx * side, s.points.first.dy * side);
    for (var i = 1; i < s.points.length; i++) {
      path.lineTo(s.points[i].dx * side, s.points[i].dy * side);
    }
    canvas.drawPath(path, paint);
  }
  canvas.restore();
}

// =====================================================================
// Players
// =====================================================================

/// Seat colours: You (teal), 2 (red), 3 (orange), 4 (blue).
const List<Color> kSeatColors = [
  Color(0xFF1FC3A3),
  Color(0xFFE5484D),
  Color(0xFFF5A623),
  Color(0xFF1E88E5),
];

class BattlePlayer {
  final String id;
  final int seat;
  final String name;
  final int avatar;
  final bool bot;
  const BattlePlayer(
      {required this.id,
      required this.seat,
      required this.name,
      required this.avatar,
      required this.bot});

  Map<String, Object?> toMap() =>
      {'id': id, 'seat': seat, 'name': name, 'avatar': avatar, 'bot': bot};

  static BattlePlayer fromMap(Map m) => BattlePlayer(
        id: '${m['id']}',
        seat: (m['seat'] as num?)?.toInt() ?? 0,
        name: '${m['name'] ?? 'Guest'}',
        avatar: (m['avatar'] as num?)?.toInt() ?? 0,
        bot: m['bot'] == true,
      );
}

/// Live progress of one seat.
class SeatState {
  SeatState();
  final List<BStroke> strokes = [];
  int step = 0; // steps completed
  /// How much of the current step is done (0..1). Goes down again when the
  /// player draws outside or erases, so everyone's bar moves both ways.
  double progress = 0;
  bool finished = false;
  bool left = false;
  double accuracy = 0;
  int finishedAt = 0; // ms since epoch
}

