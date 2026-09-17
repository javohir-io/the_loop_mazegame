import 'package:flutter/material.dart';

enum CharacterType {
  survivor,
  runner,
  technician,
  medic,
  wanderer,
}

class Character {
  final CharacterType type;
  final String name;
  final String description;

  final double movementSanityCost;
  final double listenCost;
  final double loopSanityRecovery;

  /// Multiplies the sanity gained from picking up a stabilizer.
  /// 1.0 = normal, higher = better at healing.
  final double stabilizerBonusMultiplier;

  /// Multiplies how far the Watcher can detect this character.
  /// Below 1.0 means quieter / harder to spot.
  final double stealthMultiplier;

  final IconData icon;
  final Color accentColor;

  const Character({
    required this.type,
    required this.name,
    required this.description,
    required this.movementSanityCost,
    required this.listenCost,
    required this.loopSanityRecovery,
    required this.icon,
    required this.accentColor,
    this.stabilizerBonusMultiplier = 1.0,
    this.stealthMultiplier = 1.0,
  });

  static const survivor = Character(
    type: CharacterType.survivor,
    name: 'SURVIVOR',
    description:
        'A balanced survivor with no major weaknesses.',
    movementSanityCost: 0.35,
    listenCost: 3,
    loopSanityRecovery: 12,
    icon: Icons.person,
    accentColor: Color(0xFFE6F6FF),
  );

  static const runner = Character(
    type: CharacterType.runner,
    name: 'RUNNER',
    description:
        'Moves efficiently through the loop but has weaker recovery.',
    movementSanityCost: 0.20,
    listenCost: 4,
    loopSanityRecovery: 8,
    icon: Icons.directions_run,
    accentColor: Color(0xFFFFD37A),
  );

  static const technician = Character(
    type: CharacterType.technician,
    name: 'TECHNICIAN',
    description:
        'Experienced with strange signals. LISTEN costs less.',
    movementSanityCost: 0.45,
    listenCost: 1,
    loopSanityRecovery: 15,
    icon: Icons.settings,
    accentColor: Color(0xFF7CC7FF),
  );

  static const medic = Character(
    type: CharacterType.medic,
    name: 'MEDIC',
    description:
        'Trained to stabilize trauma fast. Stabilizers restore '
        'far more sanity, but every step still costs full price.',
    movementSanityCost: 0.35,
    listenCost: 3,
    loopSanityRecovery: 14,
    stabilizerBonusMultiplier: 1.6,
    icon: Icons.healing,
    accentColor: Color(0xFF8FFF6B),
  );

  static const wanderer = Character(
    type: CharacterType.wanderer,
    name: 'WANDERER',
    description:
        'Moves quietly. The Watcher notices this survivor from '
        'much closer range \u2014 but recovers sanity slowly.',
    movementSanityCost: 0.30,
    listenCost: 3.5,
    loopSanityRecovery: 7,
    stealthMultiplier: 0.72,
    icon: Icons.dark_mode,
    accentColor: Color(0xFFB98CFF),
  );

  static const List<Character> all = [
    survivor,
    runner,
    technician,
    medic,
    wanderer,
  ];
}
