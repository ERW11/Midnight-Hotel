# TRUST NO ONE: Midnight Hotel

Roblox Studio + Luau + Rojo, with server-authoritative round orchestration.

## Current status

**Milestone 1B implements WAITING → COUNTDOWN → ROLE_REVEAL only.**
The tested minimum-player selection and countdown cancellation remain in place.
At countdown completion, the server locks up to `Players.MaximumPlayers` players,
assigns exactly one Saboteur and all others Guest, and privately delivers each role.
ROLE_REVEAL lasts `Timing.RoleRevealDuration` (5 seconds). The server then clears
roles and roster, returns to WAITING, and waits `Timing.DevelopmentResetDelay`
(2 seconds) before reevaluating the lobby. This temporary loop runs in both modes.
There is no PLAYING or RESETTING state and no real gameplay yet.

## Files and ownership

- `src/server/init.server.luau`: starts RoundService and stops it on server shutdown.
- `src/server/RoundService.luau`: owns state, lobby membership, capped active roster,
  timer, connection cleanup, and private delivery. Located under `ServerScriptService.Server`.
- `src/server/RoleService.luau`: owns a private in-memory role table. A uniform
  `Random:NextInteger(1, #roster)` selects one roster index as Saboteur; all other
  indices are Guest. Rejects empty/duplicate rosters. No mutable table is exposed.
- `src/client/init.client.luau`: connects to the private event, announces readiness,
  validates Guest/Saboteur, and prints only its own role in Studio. No role is cached.
- `src/shared/Config.luau`: public tuning only, mapped to `ReplicatedStorage.Shared.Config`.
- `AGENTS.md`: project rules and current scope.

RoundService snapshots connected lobby members without yielding. Overflow selection
uses ascending UserId, capped at `Players.MaximumPlayers=6`; this is a simple stable
selection policy, not matchmaking or a fair queue. The active set can shrink on
 departure but is never backfilled. Late joiners and overflow players receive no role
for that cycle and may qualify for the next cycle. All connected players count toward
the lobby threshold; MaximumPlayers caps only the active roster, not place capacity.

DevelopmentMode true uses `Players.DevelopmentMinimumPlayers=1`; false uses
`Players.MinimumPlayers=4`. Countdown is `Timing.LobbyCountdown=15` seconds.
Configuration is loaded at startup; stop testing, edit, sync, and start a new session.
Countdowns use one-second task delays and can drift under server load.

RoundService's server-only dot-call API is `Start()`, `Stop()`, `GetState()`,
`GetCountdownRemaining()`, `GetRequiredPlayerCount()`, `IsActivePlayer(player)`,
and `GetActivePlayerCount()`. Getters expose scalars only. Start/Stop are idempotent.
Stop cancels the single timer, invalidates stale callbacks, disconnects all owned
connections, and clears membership, readiness, roster, and roles. Start re-handshakes
existing clients. The empty remote infrastructure persists and is reused safely.

RoleService exposes `AssignRoles(roster)`, `GetRole(player)`, `IsSaboteur(player)`,
`IsGuest(player)`, `HasRole(player)`, `ClearRole(player)`, and `ClearRoles()`.
RoundService orchestrates assignment and cleanup. Departures clear role data
immediately. A departing Saboteur is not replaced; reveal finishes and resets normally.
Exactly one Saboteur is guaranteed at assignment, not after that player departs.

## Private networking

The server creates/verifies `ReplicatedStorage.MidnightHotelRemotes.PrivateRole`
(a RemoteEvent), failing clearly on class conflicts. It contains no role data.
Server-to-client `("Role", ownRole)` uses `FireClient` for that player only.
`("Ready")` is a startup handshake in either direction. Clients connect first and
announce readiness. The server sends only a currently active player's own role,
once per assignment; repeated readiness messages do not cause duplicate delivery.
Clients becoming ready after reveal ends receive no stale role.

The sender is supplied by Roblox, never a client-selected target. A client cannot
choose a role, enter the roster, alter state, or request another player's role.
There are no replicated role Attributes, Values, assignment folders, shared role
tables, or role broadcasts. Guest clients receive no other player's assignment.
Role knowledge can still be inferred in tiny rosters (a two-player Guest knows the
other player is Saboteur); secrecy cannot prevent such logical inference.
Server departure diagnostics omit player identity. Studio's combined Output may
aggregate multiple clients' private logs: inspect individual client contexts when
checking privacy. Role diagnostics are Studio-only, even when DevelopmentMode=false.

## Rojo development

From the repository root, run:

```sh
rojo serve default.project.json
```

Connect the Studio Rojo plugin to the local server (default port 34872), review and
apply sync changes. Verify `ServerScriptService.Server` contains RoundService and
RoleService. Both are server-only. During Play, the server creates the remote folder.
Alternatively build and open:

```sh
rojo build default.project.json -o Midnight-Hotel.rbxlx
```

The generated place is Git-ignored. Rojo mappings and starter baseplate/lighting
are unchanged. No external packages, new geometry, or UI have been added.

## Studio test checklist

Open Output, selecting the server or individual client context as appropriate.
Always stop the session before changing Config. Restore defaults after tests.

1. **Solo:** with DevelopmentMode=true, start Play. Expect WAITING, COUNTDOWN,
   a start at 15 seconds, and ticks 14 through 0. Expect a roster of 1 and ROLE_REVEAL.
   The only client must log Saboteur. After 5 seconds expect the development-boundary
   diagnostic and WAITING; after 2 seconds another countdown begins. Test two cycles.
2. **Four players:** set DevelopmentMode=false, sync, and start a local server with
   four clients. Expect roster size 4. Inspect each client's Output: exactly one
   Saboteur message and three Guest messages per cycle, each on its own client.
   No full roster or another player's role should be received. All clients still
   print their private Studio diagnostics with DevelopmentMode=false.
3. **1A cancellation regression:** start with three clients in normal mode: WAITING.
   Add a fourth: COUNTDOWN. Close one before zero: immediate cancellation and WAITING,
   no stale ticks. Add a replacement: a fresh countdown at 15. With five clients,
   dropping to four should not cancel or restart it.
4. **Late join:** temporarily set RoleRevealDuration=30 to give time. Start four
   clients in normal mode; wait for ROLE_REVEAL, then add a fifth. Expect the late-join
   diagnostic. The fifth receives no role for this cycle, active count stays 4,
   and it can join the next cycle after reset. Use the server query below to verify.
5. **Departure:** during the extended reveal, close a Guest client. Active count
   shrinks and the departing player's role is cleared. Repeat in another cycle,
   closing the client whose own Output says Saboteur. Expect the server's Saboteur
   departure diagnostic, no reassignment, no crash, and normal completion/reset.
   Dropping below minimum during reveal does not cancel reveal; the next WAITING
   phase remains there if there are too few players.
6. **Capacity:** if practical, start seven clients with MaximumPlayers=6. Active
   count must be 6, with one Saboteur and five Guests. The excluded client receives
   no role this cycle. Do not expect fair rotation; overflow policy is UserId order.
7. **Cleanup:** during reveal, use the server Command Bar lifecycle check below.
   Stop twice, verify WAITING/0 active and no roles, wait longer than the old reveal
   duration, and confirm no stale completion. Start twice: one countdown stream and
   private delivery still work. Repeat during countdown and the retry pause.
8. Restore DevelopmentMode=true and RoleRevealDuration=5. Confirm no errors or
   infinite-yield warnings. End and restart Play to verify fresh startup.

Read-only **server** Command Bar inspection (does not print secret assignments):

```lua
local server = game.ServerScriptService.Server
local rounds = require(server.RoundService)
local roles = require(server.RoleService)
print(rounds.GetState(), rounds.GetActivePlayerCount())
for _, player in game.Players:GetPlayers() do
    print(player.Name, rounds.IsActivePlayer(player), roles.HasRole(player))
end
```

Lifecycle check, also in the **server** Command Bar:

```lua
local server = game.ServerScriptService.Server
local rounds = require(server.RoundService)
local roles = require(server.RoleService)
rounds.Stop()
rounds.Stop()
assert(rounds.GetState() == "WAITING" and rounds.GetActivePlayerCount() == 0)
for _, player in game.Players:GetPlayers() do
    assert(not roles.HasRole(player))
end
```

After waiting to check that the old timer stays cancelled, restart:

```lua
local rounds = require(game.ServerScriptService.Server.RoundService)
rounds.Start()
rounds.Start()
```

Expected server messages include (each prefixed `[Midnight Hotel][RoundService]`):

```text
State=WAITING. Players=0/1.
State=COUNTDOWN. Players=1/1.
Countdown started: 15 seconds.
Countdown: 14.
...
Countdown: 0.
Countdown complete.
Active roster locked: 1 players.
State=ROLE_REVEAL. Players=1/1.
ROLE_REVEAL complete. Development boundary; clearing temporary round.
State=WAITING. Players=1/1.
```

Additional messages: `Late joiner remains outside the active roster.`,
`Active player departed during ROLE_REVEAL.`, or
`Saboteur departed during ROLE_REVEAL; temporary cycle will reset normally.`
Initial player counts/order depend on when players connect. Each Studio client
logs only `[Midnight Hotel][Client] Private role received: Guest` or `Saboteur`.
Historical Output logs remain after reset, but no client role state is retained.

## Remaining work and validation limits

No PLAYING, teleportation, hotel building, puzzles, sabotage, voting, escape,
results, rewards, progression, final UI, or full gameplay reset. There is no
cooperative fallback or backfill on departure. RoundDuration and ResultsDuration
remain unused. The temporary reveal boundary is not a real round ending.
Rojo builds validate packaging, not runtime behavior. Studio checks above are
required; do not treat build success as executed multiplayer tests.
