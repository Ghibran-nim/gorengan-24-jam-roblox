# Gorengan 24 Jam: Awas Satpol! — Antigravity Workspace Instructions

## Vision
Build a polished, genuinely playable Roblox multiplayer tycoon/cooking/survival game set in a stylized Indonesian street-food environment. The signature experience is satisfying frying, growing a gorengan business, and escaping fair, readable Satpol PP raids.

## Source of truth
- Treat the project's approved Game Design Document (GDD) as the product vision.
- Treat current code and project configuration as the source of truth for what is actually implemented.
- If GDD details conflict with technical feasibility, security, platform policy, or player experience, document the conflict and propose a reasoned improvement.
- Never claim a feature is complete merely because files or UI exist.

## Skills
Use the specialized skills when their domain is involved:
- `roblox-game-architecture`: project structure, service boundaries, Rojo, initialization, shared contracts.
- `roblox-gameplay-engineering`: cooking, serving, inventory, cart interactions, upgrades, moment-to-moment gameplay.
- `roblox-npc-ai`: customer, Satpol, copet, preman, and special-customer behavior.
- `roblox-multiplayer-security`: remotes, server authority, validation, anti-exploit, purchases.
- `roblox-ui-ux`: HUD, menus, mobile controls, notifications, responsive layout.
- `roblox-world-building`: map, plots, safe zones, lighting, navigation, environment.
- `roblox-game-economy`: recipe margins, upgrade costs, RNG odds, progression, monetization.
- `roblox-game-audio-vfx`: sound, animation, particles, camera and feedback polish.
- `roblox-performance`: profiling, NPC/physics budgets, replication, mobile optimization.
- `roblox-qa-testing`: test plans, regression, bug triage, release gates.

Read the relevant `SKILL.md` before substantial work in that domain. Multiple skills may apply to cross-system changes.

## Non-negotiable engineering standards
1. Server-authoritative outcomes for currency, inventory, cooking quality, RNG, purchases, capture, and rewards.
2. Client handles input and presentation; never trust client-submitted results.
3. Validate every remote's payload, player state, distance, ownership, and rate.
4. Use modular Luau code and explicit service interfaces.
5. Use strict typing where practical.
6. Keep configuration values centralized and documented.
7. Avoid unbounded loops, arbitrary waits, circular dependencies, and memory leaks.
8. Do not insert unreviewed models or scripts from external assets.
9. Keep PC and mobile interaction parity for essential actions.
10. Never report tests as passed unless they were actually run.

## Product priorities
Build a fun, stable vertical slice before broad feature expansion:
1. Spawn and tutorial.
2. Player cart/plot.
3. Ingredient pickup.
4. Cooking with undercooked/crispy/burnt outcomes.
5. Customer order and serving.
6. Currency reward and HUD.
7. One meaningful upgrade.
8. Satpol warning, cart escape, safe zone, and penalty.
9. Persistence and multiplayer validation.
10. Expand recipes, events, collectibles, shops, and polish.

## Development phases
- Phase 0: audit repository, tools, Rojo mapping, dependencies, and current state.
- Phase 1: playable core cooking-to-selling loop.
- Phase 2: cart push and Satpol chase.
- Phase 3: recipes, economy, upgrades, inventory, chili RNG, persistence.
- Phase 4: multiplayer chaos, NPC variety, and random events.
- Phase 5: audio, VFX, map polish, mobile optimization, QA, beta readiness.

Do not skip validation between phases. A later phase must not hide broken core systems.

## Workflow for every task
1. Read this file and applicable skills.
2. Inspect relevant files before editing.
3. State a concise implementation plan for nontrivial work.
4. Make focused changes; preserve working functionality.
5. Update types, configuration, documentation, and tests.
6. Run available formatter, linter, type checker, Rojo build/sync validation, and tests.
7. Inspect the diff for accidental changes.
8. Report changed files, checks actually run, results, and remaining risks.

## Rojo and Studio
- Inspect `default.project.json` and installed Rojo version before changing mappings.
- Do not assume Studio-only assets are present in the filesystem.
- Use Roblox Studio Play Test and Server & Clients tests when available.
- If Studio is unavailable, state that runtime behavior remains unverified and provide exact manual test steps.

## Definition of done
A feature is done only when:
- Its behavior is implemented end-to-end.
- It is integrated with dependent systems.
- Server validation and failure states exist.
- UI and input work on target platforms.
- Relevant tests pass or unrun tests are clearly disclosed.
- Documentation is updated.
- No known critical regression remains.

## Progress tracking
Maintain `docs/DEVELOPMENT_STATUS.md` with:
- Current phase.
- Implemented and verified features.
- Implemented but unverified features.
- Not implemented features.
- Known bugs and severity.
- Tests run and results.
- Next concrete tasks.

Maintain `docs/DECISIONS.md` for important design and technical decisions, including rationale and tradeoffs.

## Communication
Be proactive and make reasonable low-risk decisions without repeatedly asking for approval. Ask only when a missing decision materially changes product direction, requires credentials/payment, risks destructive changes, or cannot be safely inferred. Do not fabricate assets, test results, API behavior, or production readiness.


## Antigravity skill discovery
Project skills are stored in `.agents/skills/<skill-name>/SKILL.md`.
Antigravity can invoke relevant skills automatically; where supported, they can also be invoked by slash command using `/<skill-name>`.
