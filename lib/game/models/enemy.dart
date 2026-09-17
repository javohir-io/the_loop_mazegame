import 'grid_pos.dart';

enum EnemyType {
  watcher,
  drifter,
}

enum EnemyState {
  idle,
  wandering,
  investigating,
  searching,
  chasing,
}

class Enemy {
  final EnemyType type;

  GridPos position;

  EnemyState state;

  /// Where the player was last detected.
  GridPos? lastKnownPlayerPosition;

  /// Number of ticks the Watcher has been searching.
  int searchTicks;

  /// How far the Watcher can detect the player.
  final double detectionRadius;

  /// How close the Watcher needs to be before causing heavy damage.
  final double dangerRadius;

  Enemy({
    required this.position,
    this.type = EnemyType.watcher,
    this.state = EnemyState.idle,
    this.lastKnownPlayerPosition,
    this.searchTicks = 0,
    this.detectionRadius = 7.0,
    this.dangerRadius = 4.5,
  });

  String get name {
    switch (type) {
      case EnemyType.watcher:
        return 'THE WATCHER';
      case EnemyType.drifter:
        return 'A DRIFTER';
    }
  }

  bool get isChasing {
    return state == EnemyState.chasing;
  }

  bool get isSearching {
    return state == EnemyState.searching ||
        state == EnemyState.investigating;
  }

  bool get isDangerous {
    return state == EnemyState.chasing ||
        state == EnemyState.searching;
  }

  void rememberPlayer(GridPos playerPosition) {
    lastKnownPlayerPosition = playerPosition;
    searchTicks = 0;
  }

  void startSearching() {
    state = EnemyState.searching;
    searchTicks = 0;
  }

  void stopSearching() {
    state = EnemyState.wandering;
    lastKnownPlayerPosition = null;
    searchTicks = 0;
  }
}