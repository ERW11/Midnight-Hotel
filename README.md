# TRUST NO ONE: Midnight Hotel

Roblox Studio + Luau + Rojo. Server-authoritative round orchestration.

## Current status: Milestone 1C

Implemented flow:

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESETTING → WAITING`

No RESULTS state or win condition exists. PLAYING ends only when its server timer
expires. Milestone 1A player thresholds/cancellation and 1B private roles remain.
At countdown completion the server snapshots connected players, sorts by UserId,
and caps the roster at MaximumPlayers (6). Exactly one random roster index is
Saboteur; everyone else is Guest. PLAYING keeps that roster and those assignments.
Departure removes a player and their role without replacement or backfill.

## Ownership and source layout

- `src/server/init.server.luau`: starts RoundService and stops it on shutdown.
- `src/server/RoundService.luau`: owns all round states, roster, spawn-slot assignment,
  private delivery, countdown, deadline, and reset. Client input cannot change them.
- `src/server/RoleService.luau`: private server-memory role assignments and scalar
  queries. No mutable role table is exposed or replicated.
- `src/server/WorldService.luau`: generates greybox geometry and owns character
  connections, server positioning, cancellable bounded waits, and respawn routing.
- `src/client/init.client.luau`: receives only its own role and logs it in Studio.
  No area, state, completion, or timer controls; no HUD or final UI.
- `src/shared/Config.luau`: public player/timing/greybox tuning, no role assignments.
- `AGENTS.md`: project rules and current scope.

Services are children of `ServerScriptService.Server`. Config is under
`ReplicatedStorage.Shared`. Existing Rojo mappings and starter baseplate are unchanged.

## Configuration

All durations are seconds. Stop testing before editing configuration, sync, and
start a new Play session; live configuration changes are not supported.

| Setting | Value | Use |
| --- | --- | --- |
| Players.MinimumPlayers | 4 | Required when DevelopmentMode=false |
| Players.MaximumPlayers | 6 | Active roster cap, not Roblox place capacity |
| Players.DevelopmentMinimumPlayers | 1 | Required when DevelopmentMode=true |
| Timing.LobbyCountdown | 15 | Lobby countdown |
| Timing.RoleRevealDuration | 5 | Private reveal while still in lobby |
| Timing.RoundDuration | 300 | Production PLAYING duration, preserved |
| Timing.DevelopmentRoundDuration | 20 | PLAYING duration when DevelopmentMode=true |
| Timing.DevelopmentResetDelay | 2 | Pause in RESETTING in either mode |
| Timing.ResultsDuration | 10 | Reserved; RESULTS is not implemented |
| Timing.RoundDiagnosticInterval | 5 | Server timer log interval |
| Timing.CharacterPositionTimeout | 10 | Maximum wait per positioning request |
| Timing.CharacterPositionPollInterval | 0.1 | Character readiness polling interval |
| DevelopmentMode | true | Selects development minimum and round duration |

`Config.World` centralizes geometry names, centers, dimensions, spawn spacing,
marker sizes, and labels. Defaults provide six distinct spawn slots in each area.

## Greybox and positioning

WorldService creates exactly one session-owned `Workspace.MidnightHotelGreybox`:

```text
MidnightHotelGreybox/
├── Lobby/                  # Floor, four walls, Spawn01..Spawn06, area label
├── Hotel/                  # Floor, four walls, Spawn01..Spawn06, area label
└── LobbySpawn              # Neutral SpawnLocation
```

Lobby center is (0,20,0); hotel center is (0,20,600). Both floors are 80x2x60,
with simple 20-stud walls. Blue lobby markers and gold hotel markers identify
positions. Labels say MIDNIGHT HOTEL - LOBBY and HOTEL TEST AREA. These are greybox
shells, not puzzle rooms. Ordinary walking players are separated by walls and distance.
The original baseplate remains below the lobby and does not connect to the hotel.

Generation runs on the server at startup, uses no Toolbox assets, and reuses its
owned folder across Start/Stop. An unrelated existing object with the reserved
folder name causes a clear error rather than deletion. Geometry persists through
round resets; it is session infrastructure. Do not manually create this folder.

Each active roster member has a stable hotel slot chosen at roster lock, unrelated
to role. At PLAYING, only these players receive hotel destinations. Everyone else
keeps a lobby destination. Late joins in ROLE_REVEAL, PLAYING, or RESETTING cannot
enter the current roster or receive a role. Overflow players may join later rounds;
UserId ordering is deterministic, not a fair queue. More than six lobby occupants
reuse lobby slots; the intended active capacity remains six.

WorldService uses server-side Character:PivotTo and clears root velocity. If the
character/root/humanoid is unavailable or dead, it waits at most ten seconds without
blocking RoundService. New destinations cancel older requests. CharacterAdded
retries the player's current destination: hotel only for active PLAYING players,
lobby otherwise. A timeout warns and leaves the next respawn to retry. The timer
does not pause for missing characters. No client chooses a destination.

## Timer, reset, and lifecycle

PLAYING uses an os.clock deadline chosen by the server. GetRoundTimeRemaining()
returns the nonnegative rounded-up difference, zero outside PLAYING. Diagnostic
callbacks run about every five seconds; scheduler lag cannot accumulate extra
five-second chunks in the deadline. A stalled server can still process expiry late.
The existing COUNTDOWN uses one-second delayed ticks.

At expiry, RESETTING cancels the prior timer, replaces every connected player's
positioning request with a lobby destination, clears roles/active roster/hotel slots/
delivery tracking, and zeros countdown and round timer state. After two seconds it
enters WAITING and reevaluates population. A missing character may finish its bounded
lobby move after that pause; stale hotel requests cannot run. Readiness and lobby
membership persist across rounds. Roles are assigned anew only in the next cycle.

Start()/Stop() are idempotent. Stop cancels the round timer and all pending character
moves, disconnects player/remote/character events, clears all player and round data,
and immediately moves available living characters to the lobby. It does not wait
for missing characters. Start rebuilds membership and re-handshakes existing clients.
Geometry and the empty remote infrastructure are reused, not duplicated.

RoundService exposes scalar getters: GetState(), GetCountdownRemaining(),
GetRequiredPlayerCount(), GetRoundTimeRemaining(), IsActivePlayer(player), and
GetActivePlayerCount(). RoleService exposes GetRole/IsSaboteur/IsGuest/HasRole and
assignment/cleanup methods for server use only.

## Privacy

`ReplicatedStorage.MidnightHotelRemotes.PrivateRole` is server-created/verified.
It contains no role state. FireClient sends only the recipient's own role. Ready
messages only indicate that the client listener is connected; they grant no role,
roster membership, or control. Delayed active clients may receive their own role
during PLAYING, once per assignment. Late joiners and reset cycles receive no stale role.
No role Attributes, Values, folders, public tables, or role broadcasts exist.
Spawn placement is independent of role. Client role logs are Studio-only; combined
Studio Output may aggregate different clients' logs. Inspect each client separately.
Tiny rosters can permit logical inference of roles despite private delivery.

## Rojo and manual setup

From the repository root:

```sh
rojo serve default.project.json
```

Connect the Studio Rojo plugin to the local server (default port 34872), review and
apply changes. Alternatively build and open the Git-ignored generated place:

```sh
rojo build default.project.json -o Midnight-Hotel.rbxlx
```

No manual geometry, SpawnLocations, remotes, or scripts are required. The greybox
appears during Play, not in edit mode. Use a clean development place or the generated
place to avoid unrelated scripts/spawns affecting tests. Open Output and select the
server or individual client context. No dependencies were added.

## Exact Studio tests

### Solo acceptance test

1. Keep DevelopmentMode=true and default timings. Sync and start Play.
2. Verify your character appears inside MIDNIGHT HOTEL - LOBBY and the greybox
   folder contains one Lobby, one Hotel, and one LobbySpawn.
3. Observe WAITING → COUNTDOWN (15 seconds) → ROLE_REVEAL (5 seconds). The solo
   client's own Output must say Saboteur; remain in the lobby during reveal.
4. At PLAYING, verify visible movement to HOTEL TEST AREA. The server logs a
   20-second timer. Move around, then use Roblox's Reset Character action.
   After respawn, return to the hotel if PLAYING is still active, lobby otherwise.
5. At expiry, verify RESETTING moves you back to the lobby. After 2 seconds,
   WAITING transitions to a fresh countdown. Observe a second complete cycle
   without restarting Studio, duplicate ticks, duplicated geometry, or stale moves.
6. Repeat a character reset near timer expiry. The new character must end up in
   the lobby after RESETTING, not at a stale hotel destination.

### Four-player production-duration test

1. Stop Play, set only DevelopmentMode=false, sync, and start a local Studio
   server with four clients. Leave RoundDuration=300 and other defaults unchanged.
2. Each character starts in the lobby. After 15+5 seconds, all four locked players
   move to separate hotel markers. Check individual client Output: exactly one
   Saboteur and three Guests, with no role reroll at PLAYING.
3. Verify the server logs PLAYING started: 300 seconds. Wait the full five-minute
   PLAYING duration. All connected players return to the lobby, reset takes two
   seconds, and another countdown begins if four players remain.
4. In a separate run, begin with three clients: remain WAITING. Add a fourth to
   start COUNTDOWN; disconnect one before zero. Expect immediate cancellation.
   Add a replacement and confirm a fresh 15-second countdown. With five clients,
   dropping to four must not cancel/restart COUNTDOWN.

### Late join, departure, and cleanup tests

1. Add a fifth client during PLAYING. It must remain in the lobby, receive no role,
   and stay outside the roster. Reset that client's character: it stays in the lobby.
   It may qualify for the next round. For ROLE_REVEAL joins, temporarily increase
   RoleRevealDuration to 30, then restore 5. For RESETTING joins, temporarily increase
   DevelopmentResetDelay to 10, then restore 2.
2. Disconnect an active Guest during PLAYING, then repeat with the Saboteur in
   another cycle. The timer continues, roles clear for departures, and there is no
   replacement or fallback. Disconnect during RESETTING too: no crash or stalled reset.
3. If all active players leave, the timer still expires normally. A late joiner
   remains in the lobby until a future roster is selected.
4. In server Command Bar, inspect state and membership without logging secret roles:

```lua
local s = game.ServerScriptService.Server
local rounds, roles = require(s.RoundService), require(s.RoleService)
print(rounds.GetState(), rounds.GetActivePlayerCount(), rounds.GetRoundTimeRemaining())
for _, p in game.Players:GetPlayers() do
    print(p.Name, rounds.IsActivePlayer(p), roles.HasRole(p))
end
```

5. During PLAYING (and separately COUNTDOWN/RESETTING), run this server cleanup check:

```lua
local s = game.ServerScriptService.Server
local rounds, roles = require(s.RoundService), require(s.RoleService)
rounds.Stop()
rounds.Stop()
assert(rounds.GetState() == "WAITING")
assert(rounds.GetActivePlayerCount() == 0 and rounds.GetRoundTimeRemaining() == 0)
assert(rounds.GetCountdownRemaining() == 0)
for _, p in game.Players:GetPlayers() do
    assert(not roles.HasRole(p))
end
```

Wait past the old timer deadline: no stale completion should occur. Then restart:

```lua
local rounds = require(game.ServerScriptService.Server.RoundService)
rounds.Start()
rounds.Start()
```

One countdown should start, geometry should not duplicate, and role delivery and
respawn routing must still work. Restore DevelopmentMode=true and all default
settings after testing. Check Output for errors and infinite-yield warnings.

## Expected Output

Existing bootstrap/countdown/private-role messages remain. New server messages:

```text
[Midnight Hotel][WorldService] Greybox ready: Lobby and Hotel.
[Midnight Hotel][RoundService] ROLE_REVEAL complete.
[Midnight Hotel][RoundService] State=PLAYING. Players=1/1.
[Midnight Hotel][RoundService] PLAYING started: 20 seconds. Active players moving to hotel.
[Midnight Hotel][RoundService] Round timer: 15 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 10 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 5 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 0 seconds remaining.
[Midnight Hotel][RoundService] PLAYING timer complete. Temporary round end; no win condition or RESULTS.
[Midnight Hotel][RoundService] State=RESETTING. Players=1/1.
[Midnight Hotel][RoundService] Reset cleanup complete; players returning to lobby.
[Midnight Hotel][RoundService] State=WAITING. Players=1/1.
```

Counts/timing may vary with connection order and scheduler load. Departure and
late-join diagnostics identify behavior, never publicly broadcast a secret identity.

## Limits and unimplemented systems

No puzzles, sabotage abilities, voting, final escape logic, RESULTS/scoring,
rewards, progression, cosmetics, polished art, final UI/HUD, persistence,
matchmaking, or monetization. No spectator mode, fair overflow queue, Saboteur
replacement, or cooperative fallback. ResultsDuration remains unused.
This is a playable movement/timer skeleton, not completed game objectives.
Character movement is ordinary Roblox movement; server-controlled placement is
not an anti-cheat system for continuous movement. Custom rigs without a live
Humanoid/HumanoidRootPart can time out. Geometry does not auto-repair manual edits
while running. More than six lobby players may share markers.
Rojo build checks packaging only. Runtime, physics, visual layout, and multiplayer
acceptance require the Studio tests above; build success is not a Studio test result.
