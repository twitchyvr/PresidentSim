# PresidentSim

US Presidential election simulation with AI-driven event generation.

## What Is This?

An emergent political simulation where every decision cascades through economic, political, and international systems. Not a chatbot — the AI is the *simulation engine* that calculates consequences, not a character you talk to.

Think: **SimCity + CK3 event system + AI brain = PresidentSim**

## Quick Start

```bash
# 1. Generate Xcode project
xcodegen generate

# 2. Open in Xcode
open PresidentSim.xcodeproj

# 3. Build and run (Cmd+R in Xcode)
xcodebuild -project PresidentSim.xcodeproj -scheme PresidentSim -configuration Debug build
```

## Requirements

- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/nicklockwood/XcodeGen) (`brew install xcodegen`)

## AI Integration (Optional)

For AI-driven events and consequences, create `~/. PresidentSim/env` with your MiniMax API key:

```
MINIMAX_API_KEY=your_key_here
```

Without an API key, the game uses a fallback simulation mode.

## How to Play

1. **Pre-Campaign Phase** — Configure your candidate (name, party, traits)
2. **Campaign Phase** — Build momentum, manage resources
3. **Primaries** — Compete against party rivals
4. **Convention** — Secure nomination, choose running mate
5. **General Election** — Win 270 electoral votes
6. **Presidency** — Make daily decisions, manage crises, seek re-election

### Command Center

Access via toolbar. Available actions include:
- Press appearances, rallies, media buys
- Policy announcements, legislative pushes
- Crisis response, diplomatic initiatives
- Cabinet appointments, executive orders

Each action costs Political Capital or campaign funds. Effects are calculated by the simulation engine and can trigger cascading events.

### Dashboard

Real-time view of:
- Approval rating (with 20-turn trend)
- Electoral map (50 states, 538 EVs)
- Economic indicators (GDP, unemployment, inflation)
- Political capital gauge
- Active briefings and pending decisions

## Architecture

```
PresidentSim/
├── App/                  # SwiftUI entry point and views
├── Models/               # Game state, player, events, actions
├── Engine/               # Simulation engine, AI service, election logic
├── Services/             # Speech synthesis, persistence
└── Resources/            # Assets, Info.plist
```

### Game Phases

```
preCampaign → campaign → primaries → convention → generalElection
    → transition → presidency → lameDuck → exited
```

### Key Systems

- **Simulation Brain**: MiniMax-powered consequence calculation
- **Event Engine**: AI-generated and random events with cooldowns
- **Election Engine**: Electoral college, primaries, debates
- **Persistence**: Save/load game state to JSON

## Development

### Build

```bash
xcodegen generate
xcodebuild -project PresidentSim.xcodeproj -scheme PresidentSim -configuration Debug build
```

### Test

```bash
xcodebuild test -scheme PresidentSim -configuration Debug
```

### CI

GitHub Actions runs on macOS 14 with Xcode 15.4. Build workflow:
1. Checkout
2. Install XcodeGen
3. Generate project
4. Patch format for Xcode 15.4 compatibility
5. Build

## Status

See [SPEC.md](SPEC.md) for full implementation status and roadmap.

## License

Copyright 2026. All rights reserved.
