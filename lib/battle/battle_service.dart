import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/app_config.dart';
import 'battle_data.dart';
import 'bot_player.dart';

/// Result of matchmaking: who is in the room and when the round starts.
class MatchInfo {
  MatchInfo({
    required this.roomId,
    required this.templateId,
    required this.size,
    required this.mySeat,
    required this.players,
    required this.startAt,
    required this.online,
  });

  final String roomId;
  final String templateId;
  final int size;
  final int mySeat;
  final List<BattlePlayer> players; // index = seat
  final int startAt; // server-time ms
  final bool online;
}

/// Matchmaking + live sync. [BattleService.instance] is set in main():
/// the Firebase version when Firebase is configured, otherwise offline bots.
abstract class BattleService {
  static BattleService instance = OfflineBattleService();

  bool get isOnline;

  /// Current time on the shared clock (server time when online).
  int now();

  Future<MatchInfo?> findMatch({
    required int size,
    required String templateId,
    required String name,
    required int avatar,
    String? queue,
    bool joinOnly = false,
    int? waitMs,
    bool fillBots = true,
  });

  /// How long a private (room code) room stays open for a friend to join.
  static const int privateRoomMs = 120000;

  Future<void> cancelSearch();

  /// Live strokes/progress of the human players in the room, keyed by seat.
  Stream<Map<int, SeatState>> watchRoom(String roomId);

  Future<void> sendStroke(String roomId, int seat, BStroke stroke);
  Future<void> removeLastStroke(String roomId, int seat);
  Future<void> setStrokes(String roomId, int seat, List<BStroke> strokes);
  Future<void> sendState(String roomId, int seat, SeatState state);
  Future<void> leave(String roomId, int seat);

  /// Quick chat messages in a room: (seat, text).
  Future<void> sendChat(String roomId, int seat, String text) async {}
  Stream<(int, String)> watchChat(String roomId) => const Stream.empty();

  /// Room with only bots (used offline, or if online matching fails).
  static MatchInfo botMatch({
    required int size,
    required String templateId,
    required String name,
    required int avatar,
    required int startAt,
  }) {
    final roomId = 'local-$startAt';
    final rnd = math.Random(startAt);
    return MatchInfo(
      roomId: roomId,
      templateId: templateId,
      size: size,
      mySeat: 0,
      online: false,
      startAt: startAt + 1200,
      players: [
        BattlePlayer(
            id: 'me', seat: 0, name: name, avatar: avatar, bot: false),
        for (var s = 1; s < size; s++)
          BattlePlayer(
              id: 'bot$s',
              seat: s,
              name: botName(rnd.nextInt(100000)),
              avatar: rnd.nextInt(12),
              bot: true),
      ],
    );
  }
}

// =====================================================================
// Offline
// =====================================================================
class OfflineBattleService extends BattleService {
  Completer<MatchInfo?>? _pending;

  @override
  bool get isOnline => false;

  @override
  int now() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<MatchInfo?> findMatch({
    required int size,
    required String templateId,
    required String name,
    required int avatar,
    String? queue,
    bool joinOnly = false,
    int? waitMs,
    bool fillBots = true,
  }) {
    final c = Completer<MatchInfo?>();
    _pending = c;
    // Offline there are no other phones: private rooms can't be joined or
    // hosted (the caller falls back to a computer buddy / "not found").
    if (joinOnly || !fillBots) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!c.isCompleted) c.complete(null);
      });
      return c.future;
    }
    final wait = 2200 + math.Random().nextInt(2500);
    Future.delayed(Duration(milliseconds: wait), () {
      if (!c.isCompleted) {
        c.complete(BattleService.botMatch(
            size: size,
            templateId: templateId,
            name: name,
            avatar: avatar,
            startAt: now()));
      }
    });
    return c.future;
  }

  @override
  Future<void> cancelSearch() async {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(null);
  }

  @override
  Stream<Map<int, SeatState>> watchRoom(String roomId) => const Stream.empty();
  @override
  Future<void> sendStroke(String roomId, int seat, BStroke stroke) async {}
  @override
  Future<void> removeLastStroke(String roomId, int seat) async {}
  @override
  Future<void> setStrokes(
      String roomId, int seat, List<BStroke> strokes) async {}
  @override
  Future<void> sendState(String roomId, int seat, SeatState state) async {}
  @override
  Future<void> leave(String roomId, int seat) async {}
}

// =====================================================================
// Firebase Realtime Database
// =====================================================================
//
// matchmaking/p4 = { roomId, count, ts }          open room being filled
// rooms/<id>/players/<uid> = {id, seat, name, avatar}
// rooms/<id>/meta = {status:'started', tpl, size, startAt, players:{s0:{..}}}
// rooms/<id>/live/s<seat>/strokes/<pushId> = "encoded stroke"
// rooms/<id>/live/s<seat>/state = {step, fin, acc, finAt, left}
//
class FirebaseBattleService extends BattleService {
  FirebaseBattleService(this._db);

  final FirebaseDatabase _db;
  int _offset = 0;

  /// How long the host waits for humans before filling seats with bots.
  static const int hostWaitMs = 15000;
  /// A room stays joinable for this long after it was created.
  static const int openWindowMs = 11000;
  static const int guestWaitMs = 25000;

  Completer<MatchInfo?>? _pending;
  final List<StreamSubscription> _subs = [];
  Timer? _timer;
  String? _roomId;
  String? _uid;
  String? _queue;
  bool _isHost = false;

  static Future<FirebaseBattleService> create() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    // google-services.json has no database URL until Realtime Database is
    // created, so the URL is given explicitly (AppConfig.firebaseDatabaseUrl).
    final db = AppConfig.firebaseDatabaseUrl.isEmpty
        ? FirebaseDatabase.instance
        : FirebaseDatabase.instanceFor(
            app: Firebase.app(), databaseURL: AppConfig.firebaseDatabaseUrl);
    final s = FirebaseBattleService(db);
    try {
      final ev = await s._db
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 4));
      s._offset = (ev.snapshot.value as num?)?.toInt() ?? 0;
    } catch (_) {}
    return s;
  }

  @override
  bool get isOnline => true;

  @override
  int now() => DateTime.now().millisecondsSinceEpoch + _offset;

  void _clearSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _finish(MatchInfo? result) {
    _clearSubs();
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(result);
  }

  @override
  Future<MatchInfo?> findMatch({
    required int size,
    required String templateId,
    required String name,
    required int avatar,
    String? queue,
    bool joinOnly = false,
    int? waitMs,
    bool fillBots = true,
  }) async {
    _clearSubs();
    final window = waitMs ?? openWindowMs;
    final c = Completer<MatchInfo?>();
    _pending = c;
    _roomId = null;
    _isHost = false;
    const writeTimeout = Duration(seconds: 6);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ??
          (await FirebaseAuth.instance.signInAnonymously()).user!.uid;
      _uid = uid;
      if (c.isCompleted) return c.future;
      final mm = _db.ref('matchmaking/${queue ?? 'p$size'}');
      _queue = queue;
      final newRoomId = _db.ref('rooms').push().key!;

      var joined = false;
      final res = await mm.runTransaction((cur) {
        joined = false;
        final t = now();
        if (cur is Map) {
          final count = (cur['count'] as num?)?.toInt() ?? 0;
          final ts = (cur['ts'] as num?)?.toInt() ?? 0;
          if (count > 0 && count < size && t - ts < window) {
            joined = true;
            return Transaction.success(
                {'roomId': cur['roomId'], 'count': count + 1, 'ts': ts});
          }
        }
        // Joining by room code: only an open room counts. The first run may
        // only see the (empty/stale) local cache, so write the value back
        // unchanged instead of aborting: the server re-runs us with the real
        // data if it differs.
        if (joinOnly) return Transaction.success(cur);
        return Transaction.success({'roomId': newRoomId, 'count': 1, 'ts': t});
      }).timeout(writeTimeout);
      if (!res.committed || (joinOnly && !joined)) {
        if (!c.isCompleted) c.complete(null);
        return c.future;
      }
      final v = res.snapshot.value as Map;
      final roomId = '${v['roomId']}';
      final seat = ((v['count'] as num).toInt()) - 1;
      final room = _db.ref('rooms/$roomId');
      final meRef = room.child('players/$uid');

      // Cancelled while we were joining: undo and stop.
      Future<MatchInfo?> bail() async {
        try {
          await meRef.remove().timeout(writeTimeout);
          if (seat == 0) await _closeOpenRoom(mm, roomId);
        } catch (_) {}
        return c.future;
      }

      if (c.isCompleted) return bail();
      _roomId = roomId;
      _isHost = seat == 0;

      await meRef.set({
        'id': uid,
        'seat': seat,
        'name': name,
        'avatar': avatar,
        'tpl': templateId,
      }).timeout(writeTimeout);
      await meRef.onDisconnect().remove().timeout(writeTimeout);
      if (c.isCompleted) return bail();

      if (_isHost) {
        _hostWait(c, room, mm, size, templateId, uid,
            waitMs: waitMs ?? hostWaitMs, fillBots: fillBots);
      } else {
        _guestWait(c, room, uid);
      }
    } catch (_) {
      if (!c.isCompleted) c.complete(null);
    }
    return c.future;
  }

  Future<void> _closeOpenRoom(DatabaseReference mm, String roomId) async {
    try {
      await mm.runTransaction((cur) {
        // Empty local cache: no-op write so the server re-runs with real data.
        if (cur == null) return Transaction.success(null);
        if (cur is Map && cur['roomId'] == roomId) {
          return Transaction.success(null);
        }
        return Transaction.abort();
      }).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  void _hostWait(Completer<MatchInfo?> c, DatabaseReference room,
      DatabaseReference mm, int size, String templateId, String uid,
      {required int waitMs, required bool fillBots}) {
    var started = false;
    Future<void> start(Map players) async {
      if (started || !identical(_pending, c) || c.isCompleted) return;
      started = true;
      _clearSubs();
      try {
        await _closeOpenRoom(mm, room.key!);

        final bySeat = <int, BattlePlayer>{};
        for (final p in players.values) {
          if (p is Map) {
            final bp = BattlePlayer.fromMap(p);
            if (bp.seat < size) bySeat[bp.seat] = bp;
          }
        }
        final rnd = math.Random(stableHash(room.key!));
        final list = <BattlePlayer>[
          for (var s = 0; s < size; s++)
            bySeat[s] ??
                BattlePlayer(
                    id: 'bot$s',
                    seat: s,
                    name: botName(rnd.nextInt(100000)),
                    avatar: rnd.nextInt(12),
                    bot: true),
        ];
        final startAt = now() + 1500;
        await room.child('meta').set({
          'status': 'started',
          'tpl': templateId,
          'size': size,
          'startAt': startAt,
          'players': {for (final p in list) 's${p.seat}': p.toMap()},
        }).timeout(const Duration(seconds: 6));
        if (!identical(_pending, c)) return;
        _finish(MatchInfo(
          roomId: room.key!,
          templateId: templateId,
          size: size,
          mySeat: 0,
          players: list,
          startAt: startAt,
          online: true,
        ));
      } catch (_) {
        if (identical(_pending, c)) _finish(null);
      }
    }

    Map latest = {};
    _subs.add(room.child('players').onValue.listen((ev) {
      if (!identical(_pending, c)) return;
      final v = ev.snapshot.value;
      latest = v is Map ? v : {};
      if (latest.length >= size) start(latest);
    }));
    _timer = Timer(Duration(milliseconds: waitMs), () {
      if (!fillBots && latest.length < size) {
        // Private room and the friend never came: close it.
        if (!identical(_pending, c)) return;
        _finish(null);
        room.child('meta').set({'status': 'cancelled'});
        room.child('players/$uid').remove();
        _closeOpenRoom(mm, room.key!);
        return;
      }
      start(latest.isEmpty
          ? {
              uid: {'id': uid, 'seat': 0, 'name': 'You', 'avatar': 0}
            }
          : latest);
    });
  }

  void _guestWait(Completer<MatchInfo?> c, DatabaseReference room, String uid) {
    _subs.add(room.child('meta').onValue.listen((ev) {
      if (!identical(_pending, c)) return;
      final v = ev.snapshot.value;
      if (v is! Map) return;
      if (v['status'] == 'cancelled') {
        _finish(null); // host left before the start
        return;
      }
      if (v['status'] != 'started') return;
      final pm = v['players'];
      final list = <BattlePlayer>[];
      if (pm is Map) {
        for (final p in pm.values) {
          if (p is Map) list.add(BattlePlayer.fromMap(p));
        }
      }
      list.sort((a, b) => a.seat.compareTo(b.seat));
      final me = list.where((p) => p.id == uid);
      if (me.isEmpty) {
        _finish(null); // room started without us
        return;
      }
      _finish(MatchInfo(
        roomId: room.key!,
        templateId: '${v['tpl']}',
        size: (v['size'] as num?)?.toInt() ?? list.length,
        mySeat: me.first.seat,
        players: list,
        startAt: (v['startAt'] as num?)?.toInt() ?? now(),
        online: true,
      ));
    }));
    _timer = Timer(const Duration(milliseconds: guestWaitMs), () {
      if (!identical(_pending, c)) return;
      room.child('players/$uid').remove();
      _finish(null);
    });
  }

  @override
  Future<void> cancelSearch() async {
    final roomId = _roomId;
    final uid = _uid;
    final wasHost = _isHost;
    _finish(null);
    if (roomId == null || uid == null) return;
    try {
      await _db.ref('rooms/$roomId/players/$uid').remove();
      if (wasHost) {
        // Close the open room; waiting guests time out and play with bots.
        await _db.ref('rooms/$roomId/meta').set({'status': 'cancelled'});
        for (final q in ['p2', 'p4', if (_queue != null) _queue!]) {
          await _closeOpenRoom(_db.ref('matchmaking/$q'), roomId);
        }
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ chat
  @override
  Future<void> sendChat(String roomId, int seat, String text) async {
    try {
      await _db
          .ref('rooms/$roomId/chat')
          .push()
          .set({'seat': seat, 'text': text, 'ts': now()});
    } catch (_) {}
  }

  @override
  Stream<(int, String)> watchChat(String roomId) {
    final start = now();
    return _db.ref('rooms/$roomId/chat').onChildAdded.where((ev) {
      final v = ev.snapshot.value;
      return v is Map && ((v['ts'] as num?)?.toInt() ?? 0) >= start - 2000;
    }).map((ev) {
      final v = ev.snapshot.value as Map;
      return ((v['seat'] as num?)?.toInt() ?? 0, '${v['text'] ?? ''}');
    });
  }

  // ------------------------------------------------------------ live sync
  @override
  Stream<Map<int, SeatState>> watchRoom(String roomId) {
    return _db.ref('rooms/$roomId/live').onValue.map((ev) {
      final out = <int, SeatState>{};
      final v = ev.snapshot.value;
      if (v is! Map) return out;
      v.forEach((k, val) {
        final key = '$k';
        if (!key.startsWith('s') || val is! Map) return;
        final seat = int.tryParse(key.substring(1));
        if (seat == null) return;
        final st = SeatState();
        final strokes = val['strokes'];
        if (strokes is Map) {
          final keys = strokes.keys.map((e) => '$e').toList()..sort();
          for (final sk in keys) {
            final s = BStroke.decode('${strokes[sk]}');
            if (s != null) st.strokes.add(s);
          }
        }
        final state = val['state'];
        if (state is Map) {
          st.step = (state['step'] as num?)?.toInt() ?? 0;
          st.progress =
              ((state['prog'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
          st.finished = state['fin'] == true;
          st.left = state['left'] == true;
          st.accuracy = (state['acc'] as num?)?.toDouble() ?? 0;
          st.finishedAt = (state['finAt'] as num?)?.toInt() ?? 0;
        }
        out[seat] = st;
      });
      return out;
    });
  }

  @override
  Future<void> sendStroke(String roomId, int seat, BStroke stroke) async {
    try {
      await _db
          .ref('rooms/$roomId/live/s$seat/strokes')
          .push()
          .set(stroke.encode());
    } catch (_) {}
  }

  @override
  Future<void> removeLastStroke(String roomId, int seat) async {
    try {
      final ref = _db.ref('rooms/$roomId/live/s$seat/strokes');
      final snap = await ref.orderByKey().limitToLast(1).get();
      final v = snap.value;
      if (v is Map && v.isNotEmpty) {
        await ref.child('${v.keys.first}').remove();
      }
    } catch (_) {}
  }

  @override
  Future<void> setStrokes(
      String roomId, int seat, List<BStroke> strokes) async {
    try {
      // Keys like "!00003" sort before later push() ids, keeping order.
      await _db.ref('rooms/$roomId/live/s$seat/strokes').set({
        for (var i = 0; i < strokes.length; i++)
          '!${i.toString().padLeft(5, '0')}': strokes[i].encode(),
      });
    } catch (_) {}
  }

  @override
  Future<void> sendState(String roomId, int seat, SeatState state) async {
    try {
      final ref = _db.ref('rooms/$roomId/live/s$seat/state');
      await ref.set({
        'step': state.step,
        'prog': double.parse(state.progress.toStringAsFixed(3)),
        'fin': state.finished,
        'acc': state.accuracy,
        'finAt': state.finishedAt,
        'left': state.left,
      });
      // Register the "left" marker once per room/seat (state is sent often).
      if (_disconnectSet.add('$roomId/$seat')) {
        await ref.onDisconnect().update({'left': true});
      }
    } catch (_) {}
  }

  final Set<String> _disconnectSet = {};

  @override
  Future<void> leave(String roomId, int seat) async {
    try {
      await _db
          .ref('rooms/$roomId/live/s$seat/state')
          .update({'left': true});
    } catch (_) {}
  }
}
