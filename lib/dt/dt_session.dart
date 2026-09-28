import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_data.dart' show BStroke, SeatState, BattlePlayer;
import '../battle/battle_service.dart';
import '../battle/bot_player.dart' show stableHash;
import '../core/dt_catalog.dart';
import '../core/trace_art_model.dart';
import '../core/trace_steps.dart';

/// Friendly names for computer drawing buddies.
const List<String> kBuddyNames = [
  'Cookie', 'Mochi', 'Peach', 'Bubbles', 'Pudding', 'Nugget', 'Sunny',
  'Pickle', 'Maple', 'Taco', 'Biscuit', 'Jelly', 'Coco', 'Pepper', 'Muffin',
];

/// One Draw Together match: my seat, the partner's live progress, and chat.
/// Lives across the drawing page and the result page.
class DtSession {
  DtSession({required this.match, required this.template}) {
    mySeat = match.mySeat;
    partnerSeat = 1 - mySeat;
    myArt = template.artFor(mySeat);
    partnerArt = template.artFor(partnerSeat);
    mySteps = buildColourSteps(myArt);
    partnerSteps = buildColourSteps(partnerArt);
    partner = match.players.firstWhere((p) => p.seat == partnerSeat,
        orElse: () => BattlePlayer(
            id: 'bot', seat: partnerSeat, name: 'Cookie', avatar: 3, bot: true));
  }

  final MatchInfo match;
  final DtTemplate template;
  late final int mySeat;
  late final int partnerSeat;
  late final TraceArt myArt;
  late final TraceArt partnerArt;
  late final List<TraceStep> mySteps;
  late final List<TraceStep> partnerSteps;
  late final BattlePlayer partner;

  /// Partner's strokes / step / finished — updates live.
  final ValueNotifier<SeatState> partnerState = ValueNotifier(SeatState());

  /// Latest chat line (seat, text) — updates live.
  final ValueNotifier<(int, String, int)?> chat = ValueNotifier(null);
  int _chatSeq = 0;

  /// Every chat line of this round, oldest first: (seat, text).
  final ValueNotifier<List<(int, String)>> log = ValueNotifier(const []);

  /// True when the room was made with a room code (friends only), so free
  /// text chat is allowed (see AppConfig.allowTextChatWithStrangers).
  bool withFriend = false;

  void _addLog(int seat, String text) {
    log.value = [...log.value, (seat, text)];
    chat.value = (seat, text, ++_chatSeq);
  }

  StreamSubscription? _roomSub;
  StreamSubscription? _chatSub;
  Timer? _tick;
  _DtBot? _bot;
  bool _started = false;

  BattleService get _svc => BattleService.instance;
  bool get online => match.online && !partner.bot;

  void start() {
    if (_started) return;
    _started = true;
    if (online) {
      _roomSub = _svc.watchRoom(match.roomId).listen((m) {
        final st = m[partnerSeat];
        if (st != null) partnerState.value = st;
      });
      _chatSub = _svc.watchChat(match.roomId).listen((c) {
        if (c.$1 != mySeat) _addLog(c.$1, cleanChat(c.$2));
      });
    } else {
      _bot = _DtBot(
          seed: stableHash(match.roomId) ^ partnerSeat, steps: partnerSteps);
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final st = SeatState();
        _bot!.update(st, _svc.now() - match.startAt);
        partnerState.value = st;
        final msg = _bot!.takeChat(_svc.now() - match.startAt);
        if (msg != null) _addLog(partnerSeat, msg);
        if (st.finished && _bot!.chatDone) _tick?.cancel();
      });
    }
  }

  // ------------------------------------------------------------ sending
  void sendStroke(BStroke s) {
    if (online) _svc.sendStroke(match.roomId, mySeat, s);
  }

  void syncStrokes(List<BStroke> all) {
    if (online) _svc.setStrokes(match.roomId, mySeat, all);
  }

  void sendProgress(int step,
      {bool finished = false, double accuracy = 0, double progress = 0}) {
    if (!online) return;
    final st = SeatState()
      ..step = step
      ..progress = finished ? 1 : progress
      ..finished = finished
      ..accuracy = accuracy
      ..finishedAt = finished ? _svc.now() : 0;
    _svc.sendState(match.roomId, mySeat, st);
  }

  void sendChat(String text) {
    final clean = cleanChat(text);
    if (clean.isEmpty) return;
    text = clean;
    _addLog(mySeat, text);
    if (online) {
      _svc.sendChat(match.roomId, mySeat, text);
    } else {
      _bot?.reactToChat(_svc.now() - match.startAt);
    }
  }

  Future<void> leave() async {
    if (online) await _svc.leave(match.roomId, mySeat);
  }

  void dispose() {
    _roomSub?.cancel();
    _chatSub?.cancel();
    _tick?.cancel();
    partnerState.dispose();
    chat.dispose();
    log.dispose();
  }
}

// =====================================================================
// Computer buddy: colours its regions one by one with scribbles.
// =====================================================================
class _DtBot {
  _DtBot({required int seed, required this.steps}) : _r = math.Random(seed) {
    var t = 2500;
    for (var i = 0; i < steps.length; i++) {
      final area = steps[i].bounds.width * steps[i].bounds.height;
      final dur = (4000 + area * 26000 + _r.nextInt(5000)).round();
      _start.add(t);
      _dur.add(dur);
      _scribbles.add(_scribble(steps[i], i));
      t += dur + 800 + _r.nextInt(1500);
    }
    _end = t;
    _nextChat = 9000 + _r.nextInt(12000);
  }

  final List<TraceStep> steps;
  final math.Random _r;
  final List<int> _start = [];
  final List<int> _dur = [];
  final List<List<Offset>> _scribbles = [];
  late final int _end;
  late int _nextChat;
  int? _replyAt;

  static const _lines = ['👋 Hi!', '😍 So cute!', '👍 Nice job!', '🎨 Let\'s go!', '❤️', '😂', '👏', '🌈 Great colors!'];

  List<Offset> _scribble(TraceStep s, int i) {
    final b = s.bounds.deflate(math.min(s.bounds.width, s.bounds.height) * 0.08);
    final rows = math.max(4, (b.height / 0.03).round());
    final pts = <Offset>[];
    for (var k = 0; k <= rows; k++) {
      final y = b.top + b.height * k / rows;
      final jitter = (_r.nextDouble() - 0.5) * 0.02;
      pts.add(Offset(k.isEven ? b.left : b.right, y + jitter));
    }
    return pts;
  }

  void update(SeatState st, int elapsed) {
    var done = 0;
    var current = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final s = _start[i];
      if (elapsed <= s) break;
      final f = ((elapsed - s) / _dur[i]).clamp(0.0, 1.0);
      // Sometimes colours over the edge and fixes it: the bar dips a bit.
      current = i % 3 == 1 && f > 0.5 && f < 0.7 ? f - 0.2 : f;
      final pts = _scribbles[i];
      final n = math.max(2, (pts.length * f).ceil());
      st.strokes.add(BStroke(steps[i].color!, 0.07,
          tag: i, points: pts.sublist(0, math.min(n, pts.length))));
      if (f >= 1) done++;
    }
    st.step = done;
    st.progress = done >= steps.length ? 1 : (current >= 1 ? 0 : current);
    st.accuracy = 0.9;
    if (elapsed >= _end) {
      st.finished = true;
      st.finishedAt = _end;
    }
  }

  bool get chatDone => _replyAt == null;

  void reactToChat(int elapsed) {
    if (_r.nextDouble() < 0.7) _replyAt = elapsed + 1200 + _r.nextInt(1500);
  }

  String? takeChat(int elapsed) {
    if (_replyAt != null && elapsed >= _replyAt!) {
      _replyAt = null;
      return _lines[_r.nextInt(_lines.length)];
    }
    if (elapsed >= _nextChat && elapsed < _end) {
      _nextChat = elapsed + 25000 + _r.nextInt(30000);
      return _lines[_r.nextInt(_lines.length)];
    }
    return null;
  }
}

// =====================================================================
// Painting helpers (canvas in 0..1 units of one drawing)
// =====================================================================

void drawDtStroke(Canvas canvas, BStroke s) {
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

void _checker(Canvas canvas, Path region) {
  final b = region.getBounds();
  const cell = 0.03;
  canvas.save();
  canvas.clipPath(region);
  canvas.drawRect(b, Paint()..color = Colors.white);
  final grey = Paint()..color = const Color(0xFF9E9E9E);
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

/// Paints one drawing in drawing order: each colour step shows white (or a
/// checkerboard when it is [checkerStep]) with the player's paint for that
/// step clipped inside it; other filled parts keep their own colour; the
/// black lines go on top.
void paintDtDrawing(Canvas canvas, TraceArt art, List<TraceStep> steps,
    Iterable<BStroke> strokes,
    {int? checkerStep}) {
  final byPart = <int, int>{
    for (var i = 0; i < steps.length; i++) steps[i].partIndex: i
  };
  for (var pi = 0; pi < art.parts.length; pi++) {
    final part = art.parts[pi];
    final si = byPart[pi];
    if (si != null) {
      final r = steps[si].region!;
      if (si == checkerStep) {
        _checker(canvas, r);
      } else {
        canvas.drawPath(r, Paint()..color = Colors.white);
      }
      final mine = strokes.where((s) => s.tag == si);
      if (mine.isNotEmpty) {
        final b = r.getBounds().inflate(0.01);
        canvas.saveLayer(b, Paint());
        canvas.clipPath(r);
        for (final s in mine) {
          drawDtStroke(canvas, s);
        }
        canvas.restore();
      }
    } else if (part.fill != null) {
      canvas.save();
      canvas.scale(0.01);
      canvas.drawPath(parseSvgPath(part.d), Paint()..color = Color(part.fill!));
      canvas.restore();
    }
  }
  // Black outlines of the drawing.
  canvas.save();
  canvas.scale(0.01);
  for (final p in art.parts) {
    if (p.stroke == null) continue;
    canvas.drawPath(
        parseSvgPath(p.d),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color(p.stroke!));
  }
  canvas.restore();
}

/// Both drawings side by side (the shared picture), in a square of [side].
void paintDtPair(
  Canvas canvas,
  double side, {
  required DtSession session,
  required Iterable<BStroke> myStrokes,
  required Iterable<BStroke> partnerStrokes,
}) {
  final left = session.mySeat == 0;
  void one(double x, TraceArt art, List<TraceStep> steps,
      Iterable<BStroke> strokes) {
    canvas.save();
    canvas.translate(x * side, side * 0.25);
    canvas.scale(side * 0.5);
    paintDtDrawing(canvas, art, steps, strokes);
    canvas.restore();
  }

  one(0.0, left ? session.myArt : session.partnerArt,
      left ? session.mySteps : session.partnerSteps,
      left ? myStrokes : partnerStrokes);
  one(0.5, left ? session.partnerArt : session.myArt,
      left ? session.partnerSteps : session.mySteps,
      left ? partnerStrokes : myStrokes);
}


/// Chat safety for a kids' app: trims, limits length and masks rude words.
String cleanChat(String text) {
  var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Cut by characters so an emoji is never split in half.
  if (t.length > 80) t = t.characters.take(80).toString();
  for (final w in _blocked) {
    t = t.replaceAllMapped(RegExp('\\b$w\\w*', caseSensitive: false),
        (m) => '*' * m.group(0)!.length);
  }
  // No phone numbers / links with strangers.
  t = t.replaceAll(RegExp(r'(https?://|www\.)\S+'), '***');
  t = t.replaceAll(RegExp(r'\d[\d\s-]{6,}\d'), '***');
  return t;
}

const List<String> _blocked = [
  'fuck', 'shit', 'bitch', 'bastard', 'dick', 'pussy', 'cunt', 'asshole',
  'slut', 'whore', 'nigg', 'fag', 'retard', 'sex', 'porn', 'nude', 'kill',
  'stupid', 'idiot', 'dumb', 'ugly', 'hate you', 'snapchat', 'instagram',
  'whatsapp', 'telegram', 'address',
];
