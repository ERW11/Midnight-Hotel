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

Milestone 1C adds PLAYING and RESETTING to the tested WAITING/COUNTDOWN/ROLE_REVEAL flow. RoundService
owns a capped roster snapshot; late joiners cannot enter the current roster.
RoleService stores authoritative secret assignments only in server memory.
PrivateRole sends only the recipient's own role; client readiness is never eligibility.
Never replicate a role table, role Attributes, or the Saboteur identity publicly.
PLAYING preserves roles and roster and uses a server-owned deadline. Its timer
ends at a temporary RESETTING boundary, not RESULTS or a win condition.
WorldService owns Workspace.MidnightHotelGreybox, deterministic lobby/hotel geometry,
server positioning, bounded character waits, and respawn routing. Never put roles
in world objects. Replace pending moves when destinations change; clean them on Stop.
Late joiners stay in the lobby; active players respawn in the hotel only during PLAYING.
DevelopmentRoundDuration is 20 seconds; production RoundDuration remains 300.
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
Only the minimal Milestone 1C greybox and world-space area labels are authorized.
Do not build final hotel art, puzzle rooms, final UI, or a timer HUD.

## Verification and delivery

- Keep README status accurate; configuration is not implemented gameplay.
- Validate Rojo builds when the CLI is available. Check runtime module loading
  and server/client Output in Studio; never claim an unperformed test.
- Report changed files, verification results, manual checks, and remaining work.
- Do not commit or push unless the user explicitly authorizes it.
