import 'dart:math';

/// Smoothly-animated first-person camera.
///
/// [GameEngine]'s player position is still strictly grid-based - one
/// tile per move, instant and deterministic, exactly as before. This
/// class just interpolates a *rendered* position/angle toward that
/// logical state every frame, so steps and turns read as fluid motion
/// in the 3D view instead of hard snaps. Nothing here affects gameplay,
/// sanity, or the Watcher's AI - it is purely a presentation layer.
///
/// Positions are in continuous tile-units using the same convention as
/// the grid: integer N is the edge between cell N-1 and cell N, so the
/// *center* of cell N is N + 0.5.
class CameraState {
  double col;
  double row;
  double angle;

  double targetCol;
  double targetRow;
  double targetAngle;

  /// Phase of the head-bob cycle. Advances only while the camera is
  /// actively sliding toward a new tile.
  double _walkCycle = 0;

  /// 0..1 envelope that rises while moving and falls while still, so
  /// the bob fades in/out smoothly instead of snapping on and off.
  double _walkEnvelope = 0;

  /// Decays from 1 to 0 after bumping into a wall - a tiny shove-back
  /// so a blocked move has some physical weight instead of just
  /// silently doing nothing.
  double bumpStrength = 0;
  double _bumpDirRow = 0;
  double _bumpDirCol = 0;

  CameraState({
    required this.col,
    required this.row,
    required this.angle,
  })  : targetCol = col,
        targetRow = row,
        targetAngle = angle;

  bool get isMoving {
    return (targetCol - col).abs() > 0.004 ||
        (targetRow - row).abs() > 0.004;
  }

  void snapToPosition(double newCol, double newRow) {
    col = newCol;
    row = newRow;
    targetCol = newCol;
    targetRow = newRow;
  }

  void snapAngle(double newAngle) {
    angle = newAngle;
    targetAngle = newAngle;
  }

  void setTargetPosition(double newCol, double newRow) {
    targetCol = newCol;
    targetRow = newRow;
  }

  /// Adds a relative turn. Angle is kept unwrapped (can grow or shrink
  /// past +/-2*pi freely) so interpolation always takes the short way
  /// round without any wrap-around bookkeeping.
  void turn(double deltaAngle) {
    targetAngle += deltaAngle;
  }

  void triggerBump(double dirRow, double dirCol) {
    bumpStrength = 1.0;
    _bumpDirRow = dirRow;
    _bumpDirCol = dirCol;
  }

  /// Advances the simulation by [dt] seconds. Call once per rendered
  /// frame from a Ticker.
  void tick(double dt) {
    const posSpeed = 9.0;
    const angleSpeed = 11.0;
    const envelopeSpeed = 6.0;

    final movingBeforeTick = isMoving;

    final posT = 1 - exp(-posSpeed * dt);
    final angleT = 1 - exp(-angleSpeed * dt);
    final envT = 1 - exp(-envelopeSpeed * dt);

    col += (targetCol - col) * posT;
    row += (targetRow - row) * posT;
    angle += (targetAngle - angle) * angleT;

    final envelopeTarget = movingBeforeTick ? 1.0 : 0.0;
    _walkEnvelope += (envelopeTarget - _walkEnvelope) * envT;

    if (movingBeforeTick) {
      _walkCycle += dt * 7.5;
    }

    if (bumpStrength > 0) {
      bumpStrength -= dt * 4.5;
      if (bumpStrength < 0) {
        bumpStrength = 0;
      }
    }
  }

  /// Small camera-space offset from the wall-bump effect, decaying
  /// quickly back to zero. Folded directly into the rendered camera
  /// position so a blocked step visually "presses" into the wall.
  double get bumpOffsetRow => _bumpDirRow * bumpStrength * 0.10;
  double get bumpOffsetCol => _bumpDirCol * bumpStrength * 0.10;

  /// -1..1 head-bob value for the current frame.
  double get bobAmount => sin(_walkCycle) * _walkEnvelope;
}
