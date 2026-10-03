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
		-- Bounded pause in RESETTING; no results or win conditions yet.
		DevelopmentResetDelay = 2,
		RoleRevealDuration = 5,
		RoundDuration = 300,
		DevelopmentRoundDuration = 20,
		RoundDiagnosticInterval = 5,
		CharacterPositionTimeout = 10,
		CharacterPositionPollInterval = 0.1,
		ResultsDuration = 10,
	}),
	World = table.freeze({
		FolderName = "MidnightHotelGreybox",
		LobbyCenter = Vector3.new(0, 20, 0),
		HotelCenter = Vector3.new(0, 20, 600),
		FloorSize = Vector3.new(80, 2, 60),
		WallHeight = 20,
		WallThickness = 2,
		SpawnSpacing = 8,
		SpawnColumns = 3,
		SpawnLift = 5,
		MarkerSize = Vector3.new(5, 0.2, 5),
		LabelOffset = Vector3.new(0, 14, 0),
		LabelSize = Vector2.new(420, 60),
		LabelMaxDistance = 150,
	}),
	DevelopmentMode = true,
}

return table.freeze(Config)
