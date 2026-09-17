import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted, app-wide volume settings.
///
/// Values are held in ValueNotifiers so any widget (the settings
/// screen, the pause dialog, etc.) can listen and react live.
class AudioSettings {
  static final ValueNotifier<double> musicVolume = ValueNotifier(0.55);
  static final ValueNotifier<double> sfxVolume = ValueNotifier(0.85);

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      musicVolume.value = prefs.getDouble('the_loop.music_volume') ?? 0.55;
      sfxVolume.value = prefs.getDouble('the_loop.sfx_volume') ?? 0.85;
    } catch (_) {
      // No persistent storage available - defaults are fine.
    }
  }

  static Future<void> setMusicVolume(double value) async {
    musicVolume.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('the_loop.music_volume', value);
    } catch (_) {}
  }

  static Future<void> setSfxVolume(double value) async {
    sfxVolume.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('the_loop.sfx_volume', value);
    } catch (_) {}
  }

  /// Tracks the deepest loop the player has ever reached, shown on
  /// the main menu as a small "best" record.
  static Future<int> loadBestLoop() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('the_loop.best_loop') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static Future<void> reportLoopReached(int loop) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final best = prefs.getInt('the_loop.best_loop') ?? 1;
      if (loop > best) {
        await prefs.setInt('the_loop.best_loop', loop);
      }
    } catch (_) {}
  }
}

/// A single looping ambient track played on the menus, kept alive as
/// a top-level singleton so it survives pushing/popping between the
/// menu, character select and settings screens.
class MenuMusic {
  static final AudioPlayer _player = AudioPlayer();
  static bool _playing = false;

  static Future<void> start() async {
    if (_playing) return;
    _playing = true;

    try {
      await AudioSettings.load();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(AudioSettings.musicVolume.value * 0.7);
      await _player.play(AssetSource('audio/ambient_loop.wav'));
      AudioSettings.musicVolume.addListener(_applyVolume);
    } catch (_) {
      _playing = false;
    }
  }

  static void _applyVolume() {
    try {
      _player.setVolume(AudioSettings.musicVolume.value * 0.7);
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.pause();
    } catch (_) {}
  }
}

/// Lightweight one-off SFX for menu screens that don't want the full
/// AudioManager (with its looping music/heartbeat players) running.
class UiSound {
  static Future<void> click() async {
    try {
      await AudioSettings.load();
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(AudioSettings.sfxVolume.value);
      await player.play(AssetSource('audio/ui_click.wav'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }
}

enum GameSfx {
  footstep,
  listenPing,
  stabilizer,
  chaseStinger,
  victory,
  gameOver,
  uiClick,
  whisper,
}

/// Owns every looping/one-shot sound used during a game session.
/// All playback is wrapped in try/catch: audio is atmosphere, never
/// something that should be allowed to crash the game.
class AudioManager {
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _chasePlayer = AudioPlayer();
  final AudioPlayer _heartbeatPlayer = AudioPlayer();

  bool _initialized = false;

  static const Map<GameSfx, String> _sfxPaths = {
    GameSfx.footstep: 'audio/footstep.wav',
    GameSfx.listenPing: 'audio/listen_ping.wav',
    GameSfx.stabilizer: 'audio/stabilizer.wav',
    GameSfx.chaseStinger: 'audio/chase_stinger.wav',
    GameSfx.victory: 'audio/victory.wav',
    GameSfx.gameOver: 'audio/game_over.wav',
    GameSfx.uiClick: 'audio/ui_click.wav',
    GameSfx.whisper: 'audio/whisper.wav',
  };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await AudioSettings.load();

    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _chasePlayer.setReleaseMode(ReleaseMode.loop);
      await _heartbeatPlayer.setReleaseMode(ReleaseMode.loop);

      await _ambientPlayer.setVolume(AudioSettings.musicVolume.value);
      await _chasePlayer.setVolume(0);
      await _heartbeatPlayer.setVolume(0);

      unawaited(_ambientPlayer.play(AssetSource('audio/ambient_loop.wav')));
      unawaited(_chasePlayer.play(AssetSource('audio/chase_loop.wav')));
      unawaited(
        _heartbeatPlayer.play(AssetSource('audio/heartbeat_loop.wav')),
      );
    } catch (_) {
      // Some platforms/environments have no audio device - ignore.
    }

    AudioSettings.musicVolume.addListener(_applyMusicVolume);
  }

  void _applyMusicVolume() {
    _ambientPlayer.setVolume(AudioSettings.musicVolume.value);
  }

  /// intensity 0..1 - how close/dangerous the situation is right now.
  /// Driving this smoothly (rather than an on/off switch) is what
  /// makes the tension feel like it's building instead of snapping.
  void setDangerIntensity(double intensity) {
    final clamped = intensity.clamp(0.0, 1.0);
    final musicVol = AudioSettings.musicVolume.value;

    try {
      _chasePlayer.setVolume(musicVol * clamped);
      _heartbeatPlayer.setVolume(musicVol * clamped * 0.9);
    } catch (_) {}
  }

  Future<void> playSfx(GameSfx sfx) async {
    final path = _sfxPaths[sfx];
    if (path == null) return;

    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(AudioSettings.sfxVolume.value);
      await player.play(AssetSource(path));

      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (_) {
      // Ignore - never let a sound effect crash the game.
    }
  }

  void dispose() {
    AudioSettings.musicVolume.removeListener(_applyMusicVolume);
    _ambientPlayer.dispose();
    _chasePlayer.dispose();
    _heartbeatPlayer.dispose();
  }
}
