# TRUST NO ONE: Midnight Hotel

Roblox Studio + Luau + Rojo. Server-authoritative round orchestration.

## Current status: Milestone 2A - Room 1: The Fuse Room

Implemented flow:

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESETTING → WAITING`

No RESULTS state exists. PLAYING ends on timeout or server-confirmed Fuse Room completion. Milestone 1A player thresholds/cancellation and 1B private roles remain.
At countdown completion the server snapshots connected players, sorts by UserId,
and caps the roster at MaximumPlayers (6). Exactly one random roster index is
Saboteur; everyone else is Guest. PLAYING keeps that roster and those assignments.
Departure removes a player and their role without replacement or backfill.

## Ownership and source layout

- `src/server/init.server.luau`: starts RoundService and stops it on shutdown.
- `src/server/RoundService.luau`: owns all round states, roster, spawn-slot assignment,
  private delivery, countdown, deadline, and reset. Client input cannot change them.
- `src/server/PuzzleService.luau`: owns randomized Fuse Room state, validated prompt handlers, completion, and cleanup.
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
| Timing.DevelopmentRoundDuration | 60 | PLAYING duration when DevelopmentMode=true |
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

Lobby center is (0,20,0); hotel center is (0,20,600). The lobby floor is 80x2x60; the Fuse Room floor is 120x2x90,
with 20-stud lobby walls and 30-stud Fuse Room walls. Blue lobby markers and gold hotel markers identify
positions. Labels say MIDNIGHT HOTEL - LOBBY and ROOM 1 - THE FUSE ROOM. These are greybox
shells; the Hotel now contains Room 1 controls, slots, and clues. Ordinary walking players are separated by walls and distance.
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

At timeout or objective completion, RESETTING deactivates and clears the puzzle, cancels the prior timer, replaces every connected player's
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
4. At PLAYING, verify visible movement to ROOM 1 - THE FUSE ROOM. The server logs a
   60-second timer. For this timer regression test, leave the puzzle unsolved. Move around, then use Roblox's Reset Character action.
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
3. Verify the server logs PLAYING started: 300 seconds. Leave the puzzle unsolved and wait the full five-minute
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
[Midnight Hotel][RoundService] PLAYING started: 60 seconds. Active players moving to hotel.
[Midnight Hotel][RoundService] Round timer: 55 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 10 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 5 seconds remaining.
[Midnight Hotel][RoundService] Round timer: 0 seconds remaining.
[Midnight Hotel][RoundService] PLAYING timer complete. Resetting unfinished round; no RESULTS.
[Midnight Hotel][RoundService] State=RESETTING. Players=1/1.
[Midnight Hotel][RoundService] Reset cleanup complete; players returning to lobby.
[Midnight Hotel][RoundService] State=WAITING. Players=1/1.
```

Counts/timing may vary with connection order and scheduler load. Departure and
late-join diagnostics identify behavior, never publicly broadcast a secret identity.

## Limits and unimplemented systems

No Room 2/3, sabotage abilities, voting, final escape logic/Escape Alone, RESULTS/scoring,
rewards, progression, cosmetics, polished art, final UI/HUD, persistence,
matchmaking, or monetization. No spectator mode, fair overflow queue, Saboteur
replacement, or cooperative fallback. ResultsDuration remains unused.
Room 1 is the only implemented objective. Later rooms and final game objectives are unimplemented.
Character movement is ordinary Roblox movement; server-controlled placement is
not an anti-cheat system for continuous movement. Custom rigs without a live
Humanoid/HumanoidRootPart can time out. Geometry does not auto-repair manual edits
while running. More than six lobby players may share markers.
Rojo build checks packaging only. Runtime, physics, visual layout, and multiplayer
acceptance require the Studio tests above; build success is not a Studio test result.


## Milestone 2A puzzle architecture and world

DevelopmentRoundDuration changed from **20 to 60 seconds** to allow solo clue
reading, travel, incorrect-input recovery, and a successful attempt. Production
RoundDuration remains **300**. Other existing player/round settings are preserved.
New Config.FuseRoom tuning: InteractionDistance=12 studs, InteractionCooldown=0.35
seconds per player, IncorrectFeedbackDuration=2 seconds, CompletionDelay=3 seconds.
The symbol alphabet and layout settings are also centralized there; no answer is
stored in Config. The alphabet is CIRCLE, TRIANGLE, DIAMOND, CROSS, identified by
English words rather than color. Every connected active player, including the
Saboteur, can solve the puzzle; no sabotage abilities exist.

WorldService builds this once inside the existing Hotel shell:

```text
Workspace.MidnightHotelGreybox.Hotel.FuseRoom/
├── ControlPanel                         # Backing for the four slot signs
├── StatusSign/Display/Text               # Progress/error/completion status
├── RoomSign/Display/Text                 # Inward-facing room name
├── ObjectiveSign/Display/Text            # RESTORE POWER and instructions
├── Slot1..Slot4/Display/Text              # Left-to-right numbered slots
├── Control_CIRCLE/                       # Likewise TRIANGLE, DIAMOND, CROSS
│   ├── Display/Text
│   └── InstallFuse                       # ProximityPrompt
└── Clue1..Clue4/Display/Text              # Four separate corner displays
```

The panel sits near the north wall; controls are spaced 26 studs apart in front
of it. Clues sit on the west/east walls and two separated south-wall positions, facing inward. The center/spawn lanes
remain clear. No new remotes, client scripts, external assets, or final HUD were
added. Geometry persists through rounds, and prompts are disabled outside play.
WorldService provides server view references through GetFuseRoom(); it does not
own the answer. The new objects are deterministic and created only with the room.

PuzzleService.Start(canInteract, onCompleted) resets old state, clones the four
symbols, and performs a Random-based Fisher-Yates shuffle. Each symbol appears
exactly once. Every round draws a fresh permutation; the same permutation can
legitimately repeat (1 in 24), so a repeated answer is not evidence of stale state.
Only a private module-local table holds the authoritative sequence. The module
exposes GetProgress()/IsComplete() scalars, not an answer getter. Each physical
clue is updated with POSITION 1..4 and that position's symbol. Visible clue text
is intentional public information and is readable by clients; answer secrecy from
clients reading those clues is not promised. Server authority prevents false
completion claims, not automatic reading of visible clues or movement cheating.
No full-answer payload, attribute, Value, or shared module is created. Secret
player roles retain their separate existing privacy boundary.

Each server prompt handler checks current puzzle generation, active/not complete,
PLAYING and unexpired round deadline through the server predicate, active roster,
connected player, living character/HumanoidRootPart in Workspace, valid symbol,
and actual root-to-control distance <=12 studs. A 0.35-second per-player cooldown
limits accepted attempts, including wrong ones. Rejected requests do not change
progress or error feedback. Native prompt visibility/activation is not trusted as
proof of eligibility or distance. The client cannot provide a target symbol value;
the handler closes over the server-created control's symbol.

Handlers do not yield between validation and state mutation; a processing guard
also prevents reentry. Simultaneous inputs serialize in server arrival order. Two
players entering the same symbol can therefore produce one correct input followed
by an incorrect duplicate and a reset; no player owns or consumes a fuse.

Accepted correct input fills the next numbered slot and updates progress. Wrong
or already-used symbols clear all entered symbols and show
INCORRECT - SEQUENCE RESET for up to two seconds. The next accepted input cancels
that feedback and can progress immediately (subject only to the small input
cooldown). Clues stay unchanged and no damage is applied. Error text never reveals
the expected symbol.

The fourth correct symbol latches completion once, disables every prompt, shows
POWER RESTORED, and calls RoundService's server callback. RoundService latches the
objective and replaces its one timer task with a reset scheduled at the earlier
of CompletionDelay (3 seconds) or the original round deadline. Timeout cannot be
extended by completion. Interactions at/after the deadline are rejected even if
the timer callback is delayed. The timer generation token and RESETTING guard
prevent duplicate resets. No client completion event exists.

PuzzleService.Reset() disables prompts, disconnects all prompt/departure handlers,
cancels the error-feedback task, increments its generation to reject stale events,
and clears solution, entered sequence, completion, and rate-limit data. It blanks
clues and slots and restores WAITING FOR ROUND. RoundService invokes it on reset
and Stop. Start creates fresh handlers once. Character resets do not restart the
puzzle or clear progress; disconnects only remove that player's cooldown record.
Remaining active players can finish the same puzzle, with no player-owned fuse.

## Fuse Room acceptance tests (not yet executed in Studio)

### Solo development

1. Keep DevelopmentMode=true and DevelopmentRoundDuration=60. Run Rojo, sync,
   and Play. No manual parts, prompts, remotes, or scripts are required.
2. Wait through the normal 15-second countdown and 5-second reveal. Confirm movement
   into Room 1, four empty slots, RESTORE POWER - 0/4, four symbol controls, and four
   clues showing POSITION 1..4, with each symbol appearing once.
3. Walk around and note the clues. Approach a control within 12 studs; use its
   displayed native prompt (keyboard E by default, touch/controller prompt otherwise).
   Enter a symbol different from POSITION 1. Expect zero progress and visible
   INCORRECT - SEQUENCE RESET. Clues must not change.
4. Enter the first correct symbol. Expect slot 1 filled and 1/4. Wait at least
   0.35 seconds, then enter that same symbol again: expect all slots empty.
5. Enter all four clues in order. Expect each numbered slot to fill, POWER RESTORED,
   prompts disabled, and one server objective-completion message. About three
   seconds later expect RESETTING, lobby return, two-second reset, and WAITING.
6. Complete a second round without restarting Studio. Verify fresh empty slots,
   new clue generation, and exactly one set of room objects and handlers. A random
   sequence may repeat; progress and completion must always start fresh.
7. In another cycle enter only one correct symbol, reset your character, and verify
   hotel return while PLAYING, unchanged clues/progress, and continuing timer.
8. Leave a cycle unsolved: at 60 seconds verify normal timeout and cleanup. Submit
   a wrong input just before timeout to check that delayed error feedback cannot
   overwrite reset or next-round displays.
9. For the completion/timeout edge, solve the first three slots, wait until the
   server timer has about two seconds left, then submit the fourth. There must be
   one RESETTING transition, at the earlier deadline, never a second delayed reset.

### Four-player production mode

1. Stop, set DevelopmentMode=false, sync, and launch a local server with four
   clients. Keep RoundDuration=300. Confirm the existing private one-Saboteur/three-
   Guest assignment and separate active spawn positions.
2. Send players to different clues, communicate their positions, and take turns
   entering controls. Observe shared slot progress on every client.
3. Have two players activate the same first correct symbol nearly simultaneously.
   Expected: one accepted input, then duplicate-reset (or a rejected input if that
   same player hits the cooldown). Progress must never skip slots or complete twice.
4. Coordinate the correct sequence. Verify one POWER RESTORED and one reset cycle.
   Default development puzzle logs are off in this mode; RoundService's completion
   diagnostic remains visible. Individual clients still log only their own role.
5. In another cycle disconnect the player who entered a fuse. Progress remains,
   another active player can finish, and no fuse becomes locked to the departure.
6. Add a fifth client during PLAYING. It remains in the lobby with no role and
   cannot progress the puzzle. For a stronger roster-validation check, use only
   the Studio **server** Command Bar to move that late joiner near a control, then
   activate its normal prompt: progress must remain unchanged. Reset the late
   joiner's character afterward; it should return to the lobby.
7. Repeat the inherited countdown-cancellation, production 300-second timeout,
   active/late-join respawn, and Stop/Start tests above. Restore DevelopmentMode=true.

Server Command Bar inspection (no answer exposed):

```lua
local s = game.ServerScriptService.Server
local puzzle = require(s.PuzzleService)
print(puzzle.GetProgress(), puzzle.IsComplete())
```

After RoundService.Stop() or while RESETTING, expect 0 and false, blank clues/slots,
and disabled prompts. Restart twice; expect one handler per prompt, not doubled
progress. Repeat during incorrect feedback and the completion delay. Attempting
native prompts from outside activation range should do nothing; adversarial
forged-prompt validation and latency testing still need a Roblox test environment.

Expected additional server Output in DevelopmentMode=true:

```text
[Midnight Hotel][PuzzleService] Puzzle reset.
[Midnight Hotel][PuzzleService] Fuse Room puzzle started.
[Midnight Hotel][PuzzleService] Incorrect sequence; progress reset.
[Midnight Hotel][PuzzleService] Accepted TRIANGLE; progress 1/4.
...
[Midnight Hotel][PuzzleService] Fuse Room completed.
[Midnight Hotel][RoundService] Fuse Room objective complete. Scheduling temporary round end.
[Midnight Hotel][RoundService] State=RESETTING. Players=1/1.
```

The accepted symbol varies with each sequence. Full solutions are not logged.
Client Output remains the existing private-role diagnostic; puzzle feedback is
physical room text and native prompts. These are expected messages, not recorded
Studio test results. Rojo/static checks cannot verify readability, networking,
physics, or multiplayer acceptance; perform the tests above before accepting 2A.


### Fuse Room readability layout

All Fuse Room text now uses SurfaceGui on physical sign faces, with scale based
on stud dimensions rather than fixed screen-size billboards. The lobby's existing
area billboard remains unchanged. The hotel center billboard was removed in favor
of a south-wall room sign. No duplicate labels or coincident text anchors were
found; the former camera-facing labels overlapped in projection.

The north-wall panel is 100 studs wide. Its four 20x6 slot signs and four separate
10x6 controls align at X=-39,-13,13,39 relative to the room center. Slot labels sit
on the panel; controls are in front and below them. Control centers are 26 studs
apart, beyond two 12-stud prompt activation radii. Prompt UI is offset upward from
the symbol face. Status and objective signs occupy distinct bands above the panel.
Clues face inward from the west/east walls and two south-wall locations; their
16x10 sign faces are readable by walking toward them. The central spawn/walking
area remains open. Sign orientations and dimensions are centralized in Config.

After syncing this layout change, stop and restart Play: the existing session-owned
world is intentionally reused by service Start/Stop and is not rebuilt in place.
Check the panel from spawn and each control, walk to all four clues, and confirm
native prompt text remains legible. Visual acceptance still requires Studio.
Puzzle validation, timing, role/roster behavior, and reset logic are unchanged.
