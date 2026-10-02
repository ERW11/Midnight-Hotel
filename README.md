# TRUST NO ONE: Midnight Hotel

A Roblox game built with Roblox Studio, Luau, and Rojo.

## Current status

Milestone 1 engineering foundation only. **Gameplay is NOT implemented yet.**
The server and client bootstraps load shared configuration and print diagnostics.
No rounds, roles, map geometry, or UI have been implemented.

## Milestone 1 goal

Eventual flow:

`WAITING → COUNTDOWN → ROLE_REVEAL → PLAYING → RESULTS → RESETTING → WAITING`

Future work includes lobby waiting, configurable minimum players, countdown,
private Guest/Saboteur assignment, active-roster teleportation to a greybox hotel,
a round timer, simple exit detection, results, full reset, late joiners outside
active rounds, and a development/solo testing override. None is implemented yet.

## Source layout and configuration

- `src/server/init.server.luau`: bootstrap in `ServerScriptService.Server`.
- `src/client/init.client.luau`: bootstrap in `StarterPlayer.StarterPlayerScripts.Client`.
- `src/shared/Config.luau`: public settings in `ReplicatedStorage.Shared.Config`.
- `AGENTS.md`: engineering rules for future agents.

Config groups player limits under `Players`, durations in seconds under `Timing`,
and exposes `DevelopmentMode`. These settings do not enable gameplay yet.
`MaximumPlayers` does not set Roblox's place capacity. Shared code is public;
secret role data and authoritative round state must stay server-only. Frozen
config tables prevent accidental writes, not client tampering.

## Rojo development

Use the Rojo CLI (starter generated with 7.7.1) and the Roblox Studio Rojo plugin.
From the repository root:

1. Run `rojo serve default.project.json`.
2. Open the development place in Studio. Connect the Rojo plugin to the local
   server (default port `34872`), review the sync changes, and apply them.
3. Verify the source mappings above in Explorer. `Shared.Hello` should be gone
   and `Shared.Config` should exist.
4. Start a Play test and inspect Output for both messages:
   - `[Midnight Hotel][Server] Bootstrap ready. DevelopmentMode=true`
   - `[Midnight Hotel][Client] Bootstrap ready. DevelopmentMode=true`
5. Confirm there are no script errors or infinite-yield warnings, then stop the test.

Alternatively, build a local place file and open it in Studio:

```sh
rojo build default.project.json -o Midnight-Hotel.rbxlx
```

Perform the same Play test. The generated place file is ignored by Git.
Existing starter baseplate, lighting, and sound settings remain unchanged.
No external packages have been added.
