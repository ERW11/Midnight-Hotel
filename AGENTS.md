# Project rules

## Architecture and security

- Build TRUST NO ONE: Midnight Hotel with Roblox Studio, Luau, and Rojo.
- Keep server code in `src/server`, client code in `src/client`, and public shared
  modules in `src/shared`. Keep configuration separate from behavior.
- Gameplay must be server-authoritative. Never trust client-submitted gameplay
  results; validate requests and derive outcomes on the server.
- Never replicate secret role information publicly. Keep role assignments and
  authoritative round state server-only. When implemented, deliver only the
  intended player's role privately.
- Shared modules are visible to all clients. `src/shared/Config.luau` contains
  only public tuning, never secrets or per-player role data.
- Centralize configuration instead of scattering magic numbers. Durations are seconds.
- Prefer simple, understandable, maintainable modules over frameworks.
- Do not add external packages without explicit approval. Do not use Toolbox scripts.
- All player-facing text must be English.
- Inspect existing structure, starter files, and Rojo mappings before editing.
  Do not rewrite unrelated working code. Adjust `default.project.json` only if needed.
- Cleanly reset all round-created systems and resources between rounds, including
  connections, tasks, instances, roster data, and state.

## Scope

The current foundation contains only configuration, minimal server/client
module-loading bootstraps, and documentation. Gameplay is NOT implemented.
Do not implement future systems without a new task authorizing them.

Eventual Milestone 1 flow:

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESULTS → RESETTING → WAITING`

Eventual features: lobby waiting, configurable minimum players, countdown,
private Guest/Saboteur assignment, active-roster teleportation to a greybox hotel,
round timer, simple exit detection, results, full reset, late joiners outside
active rounds, and a development/solo testing override. The server must decide
whether to apply the development minimum; clients cannot authorize round changes.

Do not add DataStore, MemoryStore, MessagingService, monetization, progression,
matchmaking, puzzles, sabotage abilities, voting, or final hotel art yet.
Do not create map geometry or UI during this foundation task.

## Verification and delivery

- Keep README status accurate; configuration is not implemented gameplay.
- Validate Rojo builds when the CLI is available. Check runtime module loading
  and server/client Output in Studio; never claim an unperformed test.
- Report changed files, verification results, manual checks, and remaining work.
- Do not commit or push unless the user explicitly authorizes it.
