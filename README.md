# Hero Fighter

2D fighting game built with Flutter + Flame Engine. 11 heroes, real-time multiplayer, AI opponents, cross-platform.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Flame](https://img.shields.io/badge/Flame-1.37.0-orange)
![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20iOS%20%7C%20Android%20%7C%20Desktop-green)

## Features

- **11 Unique Heroes** across 3 factions (Three Kingdoms, Mythology, Warring States)
- **Combat System** — combo chains, directional attacks, unique skills per hero
- **Real-time Multiplayer** — WebSocket-based with room management and matchmaking
- **LAN Discovery** — auto-discover game servers on local network
- **AI Opponents** — 3 difficulty levels (easy/medium/hard)
- **Cross-platform** — Web, iOS, Android, macOS, Windows, Linux
- **Touch Controls** — virtual joystick and action buttons for mobile
- **Particle Effects** — hit impacts, skill visuals, death animations

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Client | Flutter 3.x + Flame 1.37.0 |
| Server | Node.js + Express + WebSocket |
| Database | SQLite (better-sqlite3) |
| Deployment | Docker + docker-compose |

## Getting Started

### Prerequisites

- Flutter SDK `>=3.11.4`
- Node.js (for multiplayer server)
- Docker (optional, for server deployment)

### Run the Game

```bash
# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on iOS/Android/Desktop
flutter run
```

### Run the Server (Multiplayer)

```bash
cd server
npm install
npm start
```

Or with Docker:

```bash
docker-compose up -d
```

## Project Structure

```
lib/
├── game/
│   ├── heroes/        # 11 hero definitions + registry
│   ├── components/    # Fighter, Projectile, ParticleSystem
│   ├── audio/         # SynthAudio (Web Audio API)
│   └── ai/           # AI controller (3 difficulty levels)
├── network/          # WebSocket client + NetworkManager
├── screens/          # Game screens (menu, lobby, battle)
└── data/             # Player stats, nickname, device ID

server/
├── index.js          # Express + WebSocket server
├── game-logic.js     # Room management, matchmaking
└── database.js       # SQLite stats persistence
```

## Heroes

### Three Kingdoms (三国)

| Hero | Role | HP | Speed | Signature Skill |
|------|------|-----|-------|----------------|
| 吕布 | Tank | 1200 | 140 | 天下无双 — 8 piercing projectiles in circle |
| 诸葛亮 | Mage | 700 | 190 | 万箭齐发 — 7 projectiles in fan spread |
| 关羽 | Bruiser | 1100 | 160 | 青龙偃月 — Dash + piercing slash |
| 貂蝉 | Assassin | 750 | 200 | 倾城之舞 — 5 freeze projectiles |

### Mythology (神话)

| Hero | Role | HP | Speed | Signature Skill |
|------|------|-----|-------|----------------|
| 少林武僧 | Fighter | — | — | Close-range combo |
| 后羿 | Archer | — | — | Multi-arrow volley |
| 雷震子 | Caster | — | — | Lightning strikes |
| 蚩尤 | Tank | — | — | AOE slam |

### Warring States (战国)

| Hero | Role | HP | Speed | Signature Skill |
|------|------|-----|-------|----------------|
| 鬼谷子 | Trickster | — | — | Illusion projectiles |
| 盾卫将军 | Defender | — | — | Shield charge |
| 墨家机关师 | Engineer | — | — | Mechanical turrets |

## Combat System

- **Normal Attack** — Each hero has unique combo chains (1-3 hits with increasing damage)
- **Directional Attacks** — Forward/Up/Down inputs modify attack (launcher, slam, charge)
- **Skills** — Unique per hero, cooldown-based, produce projectiles or dash effects
- **Knockback** — Attacks produce directional knockback proportional to damage

## Multiplayer

The game uses WebSocket for real-time communication:

1. **Connect** to server (LAN discovery or manual URL)
2. **Create/Join** a room
3. **Select Hero** and ready up
4. **Fight** with input synced at 60fps
5. **Stats** recorded to SQLite after each match

## Testing

```bash
# Run all tests (177 tests)
flutter test

# Run specific test file
flutter test test/hero_data_test.dart
flutter test test/combat_system_test.dart
flutter test test/ai_controller_test.dart
```

### Test Coverage

| Module | Tests | Coverage |
|--------|-------|----------|
| Hero Data & Registry | 143 | All 11 heroes, skills, stats, balance |
| Combat System | 12 | Damage calc, knockback, combos |
| AI Controller | 8 | Difficulty levels, update cycle |
| Player Stats | 22 | Record, serialize, ranking |
| Nickname | 8 | Display name formatting |
| Network Models | 5 | LanServer, ConnectionState |
| Touch Controls | 14 | All screen sizes |
| Widget | 7 | App launch |

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for full server deployment guide including:
- Docker setup
- Environment variables
- Nginx reverse proxy
- SSL/TLS configuration
- Monitoring

## License

Private project.
