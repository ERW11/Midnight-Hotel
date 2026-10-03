# Project rules

## Architecture and security

- Build TRUST NO ONE: Midnight Hotel with Roblox Studio, Luau, and Rojo.
- Keep server code in src/server, client code in src/client, public tuning in
  src/shared/Config.luau, and server-specific layout configuration in HotelLayout.
- Server code owns roles, locked rosters, tasks, solutions, timers, and transitions.
  Never accept client gameplay results, completion claims, or role/area selection.
- Never publicly replicate secret role assignments or personal task state through
  Attributes, Values, folders, shared modules, or broadcasts. PrivateRole delivers
  only the recipient's role; PrivateTasks delivers only the sender's own task status.
- Task readiness requests cannot assign, advance, or complete a task.
- Physical clues intentionally reveal answer fragments. Keep the authoritative
  solution and randomized placement choices server-only; do not send answer tables.
- Validate task ownership, Guest role, active roster, PLAYING/deadline, connected
  living character, symbol, actual distance, and input rate before processing.
  Validation through mutation must not yield. Attempts and completion are personal.
- Centralize configuration. Prefer small understandable modules; no frameworks,
  external packages without approval, or Toolbox scripts. English player-facing text.
- Inspect current files before edits; preserve unrelated working behavior and Rojo mappings.
- Round resets/Stop must clear tasks, roles, roster, solutions, attempts, delayed
  feedback and round connections. Geometry belongs to the session and is reused.

## Current scope: Milestone 2B personal tasks

Implemented round flow:
`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESETTING → WAITING`

RoundService owns this flow and the server timer. Only timeout ends PLAYING in 2B.
No personal task completion, including all Guests finishing, ends a round.
TaskService owns assignments: each Guest will eventually have exactly ONE Long
and ONE Short Task. In 2B every active Guest receives Restore Hotel Power / Fuse Hunt
as the Long Task. Short Task stays unassigned (nil) and incomplete (false).
Circuit Router is the planned Short Task for 2C; do not implement it yet.
Split Decisions is removed from the current roadmap.

Saboteurs have no real task records or genuine completion requirements. Do not
implement fake tasks, sabotage, killing, or voting yet. Future fake-task behavior
must not write genuine task progress. RoleService retains one random Saboteur in
multiplayer; the explicit DevelopmentSoloGuest override is limited to a one-player
Studio roster with DevelopmentMode enabled. Disable it to test solo Saboteur denial.

PuzzleService owns a per-round Fuse Hunt sequence and separate per-Guest attempts.
TaskService owns Long/Short assignment and completion records. The same four clues
can serve multiple Guests, but completing/resetting an attempt affects only its owner.
WorldService owns geometry, readable SurfaceGui signs, physical clue signs, positioning,
bounded character waits, and respawn routing. HotelLayout defines eight valid clue
locations across Bedroom, Bathroom, Reception, Hallway, Maintenance, and Storage.
Choose four distinct locations each round and randomize clue-number placement.
Do not put all clues back at the Fuse panel or reintroduce overlapping billboards.

Late joiners stay in the lobby, with no role or task for the current roster.
Respawns route active PLAYING players to the hotel, preserving their task progress.
DevelopmentRoundDuration remains 60; production RoundDuration remains 300 seconds.
Personal status is shown locally on existing panel signs, not a final HUD.

Do not add Circuit Router, Split Decisions, Room 2/3 puzzles, sabotage, voting,
killing, final escape/Escape Alone, RESULTS/scoring, rewards, progression, DataStore,
MemoryStore, MessagingService, matchmaking, spectator mode, monetization, polished
art, or final UI. Later systems require a new task.

## Verification and delivery

- Keep README truthful about implemented behavior and validation limits.
- Run available Rojo/build/whitespace checks. Build success is not a Studio runtime test.
- Report changed files, checks, exact manual test steps, and remaining limitations.
- No commits or pushes unless explicitly authorized.
