import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// All sound effects in assets/audio/ (original sounds made for this app by
/// tools/audio/make_sounds.py — safe to publish).
enum Sfx {
  tap,
  select,
  toggle,
  back,
  oops,
  step,
  praise,
  finish,
  match,
  tick,
  chat,
}

/// Background music + sound effects. Respects the Music and Sound Fx
/// settings, pauses when the app goes to the background, and never pauses
/// other audio focus (sounds mix with the music).
class Sound {
  Sound._();
  static final Sound instance = Sound._();

  static const double musicVolume = 0.32;

  final Map<Sfx, AudioPool> _pools = {};
  final AudioPlayer _music = AudioPlayer(playerId: 'bgm');
  bool _musicOn = true;
  bool _sfxOn = true;
  bool _inForeground = true;
  bool _musicStarted = false;
  /// Music stays silent on the splash / onboarding screens and starts the
  /// first time the Lobby appears (like the reference app).
  bool _musicUnlocked = false;
  bool _initDone = false;
  bool _ready = false;

  Future<void> init({required bool music, required bool sfx}) async {
    _musicOn = music;
    _sfxOn = sfx;
    try {
      // Mix with everything; don't steal audio focus for every tap.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
      ));
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(musicVolume);
      for (final s in Sfx.values) {
        _pools[s] = await AudioPool.create(
          source: AssetSource('audio/${s.name}.mp3'),
          maxPlayers: s == Sfx.tap || s == Sfx.select ? 4 : 2,
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound init failed: $e');
    }
    _initDone = true;
    _updateMusic();
  }

  /// Plays a sound effect (ignored when Sound Fx is off).
  void play(Sfx s, {double volume = 1}) {
    if (!_sfxOn || !_ready) return;
    try {
      _pools[s]?.start(volume: volume);
    } catch (_) {}
  }

  void setMusicOn(bool on) {
    _musicOn = on;
    _updateMusic();
  }

  void setSfxOn(bool on) => _sfxOn = on;

  /// Called by the Lobby when it first appears. Safe to call repeatedly.
  void startMusic() {
    if (_musicUnlocked) return;
    _musicUnlocked = true;
    // If init is still running, it starts the music when it finishes.
    if (_initDone) _updateMusic();
  }

  void onForeground() {
    _inForeground = true;
    _updateMusic();
  }

  void onBackground() {
    _inForeground = false;
    _updateMusic();
  }

  Future<void> _updateMusic() async {
    try {
      if (_musicOn && _inForeground && _musicUnlocked) {
        if (!_musicStarted) {
          _musicStarted = true;
          await _music.play(AssetSource('audio/bgm.mp3'), volume: musicVolume);
        } else {
          await _music.resume();
        }
      } else if (_musicStarted) {
        await _music.pause();
      }
    } catch (e) {
      debugPrint('Music error: $e');
    }
  }
}
