--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RoleService = require(script.Parent:WaitForChild("RoleService"))

type State = "WAITING" | "COUNTDOWN" | "ROLE_REVEAL"

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
local active: { [Player]: boolean } = {}
local ready: { [Player]: boolean } = {}
local delivered: { [Player]: boolean } = {}
local roleRemote: RemoteEvent? = nil
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

local function ensureRemote(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("MidnightHotelRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MidnightHotelRemotes"
		folder.Parent = ReplicatedStorage
	end
	assert(folder:IsA("Folder"), "MidnightHotelRemotes must be a Folder")
	local remote = folder:FindFirstChild("PrivateRole")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "PrivateRole"
		remote.Parent = folder
	end
	assert(remote:IsA("RemoteEvent"), "PrivateRole must be a RemoteEvent")
	return remote
end

local function deliverRole(player: Player)
	local remote = roleRemote
	if not remote or state ~= "ROLE_REVEAL" or not active[player]
		or not ready[player] or delivered[player] then
		return
	end
	local role = RoleService.GetRole(player)
	if role then
		delivered[player] = true
		remote:FireClient(player, "Role", role)
	end
end

local function clearRound()
	table.clear(active)
	table.clear(delivered)
	RoleService.ClearRoles()
end

local function resetForTesting()
	clearRound()
	retryPending = true
	setState("WAITING")
	schedule(Config.Timing.DevelopmentResetDelay, function()
		retryPending = false
		evaluate()
	end)
end

local function beginRoleReveal()
	-- Snapshot without yielding. PlayerAdded never modifies this roster.
	local candidates: { Player } = {}
	for player in present do
		if player.Parent == Players then
			table.insert(candidates, player)
		end
	end
	-- Stable selection policy for overflow; no matchmaking or queue yet.
	table.sort(candidates, function(a, b)
		return a.UserId < b.UserId
	end)
	local roster: { Player } = {}
	for index = 1, math.min(#candidates, Config.Players.MaximumPlayers) do
		table.insert(roster, candidates[index])
	end
	if #roster < required then
		log("Roster lock cancelled: insufficient eligible players.")
		resetForTesting()
		return
	end
	for _, player in roster do
		active[player] = true
	end
	RoleService.AssignRoles(roster)
	log(string.format("Active roster locked: %d players.", #roster))
	setState("ROLE_REVEAL")
	for _, player in roster do
		deliverRole(player)
	end
	schedule(Config.Timing.RoleRevealDuration, function()
		log("ROLE_REVEAL complete. Development boundary; clearing temporary round.")
		resetForTesting()
	end)
end

local function tick()
	remaining -= 1
	log(string.format("Countdown: %d.", remaining))
	if remaining > 0 then
		schedule(1, tick)
		return
	end

	log("Countdown complete.")
	beginRoleReveal()
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

function RoundService.IsActivePlayer(player: Player): boolean
	return active[player] == true
end

function RoundService.GetActivePlayerCount(): number
	local count = 0
	for _ in active do
		count += 1
	end
	return count
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
	assert(Config.Players.MaximumPlayers >= required and Config.Players.MaximumPlayers % 1 == 0,
		"MaximumPlayers must be an integer at least equal to the required count")
	assert(Config.Timing.RoleRevealDuration > 0 and Config.Timing.RoleRevealDuration < math.huge,
		"RoleRevealDuration must be finite and positive")

	local remote = ensureRemote()
	roleRemote = remote

	running = true
	remaining = 0
	retryPending = false

	local function joined(player: Player)
		if present[player] then
			return
		end
		present[player] = true
		playerCount += 1
		if state == "ROLE_REVEAL" then
			log("Late joiner remains outside the active roster.")
		end
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
		if active[player] then
			-- Server Output only; never include an identity in role diagnostics.
			if RoleService.IsSaboteur(player) then
				log("Saboteur departed during ROLE_REVEAL; temporary cycle will reset normally.")
			else
				log("Active player departed during ROLE_REVEAL.")
			end
		end
		active[player] = nil
		ready[player] = nil
		delivered[player] = nil
		RoleService.ClearRole(player)
		log(string.format("Players=%d/%d. State=%s.", playerCount, required, state))
		evaluate()
	end

	table.insert(connections, Players.PlayerAdded:Connect(joined))
	table.insert(connections, Players.PlayerRemoving:Connect(leaving))
	-- Readiness is not eligibility: client arguments never select a role or roster.
	table.insert(connections, remote.OnServerEvent:Connect(function(player: Player, message: unknown)
		if message ~= "Ready" or not present[player] then
			return
		end
		ready[player] = true
		deliverRole(player)
	end))
	-- Connect before taking the snapshot; membership checks prevent double counting.
	for _, player in Players:GetPlayers() do
		present[player] = true
		playerCount += 1
	end
	setState("WAITING")
	for player in present do
		-- Re-handshake existing clients after Stop/Start as well as initial startup.
		remote:FireClient(player, "Ready")
	end
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
	table.clear(ready)
	clearRound()
	roleRemote = nil
	playerCount = 0
	remaining = 0
	retryPending = false
	setState("WAITING")
	log("Stopped.")
end

-- Only lifecycle methods and scalar getters are exposed, never mutable state.
return table.freeze(RoundService)
