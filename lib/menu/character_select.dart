import 'package:flutter/material.dart';

import 'package:demo_app/audio/audio_manager.dart';
import 'package:demo_app/game/game_screen.dart' as game;
import 'package:demo_app/game/models/character.dart';

class CharacterSelect extends StatefulWidget {
  const CharacterSelect({super.key});

  @override
  State<CharacterSelect> createState() => _CharacterSelectState();
}

class _CharacterSelectState extends State<CharacterSelect> {
  int selectedIndex = 0;

  Character get selectedCharacter {
    return Character.all[selectedIndex];
  }

  void _startGame() {
    UiSound.click();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          return game.GameScreen(
            character: selectedCharacter,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final character = selectedCharacter;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white70,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'SELECT SURVIVOR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            letterSpacing: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Expanded(
              child: PageView.builder(
                itemCount: Character.all.length,
                onPageChanged: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                itemBuilder: (_, index) {
                  final item = Character.all[index];

                  return _CharacterCard(
                    character: item,
                    selected: index == selectedIndex,
                  );
                },
              ),
            ),

            Text(
              character.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 5,
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
              ),
              child: Text(
                character.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(
                  title: 'MOVE',
                  value: character.movementSanityCost
                      .toStringAsFixed(2),
                ),
                _Stat(
                  title: 'LISTEN',
                  value: character.listenCost
                      .toStringAsFixed(0),
                ),
                _Stat(
                  title: 'RECOVERY',
                  value: character.loopSanityRecovery
                      .toStringAsFixed(0),
                ),
              ],
            ),

            if (character.stealthMultiplier != 1.0 ||
                character.stabilizerBonusMultiplier != 1.0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: character.accentColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  character.stealthMultiplier != 1.0
                      ? 'PASSIVE: HARDER TO DETECT'
                      : 'PASSIVE: STRONGER STABILIZERS',
                  style: TextStyle(
                    color: character.accentColor,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: 260,
              height: 52,
              child: OutlinedButton(
                onPressed: _startGame,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  'START',
                  style: TextStyle(
                    color: Colors.white,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Character character;
  final bool selected;

  const _CharacterCard({
    required this.character,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: selected ? 260 : 240,
        height: selected ? 340 : 320,
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          border: Border.all(
            color: selected
                ? character.accentColor.withOpacity(0.85)
                : Colors.white12,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: character.accentColor.withOpacity(0.18),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              character.icon,
              color: selected ? character.accentColor : Colors.white70,
              size: 90,
            ),

            const SizedBox(height: 30),

            Text(
              character.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              character.type.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;

  const _Stat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}