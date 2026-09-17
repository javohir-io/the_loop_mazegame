import 'dart:math';

import '../models/grid_pos.dart';

class MazeGenerator {
  final int rows;
  final int columns;

  final Random _random;

  MazeGenerator({
    required this.rows,
    required this.columns,
    Random? random,
  }) : _random = random ?? Random();

  List<List<bool>> generate() {
    final maze = List.generate(
      rows,
      (_) => List<bool>.filled(
        columns,
        false,
      ),
    );

    final start = const GridPos(1, 1);

    maze[start.row][start.col] = true;

    final stack = <GridPos>[start];

    // ------------------------------------------------------------
    // PHASE 1
    // Generate the basic connected maze.
    // ------------------------------------------------------------

    while (stack.isNotEmpty) {
      final current = stack.last;

      final neighbors = _getUnvisitedNeighbors(
        current,
        maze,
      );

      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = neighbors[
        _random.nextInt(
          neighbors.length,
        )
      ];

      final wallRow =
          current.row +
          ((next.row - current.row) ~/ 2);

      final wallColumn =
          current.col +
          ((next.col - current.col) ~/ 2);

      maze[next.row][next.col] = true;
      maze[wallRow][wallColumn] = true;

      stack.add(next);
    }

    // ------------------------------------------------------------
    // PHASE 2
    // Open additional walls.
    //
    // This is what changes the maze from a single perfect maze
    // into a more confusing environment with:
    //
    // - multiple routes
    // - loops
    // - shortcuts
    // - alternative paths
    // - opportunities to get lost
    // ------------------------------------------------------------

    _addExtraConnections(maze);

    return maze;
  }

  void _addExtraConnections(
    List<List<bool>> maze,
  ) {
    final possibleWalls = <GridPos>[];

    for (int row = 1; row < rows - 1; row++) {
      for (int column = 1;
          column < columns - 1;
          column++) {
        if (maze[row][column]) {
          continue;
        }

        final verticalConnection =
            maze[row - 1][column] &&
                maze[row + 1][column];

        final horizontalConnection =
            maze[row][column - 1] &&
                maze[row][column + 1];

        if (verticalConnection ||
            horizontalConnection) {
          possibleWalls.add(
            GridPos(
              row,
              column,
            ),
          );
        }
      }
    }

    possibleWalls.shuffle(_random);

    // Roughly 18% of the possible connections
    // are opened.
    //
    // This creates loops without turning the
    // entire map into an open room.
    final connectionsToOpen =
        (possibleWalls.length * 0.18).round();

    for (int i = 0;
        i < connectionsToOpen &&
            i < possibleWalls.length;
        i++) {
      final wall = possibleWalls[i];

      maze[wall.row][wall.col] = true;
    }
  }

  List<GridPos> _getUnvisitedNeighbors(
    GridPos current,
    List<List<bool>> maze,
  ) {
    final directions = <GridPos>[
      const GridPos(-2, 0),
      const GridPos(2, 0),
      const GridPos(0, -2),
      const GridPos(0, 2),
    ];

    directions.shuffle(_random);

    final neighbors = <GridPos>[];

    for (final direction in directions) {
      final next = GridPos(
        current.row + direction.row,
        current.col + direction.col,
      );

      if (!_isInside(next)) {
        continue;
      }

      if (maze[next.row][next.col]) {
        continue;
      }

      neighbors.add(next);
    }

    return neighbors;
  }

  bool _isInside(GridPos position) {
    return position.row > 0 &&
        position.row < rows - 1 &&
        position.col > 0 &&
        position.col < columns - 1;
  }
}