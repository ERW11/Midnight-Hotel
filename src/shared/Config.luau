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
		-- Time to read four distributed clues and test incorrect-input recovery solo.
		DevelopmentRoundDuration = 60,
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
	FuseRoom = table.freeze({
		Symbols = table.freeze({ "CIRCLE", "TRIANGLE", "DIAMOND", "CROSS" }),
		InteractionDistance = 12,
		InteractionCooldown = 0.35,
		IncorrectFeedbackDuration = 2,
		CompletionDelay = 3,
		FloorSize = Vector3.new(120, 2, 90),
		WallHeight = 30,
		PanelOffset = Vector3.new(0, 8, -41),
		PanelSize = Vector3.new(100, 10, 2),
		SlotSpacing = 26,
		SlotSize = Vector3.new(20, 6, 1),
		ControlSpacing = 26,
		ControlOffset = Vector3.new(0, 4, -30),
		ControlSize = Vector3.new(10, 6, 3),
		StatusOffset = Vector3.new(0, 17, -40),
		StatusSize = Vector3.new(76, 5, 1),
		ObjectiveOffset = Vector3.new(0, 25, -40),
		ObjectiveSize = Vector3.new(84, 7, 1),
		RoomSignOffset = Vector3.new(0, 21, 43),
		RoomSignSize = Vector3.new(44, 5, 1),
		PromptOffset = Vector2.new(0, -65),
		ClueOffsets = table.freeze({
			Vector3.new(-58, 7, 0), Vector3.new(58, 7, 0),
			Vector3.new(-30, 7, 43), Vector3.new(30, 7, 43),
		}),
		-- Back faces (+Z locally) are rotated toward the room interior.
		ClueYawDegrees = table.freeze({ 90, -90, 180, 180 }),
		ClueSize = Vector3.new(16, 10, 1),
		PixelsPerStud = 40,
		TextPadding = 0.06,
	}),
	DevelopmentMode = true,
}

return table.freeze(Config)
