# THE LOOP

**You have been here before.**

A procedurally generated, **first-person** horror-maze survival game built
with Flutter. Find the exit before your sanity runs out — or before *the
Watcher* finds you first.

### ▶️ [Play it now — no install required](https://the-loop-mazegame.netlify.app)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey)
![Live Demo](https://img.shields.io/badge/demo-live-brightgreen?logo=netlify&logoColor=white)

<!-- Swap this for an actual screenshot or GIF of gameplay once you have one -->
<!-- ![gameplay](docs/gameplay.gif) -->

## About

Every run drops you into a maze that regenerates from scratch. Something is
in there with you. It can't see you unless you make noise or wander too
close — but the longer you survive, the sharper its senses get, the bigger
the maze grows, and the more of *them* start showing up.

There is no combat. There is no map. You see the maze the way you'd really
see it: one corridor at a time, fog creeping in from the edges, never quite
sure what's behind you. There's just you, your sanity meter, and the sound of
your own footsteps.

Loop 1 is easy. Loop 1 is a lie.

## Features

- **First-person 3D view** — a Wolfenstein-style raycaster with textured
  walls, depth fog, head-bob, and billboarded enemies, all rendered in pure
  Dart/Canvas (no 3D engine). Steps and turns are tile-based but animate
  smoothly
- **Procedural mazes** that regenerate every run and grow larger (and scarier)
  with each loop you survive — 15×15 to start, scaling up to 41×41
- **A stalking enemy AI** (the Watcher) with idle / wandering / investigating
  / searching / chasing states, plus weaker "Drifter" enemies that start
  appearing from loop 3 onward
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
| Step forward / backward | `W` / `S` or `↑` / `↓` |
| Turn left / right | `A` / `D` or `←` / `→` |
| Listen (detect nearby danger) | `Space` |
| Restart | `R` |
| Pause | `Esc` |

Pro tip: LISTEN costs you sanity every time you use it. Spam it like a
coward and you'll lose your mind before anything even finds you.

## Getting started

```bash
flutter pub get
flutter run
```

Requires the Flutter SDK (stable channel). Tested targets: Android, iOS,
Web, and desktop (Windows/macOS/Linux) via standard Flutter tooling.

Or just [play the web build](https://the-loop-mazegame.netlify.app) and skip
all that.

## Tech notes

This project is a good example of a few things done "properly" rather than
hacked together:

- A `GameEngine` fully decoupled from the widget tree — all game state,
  timers, and rules live outside `Widget` classes and are driven by a simple
  tick loop
- A dedicated enemy AI state machine (`EnemyAI`) shared across every enemy
  instance
- The whole 3D view is a single `CustomPainter` (`RaycastPainter`): one DDA
  ray per screen column marched through the same `List<List<bool>>` maze the
  engine already uses, wall textures sampled one pixel-column per ray, and
  sprites projected and occluded against a per-column depth buffer
- A `CameraState` that interpolates the rendered position/angle toward the
  engine's instant, tile-based player position every frame — the engine never
  knows the camera exists, so gameplay rules are identical to before
- Camera repaints are driven by a `Ticker` + `repaint:` listenable, so the 3D
  view runs at display refresh rate without rebuilding the HUD
- An `AudioManager` that manages looping ambient/chase/heartbeat beds plus
  one-shot SFX, all wrapped defensively so audio failures never crash the
  game

## Roadmap ideas

- [ ] More enemy archetypes with distinct behavior (not just stat variants)
- [ ] A proper minimap / memory mechanic
- [ ] Touch controls (on-screen D-pad / swipe-to-turn) for mobile browsers
- [ ] True floor/ceiling casting and torch sprites in the 3D view
- [ ] Achievements tied to specific loop milestones
- [x] Web build deployed via Netlify

## License

MIT — see [LICENSE](LICENSE). Do whatever you want with it.
