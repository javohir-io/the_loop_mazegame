/// The direction the player is currently looking, in first-person mode.
///
/// Movement in [GameEngine] is still strictly tile-based (one cell per
/// step) - this enum just translates "move forward" / "move backward"
/// into the (rowDelta, columnDelta) pair the engine already understands,
/// based on which way the camera happens to be facing.
enum Facing {
  north,
  east,
  south,
  west;

  int get rowDelta {
    switch (this) {
      case Facing.north:
        return -1;
      case Facing.south:
        return 1;
      case Facing.east:
      case Facing.west:
        return 0;
    }
  }

  int get colDelta {
    switch (this) {
      case Facing.east:
        return 1;
      case Facing.west:
        return -1;
      case Facing.north:
      case Facing.south:
        return 0;
    }
  }

  /// Rotating counter-clockwise (N -> W -> S -> E -> N).
  Facing get turnedLeft {
    switch (this) {
      case Facing.north:
        return Facing.west;
      case Facing.west:
        return Facing.south;
      case Facing.south:
        return Facing.east;
      case Facing.east:
        return Facing.north;
    }
  }

  /// Rotating clockwise (N -> E -> S -> W -> N).
  Facing get turnedRight {
    switch (this) {
      case Facing.north:
        return Facing.east;
      case Facing.east:
        return Facing.south;
      case Facing.south:
        return Facing.west;
      case Facing.west:
        return Facing.north;
    }
  }
}
