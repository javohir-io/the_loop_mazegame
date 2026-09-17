import 'dart:async';
import 'dart:math';

import '../models/character.dart';
import '../models/enemy.dart';
import '../models/grid_pos.dart';
import 'enemy_ai.dart';
import 'maze_generator.dart';

class GameEngine {
  int rows = 15;
  int columns = 15;

  final Character character;

  final Random _random = Random();

  late List<List<bool>> maze;

  late GridPos playerPosition;

  late GridPos exitPosition;

  late Enemy watcher;

  /// Extra Drifters that start appearing from loop 3 onward.
  /// They are weaker than the Watcher but add pressure and make
  /// later loops feel genuinely more dangerous.
  List<Enemy> extraEnemies = [];

  final List<GridPos> stabilizers = [];

  final EnemyAI enemyAI = EnemyAI();

  Timer? _timer;

  int moveCount = 0;

  int loopNumber = 1;

  double sanity = 100;

  bool isGameOver = false;

  bool isWon = false;

  bool isListening = false;

  bool watcherIsNear = false;

  String status = 'SEARCHING';

  GameEngine({
    required this.character,
    this.loopNumber = 1,
  });

  void initialize() {
    _timer?.cancel();

    isGameOver = false;
    isWon = false;
    isListening = false;

    moveCount = 0;

    sanity = 100;

    status = 'SEARCHING';

    // Loops start small and grow steadily bigger (and scarier) as
    // the player survives longer, capped so it never becomes
    // unreasonably huge or slow to generate.
    final mazeSize = _mazeSizeForLoop(loopNumber);
    rows = mazeSize;
    columns = mazeSize;

    final generator = MazeGenerator(
      rows: rows,
      columns: columns,
    );

    maze = generator.generate();

    playerPosition =
        const GridPos(1, 1);

    exitPosition = _findExit();

    // The Watcher gets a little sharper each loop, capped so it never
    // becomes literally impossible to escape.
    final loopSharpness =
        min(loopNumber - 1, 6) * 0.28;

    watcher = Enemy(
      position: _findWatcherSpawn(),
      detectionRadius:
          7.0 * character.stealthMultiplier + loopSharpness,
      dangerRadius:
          4.5 * character.stealthMultiplier + loopSharpness * 0.5,
    );

    _spawnExtraEnemies();

    _spawnStabilizers();

    _startTimer();
  }

  void dispose() {
    _timer?.cancel();
  }

  // ============================================================
  // GAME LOOP
  // ============================================================

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(
        milliseconds: 650,
      ),
      (_) {
        if (isGameOver || isWon) {
          return;
        }

        _updateWatcher();
        _updateSanity();

        _checkStabilizer();

        if (sanity <= 0) {
          sanity = 0;
          isGameOver = true;
          status = 'SANITY LOST';
        }
      },
    );
  }

  void _updateWatcher() {
    enemyAI.update(
      enemy: watcher,
      playerPosition: playerPosition,
      maze: maze,
      rows: rows,
      columns: columns,
    );

    for (final drifter in extraEnemies) {
      enemyAI.update(
        enemy: drifter,
        playerPosition: playerPosition,
        maze: maze,
        rows: rows,
        columns: columns,
      );
    }

    final distance =
        watcher.position.distanceTo(
      playerPosition,
    );

    watcherIsNear =
        distance <= watcher.detectionRadius;

    if (watcher.state ==
        EnemyState.chasing) {
      status = 'THE WATCHER SEES YOU';
    } else if (watcher.state ==
        EnemyState.searching) {
      status = 'THE WATCHER IS SEARCHING';
    } else if (watcher.state ==
        EnemyState.investigating) {
      status = 'SIGNAL DETECTED';
    } else if (extraEnemies.any(
      (e) => e.state == EnemyState.chasing,
    )) {
      status = 'A DRIFTER SEES YOU';
    } else if (isListening) {
      status = 'LISTENING...';
    } else {
      status = 'SEARCHING';
    }
  }

  /// True if any drifter is currently close enough to be a threat.
  bool get anyDrifterNear {
    return extraEnemies.any(
      (e) => e.position.distanceTo(playerPosition) <= e.detectionRadius,
    );
  }

  void _updateSanity() {
    final distance =
        watcher.position.distanceTo(
      playerPosition,
    );

    if (distance <= 1.0) {
      sanity -= 7.0;
    } else if (distance <= 2.0) {
      sanity -= 4.0;
    } else if (distance <= watcher.dangerRadius) {
      sanity -= 2.0;
    } else if (watcher.state ==
        EnemyState.chasing) {
      sanity -= 0.8;
    }

    for (final drifter in extraEnemies) {
      final drifterDistance =
          drifter.position.distanceTo(playerPosition);

      if (drifterDistance <= 1.0) {
        sanity -= 3.5;
      } else if (drifterDistance <= drifter.dangerRadius) {
        sanity -= 1.0;
      } else if (drifter.state == EnemyState.chasing) {
        sanity -= 0.4;
      }
    }

    if (sanity < 0) {
      sanity = 0;
    }
  }

  // ============================================================
  // PLAYER MOVEMENT
  // ============================================================

  bool movePlayer(
    int rowDelta,
    int columnDelta,
  ) {
    if (isGameOver || isWon) {
      return false;
    }

    final next = GridPos(
      playerPosition.row + rowDelta,
      playerPosition.col + columnDelta,
    );

    if (!_isWalkable(next)) {
      return false;
    }

    playerPosition = next;

    moveCount++;

    sanity -=
        character.movementSanityCost;

    if (sanity < 0) {
      sanity = 0;
    }

    _checkStabilizer();

    _checkExit();

    return true;
  }

  // ============================================================
  // LISTEN
  // ============================================================

  void listen() {
    if (isGameOver || isWon) {
      return;
    }

    if (sanity <= character.listenCost) {
      status = 'TOO EXHAUSTED';
      return;
    }

    sanity -= character.listenCost;

    isListening = true;

    final distance =
        watcher.position.distanceTo(
      playerPosition,
    );

    if (distance <= 3) {
      status = 'DANGER DETECTED';
    } else if (distance <= 6) {
      status = 'SIGNAL DETECTED';
    } else {
      status = 'LISTENING...';
    }

    Timer(
      const Duration(
        milliseconds: 900,
      ),
      () {
        isListening = false;

        if (!isGameOver && !isWon) {
          status = 'SEARCHING';
        }
      },
    );
  }

  // ============================================================
  // EXIT
  // ============================================================

  void _checkExit() {
    if (playerPosition != exitPosition) {
      return;
    }

    isWon = true;

    sanity +=
        character.loopSanityRecovery;

    if (sanity > 100) {
      sanity = 100;
    }

    status = 'EXIT FOUND';
  }

  void nextLoop() {
    if (!isWon) {
      return;
    }

    loopNumber++;

    initialize();
  }

  void restart() {
    initialize();
  }

  // ============================================================
  // STABILIZERS
  // ============================================================

  void _checkStabilizer() {
    final collected =
        stabilizers.where(
      (position) {
        return position ==
            playerPosition;
      },
    ).toList();

    if (collected.isEmpty) {
      return;
    }

    for (final position in collected) {
      stabilizers.remove(position);
    }

    sanity += 15 * character.stabilizerBonusMultiplier;

    if (sanity > 100) {
      sanity = 100;
    }

    status = 'SANITY STABILIZED';
  }

  void _spawnStabilizers() {
    stabilizers.clear();

    final desiredCount = 4;

    int attempts = 0;

    while (
        stabilizers.length <
            desiredCount &&
        attempts < 500) {
      attempts++;

      final position = GridPos(
        1 + _random.nextInt(
          rows - 2,
        ),
        1 + _random.nextInt(
          columns - 2,
        ),
      );

      if (!_isWalkable(position)) {
        continue;
      }

      if (position ==
          playerPosition) {
        continue;
      }

      if (position ==
          exitPosition) {
        continue;
      }

      if (position.distanceTo(
            playerPosition,
          ) <
          4) {
        continue;
      }

      if (position.distanceTo(
            watcher.position,
          ) <
          3) {
        continue;
      }

      if (stabilizers.contains(
        position,
      )) {
        continue;
      }

      stabilizers.add(position);
    }
  }

  // ============================================================
  // SPAWNING
  // ============================================================

  // ============================================================
  // EXTRA ENEMIES (DRIFTERS)
  // ============================================================

  void _spawnExtraEnemies() {
    extraEnemies = [];

    if (loopNumber < 3) {
      return;
    }

    final desiredCount = min((loopNumber - 1) ~/ 2, 3);

    for (int i = 0; i < desiredCount; i++) {
      extraEnemies.add(
        Enemy(
          type: EnemyType.drifter,
          position: _findWatcherSpawn(),
          detectionRadius: 5.0 * character.stealthMultiplier,
          dangerRadius: 3.0 * character.stealthMultiplier,
        ),
      );
    }
  }

  // ============================================================
  // MAZE SIZE
  // ============================================================

  /// Loop 1 is small and forgiving. Every loop after that grows the
  /// maze by 4 cells per side, capped at 41 so it stays readable and
  /// fast to generate. Always odd, since the generator carves the
  /// maze in 2-cell steps from (1, 1).
  int _mazeSizeForLoop(int loop) {
    final raw = 15 + (loop - 1) * 4;
    final capped = raw > 41 ? 41 : raw;
    return capped.isOdd ? capped : capped + 1;
  }

  GridPos _findWatcherSpawn() {
    final candidates = <GridPos>[];

    final minDistance = max(4, (min(rows, columns) * 0.32).round());

    for (int row = 1;
        row < rows - 1;
        row++) {
      for (int column = 1;
          column < columns - 1;
          column++) {
        final position =
            GridPos(row, column);

        if (!_isWalkable(position)) {
          continue;
        }

        if (position.distanceTo(
              playerPosition,
            ) <
            minDistance) {
          continue;
        }

        candidates.add(position);
      }
    }

    if (candidates.isEmpty) {
      return const GridPos(1, 3);
    }

    return candidates[
      _random.nextInt(
        candidates.length,
      )
    ];
  }

  GridPos _findExit() {
    final candidates = <GridPos>[];

    final minDistance = max(6, (min(rows, columns) * 0.55).round());

    for (int row = 1;
        row < rows - 1;
        row++) {
      for (int column = 1;
          column < columns - 1;
          column++) {
        final position =
            GridPos(row, column);

        if (!_isWalkable(position)) {
          continue;
        }

        if (position.distanceTo(
              playerPosition,
            ) <
            minDistance) {
          continue;
        }

        candidates.add(position);
      }
    }

    if (candidates.isEmpty) {
      return GridPos(
        rows - 2,
        columns - 2,
      );
    }

    candidates.sort(
      (a, b) {
        return b
            .distanceTo(playerPosition)
            .compareTo(
              a.distanceTo(
                playerPosition,
              ),
            );
      },
    );

    // Pick randomly among the farthest ~20% of candidates, rather
    // than always the single most distant cell - the exit should
    // always feel far away, but never be in "the same" spot twice.
    final poolSize =
        max(5, (candidates.length * 0.20).round());

    final pool = candidates.take(poolSize).toList();

    return pool[_random.nextInt(pool.length)];
  }

  bool _isWalkable(
    GridPos position,
  ) {
    if (position.row < 0 ||
        position.row >= rows ||
        position.col < 0 ||
        position.col >= columns) {
      return false;
    }

    return maze[
      position.row
    ][position.col];
  }
}