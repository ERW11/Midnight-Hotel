# TRUST NO ONE: Midnight Hotel

Roblox Studio + Luau + Rojo. **Milestone 2B: personal tasks and Fuse Hunt.**

## Design and current scope

Every Guest will eventually have exactly **one Long Task + one Short Task**.
Currently every active Guest gets **Restore Hotel Power / Fuse Hunt** as the Long
Task. Short Task is unassigned and incomplete; Circuit Router is planned for 2C,
not implemented. Split Decisions is no longer on the roadmap. Saboteurs have no
real task requirements or genuine task records. No fake-task system exists yet.

Flow remains:

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESETTING → WAITING`

**Completing Fuse Hunt only completes that Guest's Long Task.** It does not reset
or end the round, return players to the lobby, complete another Guest's task, or
complete the pending Short Task. Even all Guests finishing does not end 2B rounds.
The server timer remains the only normal PLAYING end condition. No RESULTS exists.

## Files and responsibilities

- `src/server/RoundService.luau`: population, locked roster, states, timers, private
  role delivery, task lifecycle orchestration, and lobby/hotel routing.
- `src/server/RoleService.luau`: secret role assignments and server-only queries.
- `src/server/TaskService.luau`: per-player assignment/completion records, copied
  status snapshots, private task delivery, Guest/roster/deadline eligibility.
- `src/server/PuzzleService.luau`: randomized Fuse Hunt sequence/placements, per-player
  attempts, server prompt validation, per-player rate limits and feedback timers.
- `src/server/WorldService.luau`: session-owned deterministic greybox, physical signs,
  clue positioning, bounded character movement, and respawn routing.
- `src/server/HotelLayout.luau`: server-defined prototype areas and eight candidate
  clue locations. No secret role or task state is stored in world objects.
- `src/client/TaskDisplay.luau`: validates the local player's status and updates only
  their local copies of the existing panel's slots/status. No final HUD.
- `src/client/init.client.luau`: private-role diagnostic and TaskDisplay startup.
- `src/shared/Config.luau`: public tuning only; no answers or personal state.
- `src/server/init.server.luau`: starts/stops RoundService as before.

Services remain under ServerScriptService.Server. Client modules are under the
Client LocalScript. Rojo mappings, source separation, and starter baseplate remain.
No dependencies have been added.

## Assignment, privacy, and validation

RoundService snapshots at most six players at countdown completion, sorted by
UserId. Late joiners never enter the locked roster. RoleService assigns one random
Saboteur in multiplayer and Guests otherwise. When PLAYING begins, TaskService
assigns one FuseHunt record to each active Guest. Each record has longTask,
shortTask, longComplete, shortComplete, entered symbols, and feedback. Short Task
stays nil/false. Saboteurs and late joiners have no assignment. GetStatus(player)
returns a fresh copy; there is no public mutable task table.

PrivateTasks is a server-created RemoteEvent under MidnightHotelRemotes. Its only
accepted client message is Ready, rate limited to 0.5 seconds. The server replies
only to that sender with their status; no client-supplied target/task/role is used.
No OnServerEvent branch accepts progress or completion. Ready also handles slow
startup and existing clients after Stop/Start. Reset clears local status privately.
Shared panel text remains generic; a Guest's progress/completion is applied only
in that client's local replica, never broadcast. PrivateRole behavior is preserved.

Each native prompt uses a server-bound symbol. Before accepting it, the server
checks PLAYING and unexpired deadline, connected active roster membership, actual
Guest role, genuine incomplete FuseHunt ownership, a living character/root in
Workspace, valid symbol, root-to-control distance <=12 studs, and a 0.35-second
per-player cooldown. Mutation does not yield and has a reentry guard. Simultaneous
inputs affect separate attempts. Inputs after completion are ignored for that
player while other Guests can continue using the same controls.

A wrong or already-used symbol clears only that player's current attempt and
privately shows INCORRECT - YOUR SEQUENCE RESET for up to two seconds. The player
can retry immediately subject to the cooldown. Clues stay unchanged. Four correct
inputs call TaskService.CompleteLongTask on the server once; no RoundService
completion callback exists. The round continues with its original deadline.
Client-side text edits or fabricated network completion messages cannot affect
server progress. Continuous movement cheating and reading public clue replicas
are outside this authority boundary; visible clue text is intentionally public.
Observing another player's movement is also not hidden by private task delivery.

## Hotel and randomized clues

WorldService reuses one Workspace.MidnightHotelGreybox folder. Lobby is unchanged.
The hotel shell is expanded to 120x210 studs, with the existing Fuse panel toward
the north and clear walking routes through six labeled prototype areas to the south:
Bedroom, Bathroom, Reception, Hallway, Maintenance, Storage. They are floor zones
and physical signs, not polished rooms or additional puzzles. No blocking maze or
locked door exists. SurfaceGui signs face approach routes; no new billboards.

```text
Hotel/
├── FuseRoom/                 # Original spaced controls, personal panel slots/status
├── PrototypeAreas/
│   ├── Bedroom/
│   ├── Bathroom/
│   ├── Reception/
│   ├── Hallway/
│   ├── Maintenance/
│   └── Storage/
└── FuseHuntClues/
    └── Clue1..Clue4           # Four reusable signs, moved each round
```

At each PLAYING start, Fisher-Yates shuffles the four distinct symbols. Independently,
the eight candidate location indices are shuffled; the first four receive CLUE 1,
2, 3, 4 in that order. Thus location selection is without replacement and clue
number-to-location assignment is randomized. Clues are outside the panel area:
west/east wall locations near Bedroom/Bathroom/Reception/Hallway and south-wall
locations near Maintenance/Storage. Authoritative sequence/selection stay server-side;
physical clue signs reveal CLUE N and that position's symbol. All Guests share the
round's clues/answer but not attempts/completion. Random draws may legitimately repeat.
Unused locations contain no clue sign. Reset hides all four signs and clears text.

Player departures remove only their task/attempt/cooldown/feedback data. Nothing
is owned or consumed physically. Character reset preserves tasks/attempts and
routes active PLAYING players back to the hotel. Late joiners respawn in the lobby.
Round reset disconnects puzzle handlers, cancels feedback tasks, clears attempts,
solution and task records, hides clues, returns players to lobby, and clears roles.
Stop also disconnects private-task handlers; Start re-handshakes existing clients.
Geometry is session-owned and reused; stop and restart Play after syncing layout edits.

## Development settings

- DevelopmentMode=true: minimum 1 and PLAYING 60 seconds.
- DevelopmentMode=false: minimum 4 and PLAYING **300 seconds**, unchanged.
- MaximumPlayers=6; countdown=15; reveal=5; reset pause=2; ResultsDuration=10 unused.
- **Tasks.DevelopmentSoloGuest=true**: a one-player roster becomes Guest only when
  running inside Studio with DevelopmentMode=true. This explicit test exception
  enables real Guest task testing; it never gives a Saboteur genuine task progress.
  Multiplayer still assigns exactly one Saboteur. Published servers cannot use it.
  Set it false to test the ordinary solo Saboteur denial path.
- Interaction distance/cooldown/error duration remain 12/0.35/2. CompletionDelay was
  removed because personal completion no longer schedules a round reset.

Do not change configuration during Play. Stop, edit, sync, then start a fresh test.
The larger hunt can be tight in 60 seconds for a first-time tester; temporarily
increase DevelopmentRoundDuration locally for exploration if needed and restore 60.
Production duration remains 300. Task assignment, clue locations, and per-player
input/completion logs require BOTH Studio and DevelopmentMode, preventing hidden
information diagnostics in published servers. Full answers are not logged.

## Run and test in Studio

```sh
rojo serve default.project.json
```

Connect Studio's Rojo plugin (default localhost port 34872), review and sync.
Alternatively `rojo build default.project.json -o Midnight-Hotel.rbxlx`, then open
the Git-ignored place. No manual geometry, scripts, or remotes are required.

### Solo Guest test

1. Keep DevelopmentMode=true and Tasks.DevelopmentSoloGuest=true. Restart Play.
2. Observe normal lobby/countdown/reveal. Expect the explicit Studio solo Guest
   override diagnostic and your private Guest role. At PLAYING expect Fuse Hunt
   assigned and Short Task pending in your client Output/local panel.
3. Walk into the labeled hotel areas, locate all four CLUE signs, and note their
   position numbers/symbols. Check the server development placement logs if needed.
   No two signs should occupy the same candidate location, and none is at the panel.
4. Return to the controls. Enter a wrong symbol: only your sequence resets to 0/4.
   Enter the correct first symbol, wait >=0.35 seconds, repeat it: your attempt resets.
5. Enter the four correct symbols. Expect POWER RESTORED - YOUR LONG TASK COMPLETE,
   and SHORT TASK: PENDING. Wait longer than the former three-second completion
   delay: you must remain in PLAYING, in the hotel, with the original timer running.
6. Further input cannot complete again. Reset your character: hotel return and task
   completion persist. At the original timeout return to lobby and clear all tasks.
7. Observe the next cycle: new clue draw, empty attempt, incomplete Long Task, and
   pending Short Task. Same random answer/placement can repeat legitimately.
8. In a separate test, set Tasks.DevelopmentSoloGuest=false. Expect Saboteur, no
   genuine task assignment, and no progress from any control. Restore true afterward.

### Four-player ownership/security test

1. Stop, set DevelopmentMode=false, sync, and start a local server with four clients.
   Keep RoundDuration=300. Expect one Saboteur and three Guests, all privately informed.
2. Guests each receive FuseHunt with pending Short Task. Saboteur receives no real
   tasks. Inspect each client's local panel separately (Studio combined Output can
   aggregate logs from different clients).
3. Guest A enters one correct symbol: A sees 1/4, B/C still see 0/4. Guest B enters
   a wrong symbol: only B resets. A's partial attempt must remain.
4. A completes: only A's Long Task is complete. B/C can solve independently at the
   same controls. Even all three completing must not end or reset the round.
5. Attempt simultaneous inputs from A/B during incomplete attempts. Their attempts
   must not merge or erase one another. Same-player duplicate input still resets
   that player's attempt when outside the cooldown.
6. Saboteur tries all controls: no genuine assignment/progress. Add a fifth client
   mid-round: lobby, no role/task. Even if moved beside the controls using the Studio
   server Command Bar for testing, the late joiner must fail roster validation.
7. Reset an active Guest's character during partial progress: same attempt and clues,
   hotel respawn. Disconnect a Guest: others' state remains unchanged and solvable.
8. Let the 300-second deadline expire. Verify lobby return, private task clearing,
   and a clean next cycle. Restore DevelopmentMode=true afterward.

### Lifecycle checks

During PLAYING, run in **server** Command Bar:

```lua
local s = game.ServerScriptService.Server
local rounds, tasks = require(s.RoundService), require(s.TaskService)
rounds.Stop()
rounds.Stop()
assert(rounds.GetState() == "WAITING" and rounds.GetActivePlayerCount() == 0)
for _, player in game.Players:GetPlayers() do
    local status = tasks.GetStatus(player)
    assert(status.longTask == nil and status.shortTask == nil)
    assert(not status.longComplete and not status.shortComplete)
end
```

Wait beyond any old feedback deadline; no stale text/task must return. Start twice:

```lua
local rounds = require(game.ServerScriptService.Server.RoundService)
rounds.Start()
rounds.Start()
```

Expect one countdown stream, no duplicate geometry/prompts, functioning private
role/task delivery, and fresh assignments. Repeat during incorrect feedback and
after Long Task completion. Also repeat original countdown cancellation (4 to 3
players in normal mode) and lobby/hotel positioning tests.

Expected development diagnostics include:

```text
[Midnight Hotel][RoleService] Studio solo Guest override active.
[Midnight Hotel][TaskService] Assigned Fuse Hunt Long Task to Player1; Short Task pending.
[Midnight Hotel][PuzzleService] Clue 1 placed at Bedroom_West.
[Midnight Hotel][PuzzleService] Fuse Hunt started; attempts and completion are personal.
[Midnight Hotel][PuzzleService] Player1 accepted TRIANGLE; personal progress 1/4.
[Midnight Hotel][PuzzleService] Player1 incorrect input; personal attempt reset.
[Midnight Hotel][TaskService] Player1 completed FuseHunt. Round continues; Short Task pending.
```

Names, locations, and symbols vary. Client Output reports only its own role/task
status in Studio. With DevelopmentMode=false, detailed server task logs are off;
inspect private client feedback and server-only GetStatus for verification.

## Limitations and intentionally unimplemented systems

No Circuit Router/Short Task, Split Decisions, other puzzle rooms, sabotage, killing,
voting, fake tasks, task-based round victory, final escape, RESULTS, rewards,
progression, persistence, matchmaking, spectator mode, monetization, polished art,
or final HUD. No fairness queue/backfill or Saboteur replacement. The shared answer
means Guests may communicate clues; the task does not prove they personally visited
every clue. Candidate locations and physical clues can be inspected by clients;
server authority prevents false completion claims, not knowledge of visible clues.
Custom rigs without live HumanoidRootPart can time out on positioning. More than six
lobby players reuse markers. Client display assumes the current non-streaming place;
streaming/recreated world recovery is not implemented.

Rojo builds and static checks verify packaging, not runtime multiplayer behavior,
visual readability, or physics. The Studio procedures above remain manual acceptance
checks; do not interpret build success as proof that those tests were executed.
