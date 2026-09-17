import 'package:flutter/material.dart';

/// Every loop the player survives shifts the palette of the maze.
/// The world never looks *safe*, but it stops looking *the same*.
class LoopTheme {
  final String label;

  final Color floorTint;
  final Color wallTint;
  final Color gridLine;

  final Color playerColor;
  final Color exitColor;
  final Color stabilizerColor;

  final Color watcherColor;
  final Color secondaryEnemyColor;

  final Color ambientGlow;

  const LoopTheme({
    required this.label,
    required this.floorTint,
    required this.wallTint,
    required this.gridLine,
    required this.playerColor,
    required this.exitColor,
    required this.stabilizerColor,
    required this.watcherColor,
    required this.secondaryEnemyColor,
    required this.ambientGlow,
  });

  static const List<LoopTheme> _palettes = [
    LoopTheme(
      label: 'COLD STATIC',
      floorTint: Color(0xFF0A0D10),
      wallTint: Color(0xFF141A1F),
      gridLine: Color(0xFF3A6E8C),
      playerColor: Color(0xFFE6F6FF),
      exitColor: Color(0xFF55E0C4),
      stabilizerColor: Color(0xFF6FD8FF),
      watcherColor: Color(0xFFFF4D4D),
      secondaryEnemyColor: Color(0xFFB37CFF),
      ambientGlow: Color(0xFF2A6A8F),
    ),
    LoopTheme(
      label: 'SICK GREEN',
      floorTint: Color(0xFF090C08),
      wallTint: Color(0xFF141E12),
      gridLine: Color(0xFF4C7A3A),
      playerColor: Color(0xFFEFFFE8),
      exitColor: Color(0xFFCFFF5C),
      stabilizerColor: Color(0xFF8FFF6B),
      watcherColor: Color(0xFFFF5C5C),
      secondaryEnemyColor: Color(0xFFFFC24B),
      ambientGlow: Color(0xFF3E6B2C),
    ),
    LoopTheme(
      label: 'RUST WARNING',
      floorTint: Color(0xFF0D0806),
      wallTint: Color(0xFF231310),
      gridLine: Color(0xFF8C4A2E),
      playerColor: Color(0xFFFFF1E6),
      exitColor: Color(0xFFFFB347),
      stabilizerColor: Color(0xFFFFD37A),
      watcherColor: Color(0xFFFF3B3B),
      secondaryEnemyColor: Color(0xFF7CC7FF),
      ambientGlow: Color(0xFF8A3E1E),
    ),
    LoopTheme(
      label: 'DEEP VIOLET',
      floorTint: Color(0xFF0A0812),
      wallTint: Color(0xFF1B1330),
      gridLine: Color(0xFF6B4FA8),
      playerColor: Color(0xFFF2E9FF),
      exitColor: Color(0xFFB98CFF),
      stabilizerColor: Color(0xFFE0A6FF),
      watcherColor: Color(0xFFFF4470),
      secondaryEnemyColor: Color(0xFF6BFFDA),
      ambientGlow: Color(0xFF4E2E8C),
    ),
    LoopTheme(
      label: 'BLOOD SIGNAL',
      floorTint: Color(0xFF0C0505),
      wallTint: Color(0xFF230C0C),
      gridLine: Color(0xFF9A2E2E),
      playerColor: Color(0xFFFFECEC),
      exitColor: Color(0xFFFF7A7A),
      stabilizerColor: Color(0xFFFFB4B4),
      watcherColor: Color(0xFFFF1A1A),
      secondaryEnemyColor: Color(0xFFFFD23B),
      ambientGlow: Color(0xFF7A1E1E),
    ),
  ];

  /// Cycles through the palette list, so the loop always feels
  /// like it is *changing* even after many runs.
  static LoopTheme forLoop(int loopNumber) {
    final index = (loopNumber - 1) % _palettes.length;
    return _palettes[index < 0 ? 0 : index];
  }
}
