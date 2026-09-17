# THE LOOP

**You have been here before.**

A procedurally generated horror-maze survival game built with Flutter. Find
the exit before your sanity runs out — or before *the Watcher* finds you
first.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey)

<!-- Swap this for an actual screenshot or GIF of gameplay once you have one -->
<!-- ![gameplay](docs/gameplay.gif) -->

## About

Every run drops you into a maze that regenerates from scratch. Something is
in there with you. It can't see you unless you make noise or wander too
close — but the longer you survive, the sharper its senses get, the bigger
the maze grows, and the more of *them* start showing up.

There is no combat. There is no map. There's just you, your sanity meter,
and the sound of your own footsteps.

## Features

- **Procedural mazes** that regenerate every run and grow larger (and scarier)
  with each loop you survive — 15×15 to start, scaling up to 41×41
- **A stalking enemy AI** (the Watcher) with idle / wandering / investigating
  / searching / chasing states, plus weaker "Drifter" enemies that start
  appearing from loop 3 onward
- **5 playable characters**, each with real tradeoffs — movement cost, listen
  cost, sanity recovery, stealth, and stabilizer effectiveness all differ
- **A sanity system** — move carefully, use LISTEN to detect danger at a
  cost, and collect stabilizers to recover
- **Full original audio** — every sound effect and music track is
  synthesized procedurally (no samples, no copyrighted audio), with dynamic
  music that crossfades in as danger gets closer, plus a persistent
  volume-controlled settings screen
- **A shifting color palette** — 5 visual themes cycle with each loop, so the
  maze never looks quite the same twice
- **Procedural, tileable wall/floor textures**, generated rather than drawn
  by hand
- **Persisted progress** — your deepest loop reached is saved locally

## Controls

| Action | Key |
|---|---|
| Move | `WASD` or Arrow Keys |
| Listen (detect nearby danger) | `Space` |
| Restart | `R` |
| Pause | `Esc` |

## Getting started

```bash
flutter pub get
flutter run
```

Requires the Flutter SDK (stable channel). Tested targets: Android, iOS,
Web, and desktop (Windows/macOS/Linux) via standard Flutter tooling.

## Tech notes

This project is a good example of a few things done "properly" rather than
hacked together:

- A `GameEngine` fully decoupled from the widget tree — all game state,
  timers, and rules live outside `Widget` classes and are driven by a simple
  tick loop
- A dedicated enemy AI state machine (`EnemyAI`) shared across every enemy
  instance
- Everything rendered through a single `CustomPainter` — no image assets are
  required for gameplay elements; walls/floor use `ImageShader` for tiled
  procedural textures
- An `AudioManager` that manages looping ambient/chase/heartbeat beds plus
  one-shot SFX, all wrapped defensively so audio failures never crash the
  game

## Roadmap ideas

- [ ] More enemy archetypes with distinct behavior (not just stat variants)
- [ ] A proper minimap / memory mechanic
- [ ] Achievements tied to specific loop milestones
- [ ] Web build deployed via GitHub Pages

## License

MIT — see [LICENSE](LICENSE). Do whatever you want with it.
