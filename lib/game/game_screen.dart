import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_manager.dart';
import 'logic/game_engine.dart';
import 'models/character.dart';
import 'models/enemy.dart';
import 'models/grid_pos.dart';
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

class _GameScreenState extends State<GameScreen> {
  late final GameEngine engine;
  late final FocusNode _focusNode;
  final AudioManager _audio = AudioManager();

  Timer? _uiTimer;

  ui.Image? _floorTexture;
  ui.Image? _wallTexture;

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
      _move(-1, 0);
    } else if (key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.arrowDown) {
      _move(1, 0);
    } else if (key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.arrowLeft) {
      _move(0, -1);
    } else if (key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      _move(0, 1);
    } else if (key == LogicalKeyboardKey.space) {
      _listen();
    } else if (key == LogicalKeyboardKey.keyR) {
      _restart();
    } else if (key == LogicalKeyboardKey.escape) {
      _showPauseDialog();
    }
  }

  void _move(
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
    }

    setState(() {});
  }

  void _listen() {
    if (engine.isGameOver || engine.isWon) {
      return;
    }

    engine.listen();
    _audio.playSfx(GameSfx.listenPing);

    setState(() {});
  }

  void _restart() {
    engine.restart();

    _handledWin = false;
    _handledGameOver = false;
    _prevStabilizerCount = engine.stabilizers.length;
    _prevWatcherState = engine.watcher.state;

    setState(() {});

    _focusNode.requestFocus();
  }

  void _nextLoop() {
    engine.nextLoop();

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
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final availableWidth =
            constraints.maxWidth;

        final availableHeight =
            constraints.maxHeight - 80;

        final cellSize =
            _calculateCellSize(
          availableWidth,
          availableHeight,
        );

        final mazeWidth =
            engine.columns * cellSize;

        final mazeHeight =
            engine.rows * cellSize;

        final left =
            (availableWidth - mazeWidth) / 2;

        final top =
            80 +
            (availableHeight - mazeHeight) / 2;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: mazeWidth,
              height: mazeHeight,
              child: CustomPaint(
                painter: _MazePainter(
                  maze: engine.maze,
                  player: engine.playerPosition,
                  exit: engine.exitPosition,
                  stabilizers:
                      engine.stabilizers,
                  watcher: engine.watcher,
                  extraEnemies: engine.extraEnemies,
                  listening:
                      engine.isListening,
                  sanity: engine.sanity,
                  theme: LoopTheme.forLoop(engine.loopNumber),
                  playerColor: widget.character.accentColor,
                  floorTexture: _floorTexture,
                  wallTexture: _wallTexture,
                  pulse: DateTime.now().millisecondsSinceEpoch / 1000.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateCellSize(
    double width,
    double height,
  ) {
    final widthSize =
        width / engine.columns;

    final heightSize =
        height / engine.rows;

    return min(
      widthSize,
      heightSize,
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
// MAZE PAINTER
// ==================================================================

class _MazePainter extends CustomPainter {
  final List<List<bool>> maze;
  final GridPos player;
  final GridPos exit;
  final List<GridPos> stabilizers;
  final Enemy watcher;
  final List<Enemy> extraEnemies;
  final bool listening;
  final double sanity;
  final LoopTheme theme;
  final Color playerColor;
  final ui.Image? floorTexture;
  final ui.Image? wallTexture;
  final double pulse;

  _MazePainter({
    required this.maze,
    required this.player,
    required this.exit,
    required this.stabilizers,
    required this.watcher,
    required this.theme,
    required this.playerColor,
    required this.pulse,
    this.extraEnemies = const [],
    this.floorTexture,
    this.wallTexture,
    required this.listening,
    required this.sanity,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rows = maze.length;
    final columns = maze.first.length;

    final cellWidth =
        size.width / columns;

    final cellHeight =
        size.height / rows;

    _drawBackground(
      canvas,
      size,
    );

    _drawMaze(
      canvas,
      cellWidth,
      cellHeight,
    );

    _drawExit(
      canvas,
      exit,
      cellWidth,
      cellHeight,
    );

    for (final position
        in stabilizers) {
      _drawStabilizer(
        canvas,
        position,
        cellWidth,
        cellHeight,
      );
    }

    final watcherDistance =
        watcher.position.distanceTo(
      player,
    );

    final watcherVisible =
        listening ||
        watcherDistance <=
            watcher.detectionRadius;

    if (watcherVisible) {
      _drawWatcher(
        canvas,
        watcher,
        cellWidth,
        cellHeight,
        theme.watcherColor,
      );
    }

    for (final drifter in extraEnemies) {
      final drifterDistance = drifter.position.distanceTo(player);
      final drifterVisible =
          listening || drifterDistance <= drifter.detectionRadius;

      if (drifterVisible) {
        _drawWatcher(
          canvas,
          drifter,
          cellWidth,
          cellHeight,
          theme.secondaryEnemyColor,
        );
      }
    }

    _drawPlayer(
      canvas,
      player,
      cellWidth,
      cellHeight,
    );

    _drawVision(
      canvas,
      size,
      cellWidth,
      cellHeight,
    );

    _drawSanityEffect(
      canvas,
      size,
    );

    if (watcher.state ==
        EnemyState.chasing) {
      _drawDangerEffect(
        canvas,
        size,
      );
    }
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  void _drawBackground(
    Canvas canvas,
    Size size,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color =
            const Color(0xFF020202),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            theme.ambientGlow.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  // ============================================================
  // MAZE
  // ============================================================

  void _drawMaze(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
  ) {
    final wallPaint = Paint();
    if (wallTexture != null) {
      wallPaint.shader = ImageShader(
        wallTexture!,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    } else {
      wallPaint.color = theme.wallTint;
    }

    final wallTintPaint = Paint()
      ..color = theme.wallTint.withValues(alpha: 0.30)
      ..blendMode = BlendMode.color;

    final floorPaint = Paint();
    if (floorTexture != null) {
      floorPaint.shader = ImageShader(
        floorTexture!,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    } else {
      floorPaint.color = theme.floorTint;
    }

    final floorTintPaint = Paint()
      ..color = theme.floorTint.withValues(alpha: 0.35)
      ..blendMode = BlendMode.color;

    final wallBorderPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final gridPaint = Paint()
      ..color = theme.gridLine.withValues(
        alpha: 0.05,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int row = 0;
        row < maze.length;
        row++) {
      for (int column = 0;
          column < maze[row].length;
          column++) {
        final rect = Rect.fromLTWH(
          column * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );

        if (maze[row][column]) {
          canvas.drawRect(
            rect,
            floorPaint,
          );

          if (floorTexture != null) {
            canvas.drawRect(
              rect,
              floorTintPaint,
            );
          }

          canvas.drawRect(
            rect,
            gridPaint,
          );
        } else {
          canvas.drawRect(
            rect,
            wallPaint,
          );

          if (wallTexture != null) {
            canvas.drawRect(
              rect,
              wallTintPaint,
            );
          }

          canvas.drawRect(
            rect.deflate(0.5),
            wallBorderPaint,
          );

          // Sparse, deterministic torch markers on exposed walls -
          // same maze always lights the same spots, no extra state.
          if ((row * 31 + column * 17) % 47 == 0 &&
              _hasAdjacentFloor(row, column)) {
            _drawTorch(
              canvas,
              _cellCenter(
                GridPos(row, column),
                cellWidth,
                cellHeight,
              ),
              min(cellWidth, cellHeight),
            );
          }
        }
      }
    }
  }

  bool _hasAdjacentFloor(int row, int column) {
    final neighbors = [
      [row - 1, column],
      [row + 1, column],
      [row, column - 1],
      [row, column + 1],
    ];

    for (final n in neighbors) {
      final r = n[0];
      final c = n[1];
      if (r < 0 || r >= maze.length || c < 0 || c >= maze[0].length) {
        continue;
      }
      if (maze[r][c]) {
        return true;
      }
    }

    return false;
  }

  void _drawTorch(
    Canvas canvas,
    Offset center,
    double cellSize,
  ) {
    final flicker = 0.7 + 0.3 * sin(pulse * 6.0 + center.dx * 0.01);

    canvas.drawCircle(
      center,
      cellSize * 0.9,
      Paint()
        ..color = theme.ambientGlow.withValues(alpha: 0.16 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(
      center,
      cellSize * 0.10,
      Paint()
        ..color = theme.exitColor.withValues(alpha: 0.9 * flicker),
    );
  }

  // ============================================================
  // PLAYER
  // ============================================================

  void _drawPlayer(
    Canvas canvas,
    GridPos position,
    double cellWidth,
    double cellHeight,
  ) {
    final center = _cellCenter(
      position,
      cellWidth,
      cellHeight,
    );

    final radius =
        min(cellWidth, cellHeight) *
            0.27;

    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = playerColor.withValues(
          alpha: 0.10,
        ),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = playerColor,
    );

    canvas.drawCircle(
      center,
      radius * 0.35,
      Paint()
        ..color =
            const Color(0xFF111111),
    );
  }

  // ============================================================
  // WATCHER
  // ============================================================

  void _drawWatcher(
    Canvas canvas,
    Enemy enemy,
    double cellWidth,
    double cellHeight,
    Color baseColor,
  ) {
    final center = _cellCenter(
      enemy.position,
      cellWidth,
      cellHeight,
    );

    final radius =
        min(cellWidth, cellHeight) *
            0.38;

    final isChasing =
        enemy.state ==
            EnemyState.chasing;

    final glowColor = isChasing ? baseColor : Colors.white;

    // A slow pulse so the enemy never feels perfectly static, even
    // while idle - subtle, but it reads as "alive".
    final pulseAmount = isChasing
        ? 1.0
        : 0.75 + 0.25 * sin(pulse * 3.4 + enemy.position.row);

    canvas.drawCircle(
      center,
      radius + 7,
      Paint()
        ..color = glowColor.withValues(
          alpha: (isChasing ? 0.18 : 0.07) * pulseAmount,
        ),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color =
            const Color(0xFFD8D8D8),
    );

    final eyePaint = Paint()
      ..color = Colors.black;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.2,
        height: radius * 0.45,
      ),
      eyePaint,
    );

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = isChasing
            ? baseColor
            : baseColor.withValues(alpha: 0.7),
    );
  }

  // ============================================================
  // EXIT
  // ============================================================

  void _drawExit(
    Canvas canvas,
    GridPos position,
    double cellWidth,
    double cellHeight,
  ) {
    final center = _cellCenter(
      position,
      cellWidth,
      cellHeight,
    );

    final radius =
        min(cellWidth, cellHeight) *
            0.28;

    final glowPulse = 0.85 + 0.15 * sin(pulse * 2.2);

    canvas.drawCircle(
      center,
      radius + 5,
      Paint()
        ..color = theme.exitColor.withValues(
          alpha: 0.12 * glowPulse,
        ),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = theme.exitColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      center,
      radius * 0.30,
      Paint()
        ..color = theme.exitColor,
    );
  }

  // ============================================================
  // STABILIZER
  // ============================================================

  void _drawStabilizer(
    Canvas canvas,
    GridPos position,
    double cellWidth,
    double cellHeight,
  ) {
    final center = _cellCenter(
      position,
      cellWidth,
      cellHeight,
    );

    final radius =
        min(cellWidth, cellHeight) *
            0.20;

    final paint = Paint()
      ..color = theme.stabilizerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      center,
      radius,
      paint,
    );

    canvas.drawCircle(
      center,
      radius + 3,
      Paint()
        ..color = theme.stabilizerColor.withValues(alpha: 0.10),
    );

    canvas.drawLine(
      Offset(
        center.dx - radius * 0.7,
        center.dy,
      ),
      Offset(
        center.dx + radius * 0.7,
        center.dy,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx,
        center.dy - radius * 0.7,
      ),
      Offset(
        center.dx,
        center.dy + radius * 0.7,
      ),
      paint,
    );
  }

  // ============================================================
  // VISION
  // ============================================================

  void _drawVision(
    Canvas canvas,
    Size size,
    double cellWidth,
    double cellHeight,
  ) {
    final playerCenter = _cellCenter(
      player,
      cellWidth,
      cellHeight,
    );

    double visionRadius = 4.5;

    if (sanity <= 25) {
      visionRadius = 3.5;
    } else if (sanity <= 50) {
      visionRadius = 4.0;
    }

    if (listening) {
      visionRadius = 7.0;
    }

    final radius =
        visionRadius *
        max(
          cellWidth,
          cellHeight,
        );

    final path = Path()
      ..addRect(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: playerCenter,
          radius: radius,
        ),
      )
      ..fillType =
          PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(
          alpha: 0.78,
        ),
    );
  }

  // ============================================================
  // SANITY EFFECT
  // ============================================================

  void _drawSanityEffect(
    Canvas canvas,
    Size size,
  ) {
    if (sanity > 50) {
      return;
    }

    final intensity =
        (50 - sanity) / 50;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.redAccent
            .withValues(
          alpha: intensity * 0.055,
        ),
    );
  }

  // ============================================================
  // DANGER EFFECT
  // ============================================================

  void _drawDangerEffect(
    Canvas canvas,
    Size size,
  ) {
    final gradient =
        RadialGradient(
      colors: [
        Colors.transparent,
        Colors.redAccent.withValues(
          alpha: 0.08,
        ),
      ],
    );

    final rect =
        Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = gradient.createShader(
          rect,
        ),
    );
  }

  Offset _cellCenter(
    GridPos position,
    double cellWidth,
    double cellHeight,
  ) {
    return Offset(
      (position.col + 0.5) *
          cellWidth,
      (position.row + 0.5) *
          cellHeight,
    );
  }

  @override
  bool shouldRepaint(
    covariant _MazePainter oldDelegate,
  ) {
    return true;
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