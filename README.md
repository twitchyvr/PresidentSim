# PresidentSim

US Presidential election simulation with AI-driven event generation.

## Bootstrap

```bash
# 1. Generate Xcode project
xcodegen generate

# 2. Open in Xcode
open PresidentSim.xcodeproj

# 3. Build (or press Cmd+B in Xcode)
xcodebuild -project PresidentSim.xcodeproj -scheme PresidentSim -configuration Debug build
```

## Requirements

- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/nicklockwood/XcodeGen) (`brew install xcodegen`)

## Optional: AI Integration

For AI-driven events and consequences, create `~/.env` with your MiniMax API key:

```
MINIMAX_API_KEY=your_key_here
```

The app falls back to simple state updates when no API key is present.

## Architecture

- `App/` - SwiftUI app entry point and main views
- `Models/` - Game state, player, events, actions
- `Engine/` - Simulation engine, AI service, debate engine
- `Services/` - Speech synthesis, persistence
- `Resources/` - Assets, Info.plist

## Game Phases

```
preCampaign → campaign → primaries → convention → generalElection
    → transition → presidency → lameDuck → exited
```

## Status

See [SPEC.md](SPEC.md) for full implementation status.

## License

Copyright 2026. All rights reserved.
