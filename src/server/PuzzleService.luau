--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local TaskService = require(script.Parent:WaitForChild("TaskService"))
local HotelLayout = require(script.Parent:WaitForChild("HotelLayout"))
local Tuning = Config.FuseRoom
local PuzzleService = {}
local random = Random.new()
local solution: { string } = {}
local attempts: { [Player]: { string } } = {}
local lastInput: { [Player]: number } = {}
local feedbackTasks: { [Player]: thread } = {}
local connections: { RBXScriptConnection } = {}
local active = false
local processing = false
local generation = 0
local view: WorldService.FuseView? = nil

local function log(message: string)
	if Config.DevelopmentMode and game:GetService("RunService"):IsStudio() then
		print("[Midnight Hotel][PuzzleService] " .. message)
	end
end

local function cancelFeedback(player: Player)
	local thread = feedbackTasks[player]
	if thread then task.cancel(thread); feedbackTasks[player] = nil end
end

local function removePlayer(player: Player)
	cancelFeedback(player)
	attempts[player] = nil
	lastInput[player] = nil
end

function PuzzleService.Reset()
	active = false
	processing = false
	generation += 1
	for player in feedbackTasks do cancelFeedback(player) end
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(solution)
	table.clear(attempts)
	table.clear(lastInput)
	WorldService.HideFuseClues()
	local currentView = view
	if currentView then
		for _, prompt in currentView.prompts do prompt.Enabled = false end
		-- Shared signs never show any individual's progress or completion.
		for index, slot in currentView.slots do slot.Text = string.format("SLOT %d\n[ PERSONAL ]", index) end
		currentView.status.Text = "PERSONAL TASK TERMINAL"
	end
	log("Fuse Hunt reset.")
end

local function shuffle(values)
	for index = #values, 2, -1 do
		local other = random:NextInteger(1, index)
		values[index], values[other] = values[other], values[index]
	end
end

function PuzzleService.Start()
	PuzzleService.Reset()
	assert(#Tuning.Symbols == 4 and #HotelLayout.ClueLocations > 4, "Fuse Hunt requires four symbols and extra clue locations")
	local seen: { [string]: boolean } = {}
	for _, symbol in Tuning.Symbols do
		assert(not seen[symbol], "Fuse Hunt symbols must be unique")
		seen[symbol] = true
	end
	for _, value in { Tuning.InteractionDistance, Tuning.InteractionCooldown, Tuning.IncorrectFeedbackDuration } do
		assert(value > 0 and value < math.huge, "Fuse Hunt timings/distance must be finite and positive")
	end
	local currentView = WorldService.GetFuseRoom()
	view = currentView
	solution = table.clone(Tuning.Symbols)
	shuffle(solution)
	local locations: { number } = {}
	for index in HotelLayout.ClueLocations do table.insert(locations, index) end
	shuffle(locations)
	-- Ordered sampling without replacement also randomizes clue-number placement.
	for index, symbol in solution do
		WorldService.PlaceFuseClue(index, locations[index], string.format("CLUE %d\n%s", index, symbol))
		log(string.format("Clue %d placed at %s.", index, HotelLayout.ClueLocations[locations[index]].name))
	end
	active = true
	currentView.status.Text = "PERSONAL TASK TERMINAL"
	local roundGeneration = generation
	for symbol, prompt in currentView.prompts do
		local control = currentView.controls[symbol]
		prompt.Enabled = true
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			if roundGeneration ~= generation or not active or processing or not prompt.Enabled
				or not TaskService.CanWorkOn(player, "FuseHunt") or not table.find(Tuning.Symbols, symbol) then return end
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not character or not character:IsDescendantOf(workspace) or not root or not root:IsA("BasePart")
				or not humanoid or humanoid.Health <= 0 then return end
			if not ((root.Position - control.Position).Magnitude <= Tuning.InteractionDistance) then return end
			local now = os.clock()
			if now - (lastInput[player] or -math.huge) < Tuning.InteractionCooldown then return end
			lastInput[player] = now
			-- No yielding through validation/mutation. Different players have different attempts.
			processing = true
			cancelFeedback(player)
			local entered = attempts[player]
			if not entered then entered = {}; attempts[player] = entered end
			if table.find(entered, symbol) or solution[#entered + 1] ~= symbol then
				table.clear(entered)
				TaskService.UpdateFuseProgress(player, entered, "INCORRECT - YOUR SEQUENCE RESET")
				log(string.format("%s incorrect input; personal attempt reset.", player.Name))
				feedbackTasks[player] = task.delay(Tuning.IncorrectFeedbackDuration, function()
					feedbackTasks[player] = nil
					if generation == roundGeneration and active then
						TaskService.UpdateFuseProgress(player, entered, "RESTORE HOTEL POWER - 0/4")
					end
				end)
				processing = false
				return
			end
			table.insert(entered, symbol)
			TaskService.UpdateFuseProgress(player, entered, string.format("YOUR FUSE HUNT - %d/4", #entered))
			log(string.format("%s accepted %s; personal progress %d/4.", player.Name, symbol, #entered))
			if #entered == #solution then TaskService.CompleteLongTask(player, "FuseHunt") end
			processing = false
		end))
	end
	table.insert(connections, Players.PlayerRemoving:Connect(removePlayer))
	log("Fuse Hunt started; attempts and completion are personal.")
end

function PuzzleService.GetProgress(player: Player): number
	local entered = attempts[player]
	return if entered then #entered else 0
end

return table.freeze(PuzzleService)
