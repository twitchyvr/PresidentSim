# PresidentSim — Engineering Standards

## Build Before Push
- Run `xcodebuild -scheme PresidentSim build` — green build is non-negotiable before push.
- CI must be green before any merge. No exceptions.

## Error Handling
- **Never swallow exceptions silently.** Every `catch` block must either:
  - Log via `self.lastError = "..."` + `print("[ClassName] ...")` for `@Published` observability
  - Or re-throw
- Empty `catch` blocks are forbidden. They hide failures from operators and users.
- `try?` is acceptable only for operations where failure is benign (e.g., JSON parse with fallback).
- **All external API calls must have a timeout.** Use `request.timeoutInterval = 30` on URLRequests. No indefinite hangs.
- **All @Published error state must be observed in the UI.** If a class sets `lastError`, the view must display it.

## Color System
- **Always use semantic Color tokens** from the `Color` extension (defined at line 42 of `PresidentSimApp.swift`):
  - `.positive` — good outcomes, approval up, gains
  - `.danger` — bad outcomes, warnings, negative action tags
  - `.tipAccent` — lightbulb/tips, caution-level urgency
  - `.tossupAccent` — swing/tossup states
  - `.playerAccent` / `.opponentAccent` — party colors
  - `.special` — campaign/AI tags
- **Never use raw `.red` / `.green` / `.yellow` / `.blue` in computed properties** — only use raw colors when no semantic token matches the intent.
- When adding new semantic colors, update the `Color` extension — don't scatter raw colors.

## Diagnostics
- **SourceKit diagnostics are unreliable.** Always trust `xcodebuild` over SourceKit in-editor errors.
- Do not fix "Cannot find type in scope" SourceKit errors if `xcodebuild build` succeeds.

## Security Principles
- API key: loaded from `~/.PresidentSim/env` — never hardcoded, never logged
- Player-provided text (candidate name, statements): never sent to AI prompts
- AI prompts: built from typed enums (`DecisionContext`, `SpeechType`, `Tone`) — not raw user input
- Diplomacy conversation: keyword-matching only, no AI call, no injection risk

## Testing
- When adding functionality, add test coverage for the new paths
- Regression: verify existing tests still pass before pushing

## Adding Dependencies
- Any new external dependency must be approved by the user
- Document why it's needed and how it handles errors

## Performance Budgets
- **Cold start**: App window visible within 2s of launch
- **AI API calls**: 30s timeout (hard limit — no indefinite hangs)
- **Test suite**: Must pass before any push (`xcodebuild test` exit 0)
- **Memory**: No unbounded array growth — event/history arrays must have purge logic at defined limits
- **Frame time**: 60fps on standard Mac hardware — no blocking main actor work > 16ms
