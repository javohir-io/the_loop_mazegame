import 'dart:collection';
import 'dart:math';

import '../models/enemy.dart';
import '../models/grid_pos.dart';

class EnemyAI {
  final Random _random;

  /// How long the Watcher searches before giving up.
  final int maximumSearchTicks;

  EnemyAI({
    Random? random,
    this.maximumSearchTicks = 12,
  }) : _random = random ?? Random();

  void update({
    required Enemy enemy,
    required GridPos playerPosition,
    required List<List<bool>> maze,
    required int rows,
    required int columns,
  }) {
    final distance = enemy.position.distanceTo(playerPosition);

    final playerVisible = _hasLineOfSight(
      enemy.position,
      playerPosition,
      maze,
    );

    // ------------------------------------------------------------
    // CHASING
    // ------------------------------------------------------------

    if (playerVisible &&
        distance <= enemy.detectionRadius) {
      enemy.state = EnemyState.chasing;

      enemy.rememberPlayer(playerPosition);

      _moveUsingPathfinding(
        enemy: enemy,
        target: playerPosition,
        maze: maze,
        rows: rows,
        columns: columns,
      );

      return;
    }

    // ------------------------------------------------------------
    // PLAYER LOST
    // ------------------------------------------------------------

    if (enemy.state == EnemyState.chasing) {
      enemy.startSearching();
    }

    // ------------------------------------------------------------
    // SEARCHING
    // ------------------------------------------------------------

    if (enemy.state == EnemyState.searching ||
        enemy.state == EnemyState.investigating) {
      final target =
          enemy.lastKnownPlayerPosition;

      if (target == null) {
        enemy.stopSearching();
        return;
      }

      final distanceToLastKnown =
          enemy.position.distanceTo(target);

      if (distanceToLastKnown > 0.5) {
        _moveUsingPathfinding(
          enemy: enemy,
          target: target,
          maze: maze,
          rows: rows,
          columns: columns,
        );
      } else {
        enemy.searchTicks++;

        enemy.state = EnemyState.searching;

        // The Watcher remains around the location
        // where it last saw the player.
        if (enemy.searchTicks >=
            maximumSearchTicks) {
          enemy.stopSearching();
        } else {
          _wanderNearPosition(
            enemy: enemy,
            center: target,
            maze: maze,
            rows: rows,
            columns: columns,
          );
        }
      }

      return;
    }

    // ------------------------------------------------------------
    // INVESTIGATION
    // ------------------------------------------------------------

    if (playerVisible &&
        distance <= enemy.detectionRadius * 1.7) {
      enemy.state = EnemyState.investigating;

      enemy.rememberPlayer(playerPosition);

      _moveUsingPathfinding(
        enemy: enemy,
        target: playerPosition,
        maze: maze,
        rows: rows,
        columns: columns,
      );

      return;
    }

    // ------------------------------------------------------------
    // WANDERING
    // ------------------------------------------------------------

    enemy.state = EnemyState.wandering;

    _wander(
      enemy: enemy,
      maze: maze,
      rows: rows,
      columns: columns,
    );
  }

  // ============================================================
  // PATHFINDING
  // ============================================================

  void _moveUsingPathfinding({
    required Enemy enemy,
    required GridPos target,
    required List<List<bool>> maze,
    required int rows,
    required int columns,
  }) {
    final path = _findPath(
      start: enemy.position,
      target: target,
      maze: maze,
      rows: rows,
      columns: columns,
    );

    if (path.length <= 1) {
      return;
    }

    enemy.position = path[1];
  }

  List<GridPos> _findPath({
    required GridPos start,
    required GridPos target,
    required List<List<bool>> maze,
    required int rows,
    required int columns,
  }) {
    final queue = Queue<GridPos>();

    final cameFrom =
        <GridPos, GridPos?>{};

    queue.add(start);
    cameFrom[start] = null;

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current == target) {
        break;
      }

      for (final neighbor in _getNeighbors(
        current,
        maze,
        rows,
        columns,
      )) {
        if (cameFrom.containsKey(neighbor)) {
          continue;
        }

        cameFrom[neighbor] = current;
        queue.add(neighbor);
      }
    }

    if (!cameFrom.containsKey(target)) {
      return [start];
    }

    final path = <GridPos>[];

    GridPos? current = target;

    while (current != null) {
      path.add(current);
      current = cameFrom[current];
    }

    return path.reversed.toList();
  }

  // ============================================================
  // WANDERING
  // ============================================================

  void _wander({
    required Enemy enemy,
    required List<List<bool>> maze,
    required int rows,
    required int columns,
  }) {
    final possibleMoves = _getNeighbors(
      enemy.position,
      maze,
      rows,
      columns,
    );

    if (possibleMoves.isEmpty) {
      return;
    }

    // Mostly continue wandering randomly.
    // Occasionally stay still to make the enemy
    // feel less robotic.
    if (_random.nextDouble() < 0.20) {
      return;
    }

    enemy.position = possibleMoves[
      _random.nextInt(
        possibleMoves.length,
      )
    ];
  }

  void _wanderNearPosition({
    required Enemy enemy,
    required GridPos center,
    required List<List<bool>> maze,
    required int rows,
    required int columns,
  }) {
    final possibleMoves = _getNeighbors(
      enemy.position,
      maze,
      rows,
      columns,
    );

    if (possibleMoves.isEmpty) {
      return;
    }

    possibleMoves.sort(
      (a, b) {
        final distanceA =
            a.distanceTo(center);

        final distanceB =
            b.distanceTo(center);

        return distanceA.compareTo(distanceB);
      },
    );

    // Prefer cells around the last known position.
    final count = min(
      possibleMoves.length,
      2,
    );

    enemy.position = possibleMoves[
      _random.nextInt(count)
    ];
  }

  // ============================================================
  // LINE OF SIGHT
  // ============================================================

  bool _hasLineOfSight(
    GridPos start,
    GridPos target,
    List<List<bool>> maze,
  ) {
    final rowDifference =
        target.row - start.row;

    final columnDifference =
        target.col - start.col;

    final steps = max(
      rowDifference.abs(),
      columnDifference.abs(),
    );

    if (steps == 0) {
      return true;
    }

    for (int i = 1; i < steps; i++) {
      final progress =
          i / steps;

      final row = start.row +
          (rowDifference * progress)
              .round();

      final column = start.col +
          (columnDifference * progress)
              .round();

      if (row < 0 ||
          row >= maze.length ||
          column < 0 ||
          column >= maze[row].length) {
        return false;
      }

      if (!maze[row][column]) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // NEIGHBORS
  // ============================================================

  List<GridPos> _getNeighbors(
    GridPos position,
    List<List<bool>> maze,
    int rows,
    int columns,
  ) {
    final candidates = <GridPos>[
      GridPos(
        position.row - 1,
        position.col,
      ),
      GridPos(
        position.row + 1,
        position.col,
      ),
      GridPos(
        position.row,
        position.col - 1,
      ),
      GridPos(
        position.row,
        position.col + 1,
      ),
    ];

    return candidates.where(
      (candidate) {
        if (candidate.row < 0 ||
            candidate.row >= rows ||
            candidate.col < 0 ||
            candidate.col >= columns) {
          return false;
        }

        return maze[
          candidate.row
        ][candidate.col];
      },
    ).toList();
  }
}