import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ads/ads.dart';
import 'sound.dart';

/// Global, persisted app state. Accessed through [AppScope.of].
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late SharedPreferences _p;

  // Onboarding
  String lang = 'en';
  bool onboarded = false;
  int? ageIndex;
  int? purposeIndex;
  Set<String> interests = {};
  bool askedNotifications = false;

  // Profile
  String username = '';
  int avatarIndex = 0;
  int lessons = 0;
  /// People you finished a Draw Together picture with.
  List<Buddy> buddyList = [];
  int get buddies => buddyList.length;

  // Settings
  bool messagesOff = false;
  bool music = true;
  bool soundFx = true;
  bool vibrate = true;

  /// Active Premium subscription (set by PremiumService).
  bool isPremium = false;
  String? premiumPlan;

  /// Finished Trace Art drawings (My album on the profile).
  List<AlbumEntry> album = [];

  /// Seconds spent in the app (ticks only while in foreground).
  final ValueNotifier<int> spentSeconds = ValueNotifier<int>(0);
  Timer? _timer;

  /// App documents folder (album PNGs live here). Resolved at start-up
  /// because the absolute path can change between app updates on iOS.
  String docsDir = '';

  /// Full path of an album entry's PNG, or null.
  String? albumImagePath(AlbumEntry e) {
    final f = e.imagePath;
    if (f == null || docsDir.isEmpty) return null;
    return f.contains('/') ? f : '$docsDir/$f';
  }

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      docsDir = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
    lang = _p.getString('lang') ?? 'en';
    onboarded = _p.getBool('onboarded') ?? false;
    ageIndex = _p.getInt('age');
    purposeIndex = _p.getInt('purpose');
    interests = (_p.getStringList('interests') ?? const []).toSet();
    askedNotifications = _p.getBool('askedNotif') ?? false;
    username = _p.getString('username') ?? '';
    if (username.isEmpty) {
      username = 'Guest_${100 + Random().nextInt(900)}';
      await _p.setString('username', username);
    }
    avatarIndex = _p.getInt('avatar') ?? 0;
    lessons = _p.getInt('lessons') ?? 0;
    buddyList = [
      for (final raw in _p.getStringList('buddyList') ?? const <String>[])
        if (Buddy.tryParse(raw) != null) Buddy.tryParse(raw)!
    ];
    messagesOff = _p.getBool('messagesOff') ?? false;
    music = _p.getBool('music') ?? true;
    soundFx = _p.getBool('soundFx') ?? true;
    vibrate = _p.getBool('vibrate') ?? true;
    spentSeconds.value = _p.getInt('spent') ?? 0;
    isPremium = _p.getBool('premium') ?? false;
    premiumPlan = _p.getString('premiumPlan');
    album = [
      for (final raw in _p.getStringList('album') ?? const <String>[])
        if (AlbumEntry.tryParse(raw) != null) AlbumEntry.tryParse(raw)!
    ];
  }

  // ---------------------------------------------------------------- tracking
  void startTracking() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      spentSeconds.value++;
      if (spentSeconds.value % 10 == 0) {
        _p.setInt('spent', spentSeconds.value);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      Sound.instance.onForeground();
      Ads.showAppOpen();
    } else {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        Sound.instance.onBackground();
      }
      _timer?.cancel();
      _timer = null;
      _p.setInt('spent', spentSeconds.value);
    }
  }

  // ---------------------------------------------------------------- feedback
  /// Call on every button tap: honours the Sound Fx and Vibrate settings.
  void tap([Sfx sound = Sfx.tap]) {
    Sound.instance.play(sound);
    if (vibrate) HapticFeedback.lightImpact();
  }

  // ---------------------------------------------------------------- setters
  void setLang(String code) {
    lang = code;
    _p.setString('lang', code);
    notifyListeners();
  }

  void setAge(int i) {
    ageIndex = i;
    _p.setInt('age', i);
    notifyListeners();
  }

  void setPurpose(int i) {
    purposeIndex = i;
    _p.setInt('purpose', i);
    notifyListeners();
  }

  void setInterests(Set<String> v) {
    interests = v;
    _p.setStringList('interests', v.toList());
    notifyListeners();
  }

  void completeOnboarding() {
    onboarded = true;
    _p.setBool('onboarded', true);
    notifyListeners();
  }

  void markAskedNotifications() {
    askedNotifications = true;
    _p.setBool('askedNotif', true);
  }

  /// Called when a Trace Art drawing is finished. Unlocks levels over time.
  void completeLesson() {
    lessons++;
    _p.setInt('lessons', lessons);
    notifyListeners();
  }

  void addToAlbum(String itemId, List<String> strokes, {String? imagePath}) {
    album.add(AlbumEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      itemId: itemId,
      strokes: strokes,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imagePath: imagePath,
    ));
    _saveAlbum();
  }

  void toggleFavorite(String id) {
    for (final e in album) {
      if (e.id == id) e.favorite = !e.favorite;
    }
    _saveAlbum();
  }

  void deleteFromAlbum(String id) {
    for (final e in album.where((e) => e.id == id)) {
      final path = albumImagePath(e);
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
    album.removeWhere((e) => e.id == id);
    _saveAlbum();
  }

  void _saveAlbum() {
    _p.setStringList('album', album.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Adds (or refreshes) a drawing buddy after a finished Draw Together.
  void addBuddy(String id, String name, int avatar) {
    buddyList.removeWhere((b) => b.id == id);
    buddyList.insert(
        0,
        Buddy(
            id: id,
            name: name,
            avatar: avatar,
            lastDrawn: DateTime.now().millisecondsSinceEpoch));
    _p.setStringList('buddyList', buddyList.map((b) => b.toJson()).toList());
    notifyListeners();
  }

  void setUsername(String v) {
    username = v;
    _p.setString('username', v);
    notifyListeners();
  }

  void setAvatar(int i) {
    avatarIndex = i;
    _p.setInt('avatar', i);
    notifyListeners();
  }

  void setMessagesOff(bool v) {
    messagesOff = v;
    _p.setBool('messagesOff', v);
    notifyListeners();
  }

  void setMusic(bool v) {
    music = v;
    _p.setBool('music', v);
    Sound.instance.setMusicOn(v);
    notifyListeners();
  }

  void setSoundFx(bool v) {
    soundFx = v;
    _p.setBool('soundFx', v);
    Sound.instance.setSfxOn(v);
    notifyListeners();
  }

  void setPremium(bool v, {String? plan}) {
    isPremium = v;
    premiumPlan = v ? plan : null;
    _p.setBool('premium', v);
    if (plan != null && v) {
      _p.setString('premiumPlan', plan);
    } else {
      _p.remove('premiumPlan');
    }
    notifyListeners();
  }

  void setVibrate(bool v) {
    vibrate = v;
    _p.setBool('vibrate', v);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (use inside callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// One saved drawing. [strokes] are encoded BStroke strings.
class AlbumEntry {
  AlbumEntry({
    required this.id,
    required this.itemId,
    required this.strokes,
    required this.createdAt,
    this.favorite = false,
    this.imagePath,
  });

  final String id;
  final String itemId;
  final List<String> strokes;
  final int createdAt;
  bool favorite;

  /// PNG of the finished picture (Trace Art), if saved.
  final String? imagePath;

  String toJson() => jsonEncode({
        'id': id,
        'item': itemId,
        'strokes': strokes,
        'at': createdAt,
        'fav': favorite,
        if (imagePath != null) 'img': imagePath,
      });

  static AlbumEntry? tryParse(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AlbumEntry(
        id: '${m['id']}',
        itemId: '${m['item']}',
        strokes: (m['strokes'] as List).map((e) => '$e').toList(),
        createdAt: (m['at'] as num).toInt(),
        favorite: m['fav'] == true,
        imagePath: m['img'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class Buddy {
  Buddy(
      {required this.id,
      required this.name,
      required this.avatar,
      required this.lastDrawn});
  final String id;
  final String name;
  final int avatar;
  final int lastDrawn;

  String toJson() =>
      jsonEncode({'id': id, 'name': name, 'avatar': avatar, 'at': lastDrawn});

  static Buddy? tryParse(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return Buddy(
          id: '${m['id']}',
          name: '${m['name']}',
          avatar: (m['avatar'] as num).toInt(),
          lastDrawn: (m['at'] as num).toInt());
    } catch (_) {
      return null;
    }
  }
}
