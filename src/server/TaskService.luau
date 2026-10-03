--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RoleService = require(script.Parent:WaitForChild("RoleService"))
local TaskService = {}
type Record = {
	longTask: string, shortTask: string?, longComplete: boolean, shortComplete: boolean,
	entered: { string }, feedback: string,
}
local records: { [Player]: Record } = {}
local ready: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local remote: RemoteEvent? = nil
local eligible: ((Player) -> boolean)? = nil

local function log(message: string)
	if Config.DevelopmentMode and game:GetService("RunService"):IsStudio() then
		print("[Midnight Hotel][TaskService] " .. message)
	end
end

-- A fresh copy: no mutable authoritative state escapes this module.
function TaskService.GetStatus(player: Player)
	local record = records[player]
	return {
		longTask = if record then record.longTask else nil,
		shortTask = if record then record.shortTask else nil,
		longComplete = if record then record.longComplete else false,
		shortComplete = if record then record.shortComplete else false,
		entered = if record then table.clone(record.entered) else {},
		feedback = if record then record.feedback else "NO ACTIVE TASK ASSIGNMENT",
	}
end

local function send(player: Player)
	local event = remote
	if event and ready[player] and player.Parent == Players then
		event:FireClient(player, "Status", TaskService.GetStatus(player))
	end
end

function TaskService.RemovePlayer(player: Player)
	records[player] = nil
	ready[player] = nil
	lastRequest[player] = nil
end

function TaskService.Reset()
	table.clear(records)
	for player in ready do send(player) end
end

function TaskService.Stop()
	TaskService.Reset()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(ready)
	table.clear(lastRequest)
	remote = nil
	eligible = nil
end

function TaskService.Start(canWork: (Player) -> boolean)
	TaskService.Stop()
	eligible = canWork
	local folder = ReplicatedStorage:FindFirstChild("MidnightHotelRemotes")
	assert(folder and folder:IsA("Folder"), "RoundService must initialize remotes first")
	local event = folder:FindFirstChild("PrivateTasks")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PrivateTasks"
		event.Parent = folder
	end
	assert(event:IsA("RemoteEvent"), "PrivateTasks must be a RemoteEvent")
	remote = event
	table.insert(connections, event.OnServerEvent:Connect(function(player: Player, message: unknown)
		-- Readiness can only request the sender's own status, never alter it.
		if message ~= "Ready" or player.Parent ~= Players then return end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Config.Tasks.StatusRequestCooldown then return end
		lastRequest[player] = now
		ready[player] = true
		send(player)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(TaskService.RemovePlayer))
	for _, player in Players:GetPlayers() do event:FireClient(player, "Ready") end
end

function TaskService.AssignRound(roster: { Player })
	TaskService.Reset()
	for _, player in roster do
		if player.Parent == Players and RoleService.IsGuest(player) then
			records[player] = {
				longTask = "FuseHunt", shortTask = nil, longComplete = false, shortComplete = false,
				entered = {}, feedback = "RESTORE HOTEL POWER - FIND CLUES 1-4",
			}
			log(string.format("Assigned Fuse Hunt Long Task to %s; Short Task pending.", player.Name))
		end
		send(player)
	end
end

function TaskService.CanWorkOn(player: Player, taskId: string): boolean
	local record = records[player]
	local predicate = eligible
	return record ~= nil and record.longTask == taskId and not record.longComplete
		and player.Parent == Players and RoleService.IsGuest(player)
		and predicate ~= nil and predicate(player)
end

function TaskService.UpdateFuseProgress(player: Player, entered: { string }, feedback: string)
	if not TaskService.CanWorkOn(player, "FuseHunt") then return end
	local record = records[player]
	record.entered = table.clone(entered)
	record.feedback = feedback
	send(player)
end

-- Called only by a server task implementation after validation, never by a remote.
function TaskService.CompleteLongTask(player: Player, taskId: string): boolean
	if not TaskService.CanWorkOn(player, taskId) then return false end
	local record = records[player]
	record.longComplete = true
	record.feedback = "POWER RESTORED - YOUR LONG TASK COMPLETE"
	send(player)
	log(string.format("%s completed %s. Round continues; Short Task pending.", player.Name, taskId))
	return true
end

return table.freeze(TaskService)
