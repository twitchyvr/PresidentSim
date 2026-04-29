# Contributing to PresidentSim

## Quick Links

- [Open Issues](https://github.com/twitchyvr/PresidentSim/issues)
- [Open Pull Requests](https://github.com/twitchyvr/PresidentSim/pulls)

## Getting Started

1. Fork the repo
2. Clone your fork
3. Run `xcodegen generate` to generate the Xcode project
4. `open PresidentSim.xcodeproj`
5. Verify build: `xcodebuild -scheme PresidentSim -configuration Debug build`
6. Verify tests: `xcodebuild -scheme PresidentSimTests -configuration Debug test`

## Branching

- Branch from `main`
- Naming: `feature/<short-description>`, `fix/<short-description>`, `docs/<short-description>`
- Example: `fix/ux-bugs-5-fixes`, `docs/add-test-command`

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new campaign rally action
fix: resolve DecisionCard immediate commit bug
docs: add test command to README
refactor: extract debate scoring into DebateEngine
```

Prefixes: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

All code in this repo is owned — no "pre-existing" or "not my changes" exceptions.

## Pull Request Process

1. **Issue first** — file a GitHub issue before submitting a PR (bug fixes excepted)
2. **One concern per PR** — separate UX fixes from refactors from new features
3. **CI must pass** — build and tests must pass before merge; investigate every failing check independently
4. **Self-review** — review your own diff before requesting review; delete debug code, ensure no `TODO`/`FIXME` left in
5. **Description** — PR body must explain *why* not just *what*; link to the issue it resolves

### PR Checklist

- [ ] Build succeeds locally (`xcodebuild ... build`)
- [ ] Tests pass (`xcodebuild ... test`)
- [ ] No `TODO`/`FIXME`/`HACK`/`XXX` in changed files
- [ ] Tech debt introduced? File a linked issue labeled `tech-debt`
- [ ] New UI change verified visually (light + dark mode if applicable)

## Tech Debt Policy

Any `TODO`, `FIXME`, `HACK`, shortcut, or known limitation must have a GitHub issue labeled `tech-debt` filed in the same commit it is introduced. No silent debt.

## Issues

- Use [GitHub Issues](https://github.com/twitchyvr/PresidentSim/issues) for bugs, features, and tech debt
- Search before filing to avoid duplicates
- Bug reports should include: steps to reproduce, expected vs actual behavior, macOS version
- Enhancement requests should explain the user need, not just the implementation approach
