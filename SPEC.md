# PresidentSim — Emergent Presidential Simulation

## Core Philosophy

**NOT a chatbot.** The AI is the *simulation engine*, not the *interface*. The player never "talks to AI" — instead, every game state change flows through AI logic that calculates emergent consequences.

Think: **SimCity + CK3 event system + AI brain = PresidentSim**

## Game Phases (State Machine)

```
[Pre-Campaign] → [Campaign] → [Primaries] → [Convention] → [General Election]
                                                                      ↓
[Impeachment/Resignation/Death] ← [Lame Duck] ← [Second Term] ← [First Term]
                                                                      ↓
                                                              [Transition] → [Presidency]
```

## Core Systems

### 1. Simulation State (`GameState`)
- **Political Capital**: Mutable resource for making moves
- **Approval Rating**: 0-100%, affected by every action
- **Economic Dashboard**: GDP growth, unemployment, inflation, stock market, national debt
- **Party Standing**: Polling data, party unity score, donor satisfaction
- **International Relations**: Various country relations, global influence score
- **News Cycle**: Media narrative, trending topics, news cycle momentum
- **Congressional Relations**: Senate/House composition, opposition party mood
- **Personal Attributes**: Age, health (for mortality calculations), family status
- **Historical Ledger**: Immutable log of all decisions and their first-order effects

### 2. Event Engine (`EventSystem`)
- **Random Events**: Economic shocks, scandals, crises, international incidents
- **Triggered Events**: Emerge from player actions via AI calculation
- **AI-Generated Events**: When player does unprecedented things, AI generates plausible events
- **Scheduled Events**: Historical events that occur at appropriate times

### 3. AI Brain (`SimulationAI`)
**Purpose**: When player does X, calculate the Y consequences that emerge.

**Called for:**
- Complex multi-variable consequence calculation (player action → multi-domain ripple effects)
- NPC behavior generation (how does Congress/World react without scripting)
- Policy outcome projection (what happens economically if we implement this policy?)
- Event interpretation (a crisis happens — AI generates realistic progression)
- Speech generation (campaign speeches, State of Union, press conferences)

**NOT a chatbot.** The AI is called internally, returns structured data, game engine handles display.

### 4. Decision System (`DecisionEngine`)
When player faces a choice:
1. Display situation context
2. Show available actions (computed from state + AI)
3. Player chooses
4. AI calculates consequences
5. State updates
6. Events may trigger
7. Display outcome

### 5. Election System
- **Primary Simulation**: Compete against AI-generated primary rivals
- **Convention**: Delegate math, platform decisions, VP selection
- **General Election**: Electoral college simulation, popular vote modeling, debate system
- **Concession/Victory**: Realistic handling

### 6. Presidency Simulation
- **Daily/Weekly Decision Loop**: Issues arrive, player responds
- **Congressional Agenda**: Bills to sign/veto, legislative priorities
- **Crisis Management**: AI generates realistic crises
- **Approval Rating Dynamics**: Complex model of what's popular vs. what's necessary
- **Second Term**: Re-election, potential constitutional crisis (impeachment risk)
- **Exit Scenarios**: Lost election, term-limited, resignation, death, impeachment

## Technical Architecture

### Stack
- **SwiftUI** (macOS app) — clean UI, good state management, native feel
- **SQLite.swift** — persistent game state
- **MiniMax API** — AI brain for consequence calculation
- **AVFoundation** — speech synthesis for speeches

### Key Files
```
PresidentSim/
├── App/
│   └── PresidentSimApp.swift
├── Models/
│   ├── GameState.swift
│   ├── Player.swift
│   ├── Event.swift
│   ├── Decision.swift
│   └── WorldState.swift
├── Engine/
│   ├── SimulationEngine.swift      # Main game loop
│   ├── EventEngine.swift           # Event generation/triggering
│   ├── AISimulationBrain.swift     # MiniMax integration
│   ├── DecisionEngine.swift        # Player choices
│   └── ElectionEngine.swift        # Election simulation
├── Views/
│   ├── MainView.swift
│   ├── Campaign/
│   ├── Presidency/
│   ├── Dashboard/
│   └── Components/
├── Services/
│   ├── MiniMaxService.swift
│   ├── SpeechService.swift
│   └── PersistenceService.swift
└── Resources/
    └── Assets.xcassets
```

## MiniMax Integration (The AI Brain)

### API Configuration
- Endpoint: `https://api.minimax.io/anthropic/v1/messages`
- Model: `MiniMax-M2.7`
- API Key: From config (already secured)

### How AI is Used (NOT as chatbot)

**1. Consequence Calculation**
```
Input: { game_state, player_action: "declare_war_on_Iran", context }
Output: {
  immediate_effects: { oil_prices: +40%, international_relations: {...}, ... },
  cascading_effects: [...],
  triggered_events: ["oil_crisis_1973_style", "domestic_protests"],
  narrative: "The decision reverberates..."
}
```

**2. Event Generation**
When random seed + state suggests crisis possibility, AI generates realistic event.

**3. Speech Generation**
Player's advisors write speeches. AI generates first-draft text. Player approves/modifies.

**4. NPC Behavior**
Congress members, foreign leaders, donors — AI models their likely responses.

## Non-Deterministic Elements

- **Dice rolls** on action outcomes (weighted by stats)
- **Random events** with configurable probability
- **AI variability** — same situation may be judged slightly differently
- **Hidden variables** — player doesn't see everything

## Emergent Gameplay Examples

- You implement universal healthcare → AI calculates: economic impact, party reactions, insurance industry response, international comparisons, generates events
- A scandal breaks → AI calculates: media cycle dynamics, resignation pressure, congressional response, your approval trajectory
- Economic crisis hits → AI generates realistic crisis progression, your options, consequences of each path

## What's Unique

1. **No scripted paths** — AI generates consequences for ANY player action
2. **True simulation** — economics, politics, international relations all affect each other
3. **AI as engine** — not a character to talk to, but the invisible logic of history
4. **Non-deterministic** — replay value through randomness + AI variability
5. **Multi-modal** — speeches can be spoken aloud via TTS

## Development Phases

### Phase 1: Core Foundation
- Game state model
- Basic UI shell
- Phase transitions (Campaign → Presidency → Exit)
- Stub AI calls (real AI integration later)

### Phase 2: Simulation Engine
- Economic model
- Political model
- Event system basics
- Decision engine

### Phase 3: AI Integration
- MiniMax service
- Consequence calculation
- Speech generation
- Event generation

### Phase 4: Polish
- Full UI
- Speech synthesis
- Persistence
- Replayability features

## Implementation Status

### Phase 1: Core Foundation ✅
- [x] Game state model (GameState, Player, WorldState, Event, Decision, Actions)
- [x] Basic UI shell (SwiftUI macOS app with sidebars, main area, toolbars)
- [x] Phase transitions (preCampaign → campaign → primaries → convention → generalElection → transition → presidency → lameDuck → exited)
- [x] Stub AI calls (MiniMaxService integration ready)

### Phase 2: Simulation Engine ✅
- [x] Economic model (GDP growth, unemployment, inflation tracking)
- [x] Political model (approval rating, party unity, congressional support)
- [x] Event system basics (lifecycle: resolve at 5 turns, remove at 10)
- [x] Decision engine (player choices with risk/reward)

### Phase 3: AI Integration ✅
- [x] MiniMax service (MiniMaxService with consequence calculation)
- [x] Consequence calculation (AI calculates multi-domain ripple effects)
- [x] Event generation (AI generates phase-appropriate events)
- [ ] Speech generation (TODO)
- [ ] NPC behavior modeling (TODO)

### Phase 4: Polish (in progress)
- [x] Electoral map with 50 states and EV counting
- [x] Approval trend chart (last 20 turns)
- [x] Political capital gauge
- [x] Command Center with 20+ actions
- [x] Briefings inbox system
- [ ] Speech synthesis (TODO)
- [ ] Persistence (TODO) - Save/load game state
- [ ] Replayability features (TODO)
