# TRUST NO ONE: Midnight Hotel

A Roblox game built with Roblox Studio, Luau, and Rojo.

## Current status

**Milestone 1A: server-side WAITING/COUNTDOWN is implemented.** RoundService
observes joins and departures, starts a countdown when enough players are present,
and immediately cancels it when the player count drops below the minimum.
Only WAITING and COUNTDOWN exist. No real round gameplay is implemented.

After completion, the service returns to WAITING and pauses for
`Timing.DevelopmentResetDelay` (2 seconds) before checking the population again.
This temporary development testing loop applies in both configuration modes;
`DevelopmentMode` selects the player threshold. It is not a RESETTING state and
must be replaced when the next round phase is implemented.

## Milestone 1 goal

Eventual flow (only the first two states currently exist):

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESULTS → RESETTING → WAITING`

Private roles, active-round rosters, teleportation, hotel geometry, gameplay timer,
exit detection, results, full round reset, and late-join handling remain unimplemented.
There are no RemoteEvents, UI, rewards, puzzles, sabotage, or voting.

## Source layout and configuration

- `src/server/init.server.luau`: starts RoundService and stops it on server shutdown;
  maps to `ServerScriptService.Server`.
- `src/server/RoundService.luau`: server-only module under that Server script.
  Owns transitions, membership tracking, one cancellable timer, and connections.
- `src/client/init.client.luau`: unchanged config-loading diagnostic bootstrap in
  `StarterPlayer.StarterPlayerScripts.Client`; it cannot control the service.
- `src/shared/Config.luau`: public tuning in `ReplicatedStorage.Shared.Config`.
- `AGENTS.md`: project rules for future agents.

Config uses `Players` for limits and `Timing` for durations in seconds.
With `DevelopmentMode=true`, the required count is `DevelopmentMinimumPlayers=1`;
otherwise it is `MinimumPlayers=4`. `LobbyCountdown=15`. Edit configuration before
starting a new Play session; live configuration changes are not supported.
`MaximumPlayers=6` is reserved and does not cap this lobby or set place capacity.
Role-reveal, round, and results durations are reserved for future work.
Shared configuration contains no secret information. Frozen tables guard against
accidental writes, not client tampering.

RoundService exposes dot-call methods `Start()`, `Stop()`, `GetState()`,
`GetCountdownRemaining()`, and `GetRequiredPlayerCount()`. Start/Stop are idempotent;
Stop disconnects player events, cancels the timer, and clears membership and state.
Start can then rebuild membership. Getters return scalars, with countdown remaining
zero while WAITING. No public state setter exists. A generation check also rejects
stale timer callbacks. Countdown duration must be a positive whole number and the
retry delay must be finite and positive. Ticks use one-second task delays, so a
busy server can extend the wall-clock countdown; precision timing is future work.

## Rojo development

Use the Rojo CLI (starter generated with 7.7.1) and Roblox Studio's Rojo plugin.
From the repository root:

```sh
rojo serve default.project.json
```

Connect Studio's Rojo plugin to the local server (default port 34872), review the
sync changes, and apply them. In Explorer, verify `ServerScriptService.Server`
contains `RoundService` and `ReplicatedStorage.Shared` contains `Config`.
Alternatively, build and open a local place file:

```sh
rojo build default.project.json -o Midnight-Hotel.rbxlx
```

The generated place is Git-ignored. Existing starter baseplate, lighting, and sound
settings remain unchanged. No external packages are added.

## Studio validation

Open Output and inspect the **server** messages. Always stop the test before
editing Config, then sync and start a fresh session.

1. **Solo default:** leave DevelopmentMode true and start Play. Expect the bootstrap
   diagnostics, an initial WAITING message, player count 1/1, COUNTDOWN, and
   `Countdown started: 15 seconds.` Expect one tick per second from 14 through 0,
   `Countdown complete.`, then WAITING. After 2 seconds a fresh 15-second countdown
   starts if the player remains. Observe at least two cycles without duplicate ticks.
2. **Normal threshold:** set DevelopmentMode false. Start a local server with 3
   clients using Studio's multiplayer testing controls. Expect WAITING at 3/4 with
   no ticks. Add a fourth client: expect COUNTDOWN at 4/4.
3. **Immediate cancellation:** close one client during the countdown, leaving 3.
   Expect `Countdown cancelled: insufficient players.` and WAITING immediately,
   with no remaining ticks from that countdown. Add another client: countdown
   starts fresh at 15, not at the old remaining value.
4. **Above threshold:** with 5 clients, close one. The countdown should continue
   at 4/4 without restarting. Close another to trigger cancellation. Repeat joins
   and departures, including near the last tick; there should be one timer stream.
5. **Retry pause:** after completion, remove enough clients during the 2-second
   pause. It must stay WAITING after the pause until the minimum is met again.
6. **Lifecycle:** in the running server's Command Bar, use the commands below.
   Stop twice; ticks should cease and getters should return WAITING and 0. Join or
   remove a client while stopped: there should be no service messages. Start twice;
   membership is rebuilt and only one countdown should run.
7. Restore DevelopmentMode true after testing. Confirm Output has no script errors
   or infinite-yield warnings. A fresh Play session should behave like the first.

Server Command Bar lifecycle check:

```lua
local service = require(game.ServerScriptService.Server.RoundService)
service.Stop()
service.Stop()
print(service.GetState(), service.GetCountdownRemaining(), service.GetRequiredPlayerCount())
```

Restart check:

```lua
local service = require(game.ServerScriptService.Server.RoundService)
service.Start()
service.Start()
```

Service diagnostics use the prefix `[Midnight Hotel][RoundService]`, for example:

```text
[Midnight Hotel][RoundService] State=WAITING. Players=0/1.
[Midnight Hotel][RoundService] Players=1/1. State=WAITING.
[Midnight Hotel][RoundService] State=COUNTDOWN. Players=1/1.
[Midnight Hotel][RoundService] Countdown started: 15 seconds.
[Midnight Hotel][RoundService] Countdown: 14.
...
[Midnight Hotel][RoundService] Countdown: 0.
[Midnight Hotel][RoundService] Countdown complete.
[Midnight Hotel][RoundService] State=WAITING. Players=1/1.
```

Initial population/log ordering depends on whether players are already connected
when the service starts. Diagnostics are intentionally enabled for Output testing
in both modes. Rojo build validates packaging; runtime behavior must be tested in Studio.
