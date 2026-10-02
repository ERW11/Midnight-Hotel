--!strict

-- Public tuning only; this module replicates to every client.
-- Keep secret roles and authoritative round state server-only. Durations are seconds.
local Config = {
	Players = table.freeze({
		MinimumPlayers = 4,
		MaximumPlayers = 6,
		DevelopmentMinimumPlayers = 1,
	}),
	Timing = table.freeze({
		LobbyCountdown = 15,
		RoleRevealDuration = 5,
		RoundDuration = 300,
		ResultsDuration = 10,
	}),
	DevelopmentMode = true,
}

return table.freeze(Config)
