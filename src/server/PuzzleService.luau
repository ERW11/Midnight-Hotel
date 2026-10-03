--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local Tuning = Config.FuseRoom
local PuzzleService = {}
local random = Random.new()
local solution: { string } = {}
local entered: { string } = {}
local lastInput: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local active = false
local complete = false
local processing = false
local generation = 0
local feedbackTask: thread? = nil
local view: WorldService.FuseView? = nil

local function log(message: string)
	if Config.DevelopmentMode then
		print("[Midnight Hotel][PuzzleService] " .. message)
	end
end

local function cancelFeedback()
	if feedbackTask then
		task.cancel(feedbackTask)
		feedbackTask = nil
	end
end

local function renderProgress(currentView: WorldService.FuseView)
	for index, slot in currentView.slots do
		slot.Text = string.format("SLOT %d\n[ %s ]", index, entered[index] or "EMPTY")
	end
end

function PuzzleService.Reset()
	active = false
	complete = false
	processing = false
	generation += 1
	cancelFeedback()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(solution)
	table.clear(entered)
	table.clear(lastInput)
	local currentView = view
	if currentView then
		for _, prompt in currentView.prompts do
			prompt.Enabled = false
		end
		for _, clue in currentView.clues do
			clue.Text = "CLUE OFFLINE"
		end
		renderProgress(currentView)
		currentView.status.Text = "WAITING FOR ROUND"
	end
	log("Puzzle reset.")
end

-- RoundService supplies non-yielding server predicates/callbacks, avoiding a circular require.
function PuzzleService.Start(canInteract: (Player) -> boolean, onCompleted: () -> ())
	PuzzleService.Reset()
	for _, value in { Tuning.InteractionDistance, Tuning.InteractionCooldown,
		Tuning.IncorrectFeedbackDuration, Tuning.CompletionDelay } do
		assert(value > 0 and value < math.huge, "Fuse Room timings and distance must be finite and positive")
	end
	local currentView = WorldService.GetFuseRoom()
	view = currentView
	assert(#Tuning.Symbols == 4, "Fuse Room requires four symbols")
	local seen: { [string]: boolean } = {}
	for _, symbol in Tuning.Symbols do
		assert(not seen[symbol], "Fuse Room symbols must be unique")
		seen[symbol] = true
	end
	solution = table.clone(Tuning.Symbols)
	-- Fisher-Yates: each symbol appears exactly once; all permutations are possible.
	for index = #solution, 2, -1 do
		local other = random:NextInteger(1, index)
		solution[index], solution[other] = solution[other], solution[index]
	end
	for index, clue in currentView.clues do
		clue.Text = string.format("POSITION %d:\n%s", index, solution[index])
	end
	active = true
	currentView.status.Text = "RESTORE POWER - 0/4"
	local roundGeneration = generation
	for symbol, prompt in currentView.prompts do
		local control = currentView.controls[symbol]
		prompt.Enabled = true
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			if roundGeneration ~= generation or not active or complete or processing
				or not prompt.Enabled or player.Parent ~= Players or not canInteract(player)
				or not table.find(Tuning.Symbols, symbol) then
				return
			end
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not character or not character:IsDescendantOf(workspace) or not root or not root:IsA("BasePart")
				or not humanoid or humanoid.Health <= 0 then
				return
			end
			local distance = (root.Position - control.Position).Magnitude
			if not (distance <= Tuning.InteractionDistance) then
				return -- Also rejects NaN positions.
			end
			local now = os.clock()
			if now - (lastInput[player] or -math.huge) < Tuning.InteractionCooldown then
				return
			end
			lastInput[player] = now
			-- No yielding from validation through mutation; queued multiplayer events serialize.
			processing = true
			cancelFeedback()
			if table.find(entered, symbol) or solution[#entered + 1] ~= symbol then
				table.clear(entered)
				renderProgress(currentView)
				currentView.status.Text = "INCORRECT - SEQUENCE RESET"
				log("Incorrect sequence; progress reset.")
				feedbackTask = task.delay(Tuning.IncorrectFeedbackDuration, function()
					feedbackTask = nil
					if generation == roundGeneration and active and not complete then
						currentView.status.Text = string.format("RESTORE POWER - %d/4", #entered)
					end
				end)
				processing = false
				return
			end
			table.insert(entered, symbol)
			renderProgress(currentView)
			currentView.status.Text = string.format("RESTORE POWER - %d/4", #entered)
			log(string.format("Accepted %s; progress %d/4.", symbol, #entered))
			if #entered == #solution then
				complete = true
				active = false
				for _, item in currentView.prompts do
					item.Enabled = false
				end
				currentView.status.Text = "POWER RESTORED"
				log("Fuse Room completed.")
				processing = false
				onCompleted() -- One server callback, after the completion latch is set.
				return
			end
			processing = false
		end))
	end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		lastInput[player] = nil
	end))
	log("Fuse Room puzzle started.")
end

function PuzzleService.GetProgress(): number
	return #entered
end

function PuzzleService.IsComplete(): boolean
	return complete
end

return table.freeze(PuzzleService)
