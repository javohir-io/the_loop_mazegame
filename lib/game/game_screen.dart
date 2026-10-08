import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/audio_manager.dart';
import 'logic/camera_state.dart';
import 'logic/facing.dart';
import 'logic/game_engine.dart';
import 'models/character.dart';
import 'models/enemy.dart';
import 'render/raycast_painter.dart';
import 'theme/loop_theme.dart';

class GameScreen extends StatefulWidget {
  final Character character;

  const GameScreen({
    super.key,
    required this.character,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late final GameEngine engine;
  late final FocusNode _focusNode;
  final AudioManager _audio = AudioManager();

  Timer? _uiTimer;

  ui.Image? _floorTexture;
  ui.Image? _wallTexture;

  // ============================================================
  // FIRST-PERSON CAMERA
  // ============================================================

  // Which way the player is currently looking. The engine itself has
  // no concept of facing - this just decides what (rowDelta,
  // columnDelta) "move forward" turns into.
  late Facing _facing;

  // Smoothly-animated render position/angle, interpolated every frame
  // toward the engine's (instant, tile-based) player position.
  late final CameraState _camera;

  // Bumped whenever the camera advances, so the CustomPaint repaints
  // at display refresh rate without rebuilding the rest of the HUD.
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);

  late final Ticker _ticker;
  Duration? _lastTickElapsed;

  // Used to detect state transitions each tick so we know when to
  // play a sound effect, without touching GameEngine's core loop.
  int _prevStabilizerCount = 0;
  EnemyState _prevWatcherState = EnemyState.idle;
  bool _handledWin = false;
  bool _handledGameOver = false;
  int _whisperCooldownTicks = 0;
  final Random _sfxRandom = Random();

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    engine = GameEngine(
      character: widget.character,
    );

    engine.initialize();

    _facing = Facing.north;
    _camera = CameraState(
      col: engine.playerPosition.col + 0.5,
      row: engine.playerPosition.row + 0.5,
      angle: 0.0,
    );
    _ticker = createTicker(_onTick)..start();

    _prevStabilizerCount = engine.stabilizers.length;
    _prevWatcherState = engine.watcher.state;

    MenuMusic.stop();
    _audio.init();
    _loadTextures();

    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (mounted) {
          _pollForAudioEvents();
          setState(() {});
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  // ============================================================
  // CAMERA TICK
  // ============================================================

  void _onTick(Duration elapsed) {
    final last = _lastTickElapsed ?? elapsed;
    _lastTickElapsed = elapsed;

    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 0.05);

    if (dt <= 0) {
      return;
    }

    _camera.tick(dt);
    _frameNotifier.value++;
  }

  Future<void> _loadTextures() async {
    try {
      final floorBytes = await rootBundle.load('assets/textures/floor.png');
      final wallBytes = await rootBundle.load('assets/textures/wall.png');

      final floorImage = await _decode(floorBytes.buffer.asUint8List());
      final wallImage = await _decode(wallBytes.buffer.asUint8List());

      if (mounted) {
        setState(() {
          _floorTexture = floorImage;
          _wallTexture = wallImage;
        });
      }
    } catch (_) {
      // Textures are a visual bonus - fall back to flat colors if
      // asset loading fails for any reason.
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _pollForAudioEvents() {
    if (engine.stabilizers.length < _prevStabilizerCount) {
      _audio.playSfx(GameSfx.stabilizer);
    }
    _prevStabilizerCount = engine.stabilizers.length;

    if (engine.watcher.state == EnemyState.chasing &&
        _prevWatcherState != EnemyState.chasing) {
      _audio.playSfx(GameSfx.chaseStinger);
    }
    _prevWatcherState = engine.watcher.state;

    final watcherDistance =
        engine.watcher.position.distanceTo(engine.playerPosition);
    final proximity =
        1.0 - (watcherDistance / max(engine.watcher.detectionRadius, 1.0));
    final chasingBoost =
        engine.watcher.state == EnemyState.chasing ? 0.4 : 0.0;
    _audio.setDangerIntensity(proximity.clamp(0.0, 1.0) + chasingBoost);

    if (engine.isWon && !_handledWin) {
      _handledWin = true;
      _audio.playSfx(GameSfx.victory);
      AudioSettings.reportLoopReached(engine.loopNumber);
    }

    if (engine.isGameOver && !_handledGameOver) {
      _handledGameOver = true;
      _audio.playSfx(GameSfx.gameOver);
      AudioSettings.reportLoopReached(engine.loopNumber);
    }

    // Occasional eerie whisper when sanity is low - just atmosphere,
    // on a cooldown so it never spams.
    if (_whisperCooldownTicks > 0) {
      _whisperCooldownTicks--;
    } else if (engine.sanity <= 35 &&
        !engine.isGameOver &&
        !engine.isWon &&
        _sfxRandom.nextDouble() < 0.02) {
      _audio.playSfx(GameSfx.whisper);
      _whisperCooldownTicks = 40 + _sfxRandom.nextInt(40);
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _ticker.dispose();
    _frameNotifier.dispose();
    _focusNode.dispose();
    _audio.dispose();
    engine.dispose();
    MenuMusic.start();
    super.dispose();
  }

  // ============================================================
  // INPUT
  // ============================================================

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.arrowUp) {
      _moveForward();
    } else if (key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.arrowDown) {
      _moveBackward();
    } else if (key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.arrowLeft) {
      _turnLeft();
    } else if (key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      _turnRight();
    } else if (key == LogicalKeyboardKey.space) {
      _listen();
    } else if (key == LogicalKeyboardKey.keyR) {
      _restart();
    } else if (key == LogicalKeyboardKey.escape) {
      _showPauseDialog();
    }
  }

  // Stepping forward/backward reuses the exact same tile-based
  // GameEngine.movePlayer call the old top-down controls used - only
  // which (rowDelta, columnDelta) gets passed in has changed, now
  // derived from which way the camera is facing.

  void _moveForward() {
    _step(_facing.rowDelta, _facing.colDelta);
  }

  void _moveBackward() {
    _step(-_facing.rowDelta, -_facing.colDelta);
  }

  void _step(
    int rowDelta,
    int columnDelta,
  ) {
    if (engine.isGameOver || engine.isWon) {
      return;
    }

    final moved = engine.movePlayer(
      rowDelta,
      columnDelta,
    );

    if (moved) {
      _audio.playSfx(GameSfx.footstep);
      _camera.setTargetPosition(
        engine.playerPosition.col + 0.5,
        engine.playerPosition.row + 0.5,
      );
    } else {
      _camera.triggerBump(rowDelta.toDouble(), columnDelta.toDouble());
    }

    setState(() {});
  }

  void _turnLeft() {
    if (engine.isGameOver || engine.isWon) {
      return;
    }

    _facing = _facing.turnedLeft;
    _camera.turn(-pi / 2);
  }

  void _turnRight() {
    if (engine.isGameOver || engine.isWon) {
      return;
    }

    _facing = _facing.turnedRight;
    _camera.turn(pi / 2);
  }

  void _listen() {
    if (engine.isGameOver || engine.isWon) {
      return;
    }

    engine.listen();
    _audio.playSfx(GameSfx.listenPing);

    setState(() {});
  }

  void _resetCamera() {
    _facing = Facing.north;
    _camera.snapToPosition(
      engine.playerPosition.col + 0.5,
      engine.playerPosition.row + 0.5,
    );
    _camera.snapAngle(0.0);
  }

  void _restart() {
    engine.restart();
    _resetCamera();

    _handledWin = false;
    _handledGameOver = false;
    _prevStabilizerCount = engine.stabilizers.length;
    _prevWatcherState = engine.watcher.state;

    setState(() {});

    _focusNode.requestFocus();
  }

  void _nextLoop() {
    engine.nextLoop();
    _resetCamera();

    _handledWin = false;
    _handledGameOver = false;
    _prevStabilizerCount = engine.stabilizers.length;
    _prevWatcherState = engine.watcher.state;

    setState(() {});

    _focusNode.requestFocus();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildGame(),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHud(),
              ),

              if (engine.isWon)
                Positioned.fill(
                  child: _buildWinOverlay(),
                ),

              if (engine.isGameOver)
                Positioned.fill(
                  child: _buildGameOverOverlay(),
                ),

              if (engine.isListening &&
                  !engine.isWon &&
                  !engine.isGameOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ListeningOverlayPainter(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GAME WORLD
  // ============================================================

  Widget _buildGame() {
    // The 3D view fills the whole area below the HUD. Unlike the old
    // top-down grid, it isn't sized off the maze dimensions at all -
    // the CustomPainter just casts rays to whatever size it's given.
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: RaycastPainter(
              maze: engine.maze,
              camera: _camera,
              playerPosition: engine.playerPosition,
              exit: engine.exitPosition,
              stabilizers: engine.stabilizers,
              watcher: engine.watcher,
              extraEnemies: engine.extraEnemies,
              listening: engine.isListening,
              sanity: engine.sanity,
              theme: LoopTheme.forLoop(engine.loopNumber),
              floorTexture: _floorTexture,
              wallTexture: _wallTexture,
              pulse: DateTime.now().millisecondsSinceEpoch / 1000.0,
              repaint: _frameNotifier,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HUD
  // ============================================================

  Widget _buildHud() {
    final sanity =
        engine.sanity.clamp(0.0, 100.0);

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white12,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildSanityDisplay(
            sanity,
          ),

          const SizedBox(width: 24),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  engine.status,
                  style: TextStyle(
                    color: _statusColor(),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'LOOP ${engine.loopNumber}  \u2022  MOVES ${engine.moveCount}'
                  '${engine.extraEnemies.isNotEmpty ? '  \u2022  ${engine.extraEnemies.length} DRIFTERS' : ''}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          if (engine.watcherIsNear)
            _buildWatcherIndicator(),

          const SizedBox(width: 12),

          IconButton(
            onPressed: _showPauseDialog,
            tooltip: 'Pause',
            icon: const Icon(
              Icons.pause,
              color: Colors.white54,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSanityDisplay(
    double sanity,
  ) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SANITY',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${sanity.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: sanity / 100,
              minHeight: 4,
              backgroundColor:
                  Colors.white10,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                _sanityColor(sanity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _sanityColor(
    double sanity,
  ) {
    if (sanity <= 25) {
      return Colors.redAccent;
    }

    if (sanity <= 50) {
      return Colors.orangeAccent;
    }

    return Colors.white70;
  }

  Color _statusColor() {
    if (engine.isGameOver) {
      return Colors.redAccent;
    }

    if (engine.isWon) {
      return Colors.white;
    }

    switch (engine.watcher.state) {
      case EnemyState.chasing:
        return Colors.redAccent;

      case EnemyState.searching:
        return Colors.orangeAccent;

      case EnemyState.investigating:
        return Colors.amberAccent;

      case EnemyState.wandering:
        return Colors.white54;

      case EnemyState.idle:
        return Colors.white38;
    }
  }

  Widget _buildWatcherIndicator() {
    final isChasing =
        engine.watcher.state ==
            EnemyState.chasing;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 200),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isChasing
              ? Colors.redAccent
              : Colors.orangeAccent,
        ),
        color: isChasing
            ? Colors.redAccent.withValues(
                alpha: 0.10,
              )
            : Colors.orangeAccent.withValues(
                alpha: 0.08,
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(
              color: isChasing
                  ? Colors.redAccent
                  : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 7),

          Text(
            isChasing
                ? 'DANGER'
                : 'SIGNAL',
            style: TextStyle(
              color: isChasing
                  ? Colors.redAccent
                  : Colors.orangeAccent,
              fontSize: 9,
              letterSpacing: 2,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAUSE
  // ============================================================

  void _showPauseDialog() {
    if (engine.isWon || engine.isGameOver) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF101010),
          title: const Text(
            'PAUSED',
            style: TextStyle(
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          content: const Text(
            'The loop is waiting.',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _focusNode.requestFocus();
              },
              child: const Text(
                'CONTINUE',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _restart();
              },
              child: const Text(
                'RESTART',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'EXIT',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // WIN OVERLAY
  // ============================================================

  Widget _buildWinOverlay() {
    final theme = LoopTheme.forLoop(engine.loopNumber);

    return Container(
      color: Colors.black.withValues(
        alpha: 0.90,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Text(
              'EXIT FOUND',
              style: TextStyle(
                color: theme.exitColor,
                fontSize: 32,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 7,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'LOOP ${engine.loopNumber} COMPLETE',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'MOVES: ${engine.moveCount}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'SANITY: ${engine.sanity.toInt()}%',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 45),

            SizedBox(
              width: 240,
              height: 50,
              child: OutlinedButton(
                onPressed: _nextLoop,
                child: const Text(
                  'ENTER NEXT LOOP',
                  style: TextStyle(
                    color: Colors.white,
                    letterSpacing: 3,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: 240,
              height: 50,
              child: TextButton(
                onPressed: _restart,
                child: const Text(
                  'RESTART',
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GAME OVER OVERLAY
  // ============================================================

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(
        alpha: 0.94,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              'SANITY LOST',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 32,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 7,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'THE LOOP HAS YOU.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'YOU REACHED LOOP ${engine.loopNumber}',
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),

            if (engine.extraEnemies.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${engine.extraEnemies.length} DRIFTERS WERE ROAMING',
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ],

            const SizedBox(height: 45),

            SizedBox(
              width: 240,
              height: 50,
              child: OutlinedButton(
                onPressed: _restart,
                child: const Text(
                  'TRY AGAIN',
                  style: TextStyle(
                    color: Colors.white,
                    letterSpacing: 3,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: 240,
              height: 50,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'LEAVE LOOP',
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// LISTENING EFFECT
// ==================================================================

class _ListeningOverlayPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final maxRadius =
        max(
          size.width,
          size.height,
        ) *
        0.45;

    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: 0.04,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
        center,
        maxRadius * i / 4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _ListeningOverlayPainter
        oldDelegate,
  ) {
    return false;
  }
}