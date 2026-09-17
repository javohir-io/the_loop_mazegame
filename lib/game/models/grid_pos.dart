import 'dart:math';

class GridPos {
  final int row;
  final int col;

  const GridPos(
    this.row,
    this.col,
  );

  double distanceTo(GridPos other) {
    final rowDistance = row - other.row;
    final colDistance = col - other.col;

    return sqrt(
      (rowDistance * rowDistance) +
          (colDistance * colDistance),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GridPos &&
        other.row == row &&
        other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() {
    return 'GridPos($row, $col)';
  }
}