import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/camera_state.dart';
import '../models/enemy.dart';
import '../models/grid_pos.dart';
import '../theme/loop_theme.dart';

/// Renders the maze in first person using classic grid-based
/// raycasting (the same family of technique Wolfenstein 3D used) -
/// one ray per screen column, marched through the existing boolean
/// maze grid with a DDA loop. No 3D engine, no meshes: the maze is
/// still just [List<List<bool>>] underneath, exactly as it always was.
///
/// Walls are textured by sampling a single-pixel-wide column out of
/// the existing procedural wall texture per ray, the same texture the
/// old top-down view used. Enemies, the exit, and stabilizers are
/// drawn as billboarded sprites, projected and depth-sorted the usual
/// raycaster way and occluded against a per-column wall depth buffer.
class RaycastPainter extends CustomPainter {
  final List<List<bool>> maze;
  final CameraState camera;
  final GridPos playerPosition;
  final GridPos exit;
  final List<GridPos> stabilizers;
  final Enemy watcher;
  final List<Enemy> extraEnemies;
  final bool listening;
  final double sanity;
  final LoopTheme theme;
  final ui.Image? floorTexture;
  final ui.Image? wallTexture;
  final double pulse;

  static const double _fov = 72 * pi / 180;

  RaycastPainter({
    required this.maze,
    required this.camera,
    required this.playerPosition,
    required this.exit,
    required this.stabilizers,
    required this.watcher,
    required this.extraEnemies,
    required this.listening,
    required this.sanity,
    required this.theme,
    required this.pulse,
    this.floorTexture,
    this.wallTexture,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maze.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final rows = maze.length;
    final columns = maze.first.length;

    // Bumping into a wall nudges the *rendered* camera position only -
    // the logical (col, row) used for gameplay never moves.
    final posX = camera.col + camera.bumpOffsetCol;
    final posY = camera.row + camera.bumpOffsetRow;

    final dirX = sin(camera.angle);
    final dirY = -cos(camera.angle);

    final planeLen = tan(_fov / 2);
    final planeX = -dirY * planeLen;
    final planeY = dirX * planeLen;

    final bobPixels = camera.bobAmount * 5.0;
    final horizon = size.height / 2 + bobPixels;

    final visionRadius = _visionRadius();
    // Vision radius in the old top-down view was a flat circle around
    // the player; here it becomes draw distance down a corridor, so it
    // gets a bit more reach or straight hallways would vanish into fog
    // almost immediately.
    final fogDistance = visionRadius * 1.6;

    _drawBackdrop(canvas, size, horizon);

    final numRays = (size.width / 5.0).round().clamp(100, 260).toInt();
    final colWidth = size.width / numRays;
    final zBuffer = List<double>.filled(numRays, double.infinity);

    for (int x = 0; x < numRays; x++) {
      final cameraX = 2 * x / numRays - 1;
      final rayDirX = dirX + planeX * cameraX;
      final rayDirY = dirY + planeY * cameraX;

      _castAndDrawColumn(
        canvas: canvas,
        size: size,
        posX: posX,
        posY: posY,
        rayDirX: rayDirX,
        rayDirY: rayDirY,
        rows: rows,
        columns: columns,
        colIndex: x,
        colWidth: colWidth,
        horizon: horizon,
        fogDistance: fogDistance,
        zBuffer: zBuffer,
      );
    }

    _drawSprites(
      canvas: canvas,
      size: size,
      posX: posX,
      posY: posY,
      dirX: dirX,
      dirY: dirY,
      planeX: planeX,
      planeY: planeY,
      horizon: horizon,
      numRays: numRays,
      colWidth: colWidth,
      fogDistance: fogDistance,
      zBuffer: zBuffer,
    );

    _drawReticle(canvas, size);
    _drawSanityVignette(canvas, size);

    if (watcher.state == EnemyState.chasing) {
      _drawDangerEffect(canvas, size);
    }
  }

  // ============================================================
  // VISION / FOG
  // ============================================================

  double _visionRadius() {
    double radius = 4.5;

    if (sanity <= 25) {
      radius = 3.5;
    } else if (sanity <= 50) {
      radius = 4.0;
    }

    if (listening) {
      radius = 7.0;
    }

    return radius;
  }

  // ============================================================
  // SKY / FLOOR BACKDROP
  // ============================================================

  void _drawBackdrop(Canvas canvas, Size size, double horizon) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020202),
    );

    final ceilingRect = Rect.fromLTWH(0, 0, size.width, horizon);
    final floorRect = Rect.fromLTWH(0, horizon, size.width, size.height - horizon);

    canvas.drawRect(
      ceilingRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, horizon),
          [
            Color.lerp(Colors.black, theme.wallTint, 0.55)!,
            Colors.black,
          ],
        ),
    );

    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon),
          Offset(0, size.height),
          [
            Color.lerp(Colors.black, theme.floorTint, 0.95)!,
            Colors.black,
          ],
        ),
    );

    if (floorTexture != null) {
      canvas.save();
      canvas.clipRect(floorRect);
      canvas.saveLayer(floorRect, Paint()..color = Colors.white.withValues(alpha: 0.10));
      canvas.drawRect(
        floorRect,
        Paint()
          ..shader = ImageShader(
            floorTexture!,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          ),
      );
      canvas.restore();
      canvas.restore();
    }

    // A faint ambient wash of the loop's current theme colour, so the
    // palette shift between loops still reads clearly in first person.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, horizon),
          size.longestSide * 0.7,
          [
            theme.ambientGlow.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
    );
  }

  // ============================================================
  // WALLS (DDA RAYCAST)
  // ============================================================

  void _castAndDrawColumn({
    required Canvas canvas,
    required Size size,
    required double posX,
    required double posY,
    required double rayDirX,
    required double rayDirY,
    required int rows,
    required int columns,
    required int colIndex,
    required double colWidth,
    required double horizon,
    required double fogDistance,
    required List<double> zBuffer,
  }) {
    int mapCol = posX.floor();
    int mapRow = posY.floor();

    final deltaDistX = rayDirX.abs() < 1e-12 ? 1e30 : (1 / rayDirX).abs();
    final deltaDistY = rayDirY.abs() < 1e-12 ? 1e30 : (1 / rayDirY).abs();

    final int stepCol;
    double sideDistX;
    if (rayDirX < 0) {
      stepCol = -1;
      sideDistX = (posX - mapCol) * deltaDistX;
    } else {
      stepCol = 1;
      sideDistX = (mapCol + 1 - posX) * deltaDistX;
    }

    final int stepRow;
    double sideDistY;
    if (rayDirY < 0) {
      stepRow = -1;
      sideDistY = (posY - mapRow) * deltaDistY;
    } else {
      stepRow = 1;
      sideDistY = (mapRow + 1 - posY) * deltaDistY;
    }

    int side = 0;
    bool hit = false;
    final maxSteps = rows + columns + 4;
    int steps = 0;

    while (!hit && steps < maxSteps) {
      steps++;
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapCol += stepCol;
        side = 0;
      } else {
        sideDistY += deltaDistY;
        mapRow += stepRow;
        side = 1;
      }

      if (mapRow < 0 || mapRow >= rows || mapCol < 0 || mapCol >= columns) {
        hit = true;
        break;
      }

      if (!maze[mapRow][mapCol]) {
        hit = true;
      }
    }

    double perpWallDist;
    if (side == 0) {
      perpWallDist = (mapCol - posX + (1 - stepCol) / 2) / rayDirX;
    } else {
      perpWallDist = (mapRow - posY + (1 - stepRow) / 2) / rayDirY;
    }
    perpWallDist = perpWallDist.abs();
    if (perpWallDist < 0.05) {
      perpWallDist = 0.05;
    }

    zBuffer[colIndex] = perpWallDist;

    double wallX;
    if (side == 0) {
      wallX = posY + perpWallDist * rayDirY;
    } else {
      wallX = posX + perpWallDist * rayDirX;
    }
    wallX -= wallX.floorToDouble();

    final rawLineHeight = size.height / perpWallDist;
    final lineHeight = rawLineHeight.clamp(0.0, size.height * 6);

    final top = horizon - lineHeight / 2;
    final bottom = horizon + lineHeight / 2;

    final left = colIndex * colWidth;
    final dstRect = Rect.fromLTWH(left, top, colWidth + 1.0, bottom - top);

    final fogT = (perpWallDist / fogDistance).clamp(0.0, 1.0);
    final sideShade = side == 1 ? 0.14 : 0.0;
    final blackAlpha = (fogT + sideShade).clamp(0.0, 0.97);
    final brightness = (1 - blackAlpha).clamp(0.0, 1.0);

    if (wallTexture != null) {
      final texW = wallTexture!.width;
      final texH = wallTexture!.height;
      final texX = (wallX * texW).floor().clamp(0, texW - 1).toInt();
      final srcRect = Rect.fromLTWH(texX.toDouble(), 0, 1, texH.toDouble());

      canvas.drawImageRect(
        wallTexture!,
        srcRect,
        dstRect,
        Paint(),
      );

      // Recolour the (greyscale-ish) texture with this loop's theme,
      // preserving its luminance/detail - same trick the old top-down
      // painter used for wall tinting.
      canvas.drawRect(
        dstRect,
        Paint()
          ..color = theme.wallTint.withValues(alpha: 0.32)
          ..blendMode = BlendMode.color,
      );

      canvas.drawRect(
        dstRect,
        Paint()..color = Colors.black.withValues(alpha: blackAlpha),
      );
    } else {
      canvas.drawRect(
        dstRect,
        Paint()..color = Color.lerp(Colors.black, theme.wallTint, brightness)!,
      );
    }
  }

  // ============================================================
  // SPRITES (EXIT / STABILIZERS / ENEMIES)
  // ============================================================

  void _drawSprites({
    required Canvas canvas,
    required Size size,
    required double posX,
    required double posY,
    required double dirX,
    required double dirY,
    required double planeX,
    required double planeY,
    required double horizon,
    required int numRays,
    required double colWidth,
    required double fogDistance,
    required List<double> zBuffer,
  }) {
    final sprites = <_Sprite>[
      _Sprite(
        col: exit.col + 0.5,
        row: exit.row + 0.5,
        kind: _SpriteKind.exit,
      ),
      for (final stabilizer in stabilizers)
        _Sprite(
          col: stabilizer.col + 0.5,
          row: stabilizer.row + 0.5,
          kind: _SpriteKind.stabilizer,
        ),
    ];

    final watcherDistance = watcher.position.distanceTo(playerPosition);
    final watcherVisible = listening || watcherDistance <= watcher.detectionRadius;

    if (watcherVisible) {
      sprites.add(
        _Sprite(
          col: watcher.position.col + 0.5,
          row: watcher.position.row + 0.5,
          kind: _SpriteKind.watcher,
          chasing: watcher.state == EnemyState.chasing,
        ),
      );
    }

    for (final drifter in extraEnemies) {
      final drifterDistance = drifter.position.distanceTo(playerPosition);
      final drifterVisible = listening || drifterDistance <= drifter.detectionRadius;

      if (drifterVisible) {
        sprites.add(
          _Sprite(
            col: drifter.position.col + 0.5,
            row: drifter.position.row + 0.5,
            kind: _SpriteKind.drifter,
            chasing: drifter.state == EnemyState.chasing,
          ),
        );
      }
    }

    sprites.sort((a, b) {
      final da = (a.col - posX) * (a.col - posX) + (a.row - posY) * (a.row - posY);
      final db = (b.col - posX) * (b.col - posX) + (b.row - posY) * (b.row - posY);
      return db.compareTo(da);
    });

    final invDet = 1.0 / (planeX * dirY - dirX * planeY);

    for (final sprite in sprites) {
      final relX = sprite.col - posX;
      final relY = sprite.row - posY;

      final transformX = invDet * (dirY * relX - dirX * relY);
      final transformY = invDet * (-planeY * relX + planeX * relY);

      if (transformY <= 0.15) {
        continue;
      }

      final screenX = (size.width / 2) * (1 + transformX / transformY);

      final baseScale = switch (sprite.kind) {
        _SpriteKind.exit => 0.95,
        _SpriteKind.stabilizer => 0.42,
        _SpriteKind.watcher => 1.0,
        _SpriteKind.drifter => 0.82,
      };

      final spriteHeight = (size.height / transformY) * baseScale;
      final spriteWidth = spriteHeight;

      final top = horizon - spriteHeight / 2;
      final bottom = horizon + spriteHeight / 2;
      final left = screenX - spriteWidth / 2;
      final right = screenX + spriteWidth / 2;

      if (right < 0 || left > size.width) {
        continue;
      }

      final sampleCol = (screenX / colWidth).floor().clamp(0, numRays - 1).toInt();
      if (zBuffer[sampleCol] < transformY) {
        continue;
      }

      final fogT = (transformY / fogDistance).clamp(0.0, 1.0);
      final opacity = (1 - fogT).clamp(0.0, 1.0);

      if (opacity <= 0.02) {
        continue;
      }

      _drawSpriteShape(
        canvas,
        sprite,
        Rect.fromLTRB(left, top, right, bottom),
        opacity,
      );
    }
  }

  void _drawSpriteShape(
    Canvas canvas,
    _Sprite sprite,
    Rect rect,
    double opacity,
  ) {
    final center = rect.center;
    final radius = rect.shortestSide / 2;

    switch (sprite.kind) {
      case _SpriteKind.exit:
        _drawExitSprite(canvas, center, radius, opacity);
        break;
      case _SpriteKind.stabilizer:
        _drawStabilizerSprite(canvas, center, radius, opacity);
        break;
      case _SpriteKind.watcher:
        _drawEnemySprite(canvas, center, radius, opacity, theme.watcherColor, sprite.chasing);
        break;
      case _SpriteKind.drifter:
        _drawEnemySprite(
          canvas,
          center,
          radius,
          opacity,
          theme.secondaryEnemyColor,
          sprite.chasing,
        );
        break;
    }
  }

  void _drawExitSprite(Canvas canvas, Offset center, double radius, double opacity) {
    final glowPulse = 0.85 + 0.15 * sin(pulse * 2.2);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = theme.exitColor.withValues(alpha: 0.14 * glowPulse * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..color = theme.exitColor.withValues(alpha: 0.65 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, radius * 0.06),
    );

    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()..color = theme.exitColor.withValues(alpha: opacity),
    );
  }

  void _drawStabilizerSprite(Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = theme.stabilizerColor.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, radius * 0.1);

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = theme.stabilizerColor.withValues(alpha: 0.12 * opacity),
    );

    canvas.drawCircle(center, radius * 0.6, paint);

    canvas.drawLine(
      Offset(center.dx - radius * 0.42, center.dy),
      Offset(center.dx + radius * 0.42, center.dy),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.42),
      Offset(center.dx, center.dy + radius * 0.42),
      paint,
    );
  }

  void _drawEnemySprite(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
    Color baseColor,
    bool chasing,
  ) {
    final glowColor = chasing ? baseColor : Colors.white;
    final pulseAmount = chasing ? 1.0 : 0.75 + 0.25 * sin(pulse * 3.4 + center.dx * 0.01);

    canvas.drawCircle(
      center,
      radius * 1.15,
      Paint()
        ..color = glowColor.withValues(alpha: (chasing ? 0.30 : 0.12) * pulseAmount * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()..color = const Color(0xFFD8D8D8).withValues(alpha: opacity),
    );

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 0.75, height: radius * 0.28),
      Paint()..color = Colors.black.withValues(alpha: opacity),
    );

    final pupilAlpha = (chasing ? 1.0 : 0.7) * opacity;
    canvas.drawCircle(
      center,
      radius * 0.08,
      Paint()..color = baseColor.withValues(alpha: pupilAlpha),
    );
  }

  // ============================================================
  // SCREEN-SPACE EFFECTS
  // ============================================================

  void _drawReticle(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  void _drawSanityVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final edgeStrength = 0.34;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.72,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: edgeStrength),
          ],
          [0.55, 1.0],
        ),
    );

    if (sanity > 50) {
      return;
    }

    final intensity = (50 - sanity) / 50;

    canvas.drawRect(
      rect,
      Paint()..color = Colors.redAccent.withValues(alpha: intensity * 0.10),
    );
  }

  void _drawDangerEffect(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.75,
          [
            Colors.transparent,
            Colors.redAccent.withValues(alpha: 0.16),
          ],
          [0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant RaycastPainter oldDelegate) => true;
}

// ==================================================================
// SPRITE DATA
// ==================================================================

enum _SpriteKind { exit, stabilizer, watcher, drifter }

class _Sprite {
  final double col;
  final double row;
  final _SpriteKind kind;
  final bool chasing;

  _Sprite({
    required this.col,
    required this.row,
    required this.kind,
    this.chasing = false,
  });
}
