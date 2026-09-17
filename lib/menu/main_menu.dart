import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import 'character_select.dart';
import 'settings_screen.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _bestLoop = 1;

  @override
  void initState() {
    super.initState();
    MenuMusic.start();
    AudioSettings.loadBestLoop().then((value) {
      if (mounted) {
        setState(() {
          _bestLoop = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'THE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                  letterSpacing: 12,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'LOOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'YOU HAVE BEEN HERE BEFORE.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),

              if (_bestLoop > 1) ...[
                const SizedBox(height: 14),
                Text(
                  'DEEPEST LOOP REACHED: $_bestLoop',
                  style: const TextStyle(
                    color: Color(0xFF6FD8FF),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],

              const SizedBox(height: 70),

              _MenuButton(
                title: 'ENTER THE LOOP',
                onPressed: () {
                  UiSound.click();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CharacterSelect(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              _MenuButton(
                title: 'HOW TO PLAY',
                onPressed: () {
                  UiSound.click();
                  _showHowToPlay(context);
                },
              ),

              const SizedBox(height: 16),

              _MenuButton(
                title: 'SETTINGS',
                onPressed: () {
                  UiSound.click();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 70),

              const Text(
                'v0.2.0',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),

          title: const Text(
            'HOW TO PLAY',
            style: TextStyle(
              color: Colors.white,
            ),
          ),

          content: const Text(
            'Find the exit.\n\n'
            'Use WASD or the arrow keys to move.\n\n'
            'Use LISTEN to detect nearby danger.\n\n'
            'Protect your sanity.\n\n'
            'Collect stabilizers to recover sanity.\n\n'
            'From loop 3 onward, Drifters begin roaming too '
            '\u2014 they are weaker than the Watcher, but they add up.\n\n'
            'Escape the loop.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 54,

      child: OutlinedButton(
        onPressed: onPressed,

        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.white.withOpacity(0.35),
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
