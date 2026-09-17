import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AudioSettings.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            letterSpacing: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('MUSIC'),
              const SizedBox(height: 6),
              ValueListenableBuilder<double>(
                valueListenable: AudioSettings.musicVolume,
                builder: (context, value, _) {
                  return Slider(
                    value: value,
                    onChanged: (v) => AudioSettings.setMusicVolume(v),
                    activeColor: Colors.white70,
                    inactiveColor: Colors.white12,
                  );
                },
              ),
              const SizedBox(height: 24),
              const _SectionLabel('SOUND EFFECTS'),
              const SizedBox(height: 6),
              ValueListenableBuilder<double>(
                valueListenable: AudioSettings.sfxVolume,
                builder: (context, value, _) {
                  return Slider(
                    value: value,
                    onChanged: (v) => AudioSettings.setSfxVolume(v),
                    activeColor: Colors.white70,
                    inactiveColor: Colors.white12,
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Controls: WASD / Arrow keys to move, SPACE to listen, '
                'R to restart, ESC to pause.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
