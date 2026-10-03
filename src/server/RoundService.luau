--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

type State = "WAITING" | "COUNTDOWN"

local RoundService = {}
local state: State = "WAITING"
local remaining = 0
local running = false
local retryPending = false
local timer: thread? = nil
local generation = 0
local connections: { RBXScriptConnection } = {}
local present: { [Player]: boolean } = {}
local playerCount = 0
local required = if Config.DevelopmentMode
	then Config.Players.DevelopmentMinimumPlayers
	else Config.Players.MinimumPlayers

local function log(message: string)
	print("[Midnight Hotel][RoundService] " .. message)
end

local function setState(nextState: State)
	state = nextState
	log(string.format("State=%s. Players=%d/%d.", state, playerCount, required))
end

local function cancelTimer()
	generation += 1
	if timer then
		task.cancel(timer)
		timer = nil
	end
end

local function schedule(delaySeconds: number, callback: () -> ())
	cancelTimer()
	local scheduledGeneration = generation
	timer = task.delay(delaySeconds, function()
		if not running or generation ~= scheduledGeneration then
			return
		end
		timer = nil
		callback()
	end)
end

local evaluate: () -> ()

local function tick()
	remaining -= 1
	log(string.format("Countdown: %d.", remaining))
	if remaining > 0 then
		schedule(1, tick)
		return
	end

	log("Countdown complete.")
	-- Temporary Milestone 1A test loop, not a real round or RESETTING state.
	-- Applies in both modes so production player thresholds can also be tested.
	retryPending = true
	setState("WAITING")
	schedule(Config.Timing.DevelopmentResetDelay, function()
		retryPending = false
		evaluate()
	end)
end

evaluate = function()
	if not running then
		return
	end

	if playerCount < required then
		if state == "COUNTDOWN" then
			cancelTimer()
			remaining = 0
			log("Countdown cancelled: insufficient players.")
			setState("WAITING")
		end
		return
	end

	if state == "WAITING" and not retryPending then
		remaining = Config.Timing.LobbyCountdown
		setState("COUNTDOWN")
		log(string.format("Countdown started: %d seconds.", remaining))
		schedule(1, tick)
	end
end

function RoundService.GetState(): State
	return state
end

-- Zero while WAITING, including the temporary retry pause.
function RoundService.GetCountdownRemaining(): number
	return remaining
end

function RoundService.GetRequiredPlayerCount(): number
	return required
end

function RoundService.Start()
	if running then
		return
	end

	assert(required >= 1 and required % 1 == 0, "Required player count must be a positive integer")
	assert(Config.Timing.LobbyCountdown >= 1 and Config.Timing.LobbyCountdown % 1 == 0,
		"LobbyCountdown must be a positive integer")
	assert(Config.Timing.DevelopmentResetDelay > 0 and Config.Timing.DevelopmentResetDelay < math.huge,
		"DevelopmentResetDelay must be finite and positive")

	running = true
	remaining = 0
	retryPending = false

	local function joined(player: Player)
		if present[player] then
			return
		end
		present[player] = true
		playerCount += 1
		log(string.format("Players=%d/%d. State=%s.", playerCount, required, state))
		evaluate()
	end

	local function leaving(player: Player)
		if not present[player] then
			return
		end
		-- PlayerRemoving can fire before GetPlayers() excludes this player.
		present[player] = nil
		playerCount -= 1
		log(string.format("Players=%d/%d. State=%s.", playerCount, required, state))
		evaluate()
	end

	table.insert(connections, Players.PlayerAdded:Connect(joined))
	table.insert(connections, Players.PlayerRemoving:Connect(leaving))
	-- Connect before taking the snapshot; membership checks prevent double counting.
	for _, player in Players:GetPlayers() do
		present[player] = true
		playerCount += 1
	end
	setState("WAITING")
	evaluate()
end

function RoundService.Stop()
	if not running then
		return
	end
	running = false
	cancelTimer()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(present)
	playerCount = 0
	remaining = 0
	retryPending = false
	setState("WAITING")
	log("Stopped.")
end

-- Only lifecycle methods and scalar getters are exposed, never mutable state.
return table.freeze(RoundService)
