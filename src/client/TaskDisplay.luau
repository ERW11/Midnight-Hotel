--!strict
-- Prototype personal status on the existing panel only. No authoritative client state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TaskDisplay = {}

function TaskDisplay.Start()
	local remote = ReplicatedStorage:WaitForChild("MidnightHotelRemotes"):WaitForChild("PrivateTasks")
	assert(remote:IsA("RemoteEvent"))
	local labels: { TextLabel } = {}
	local statusLabel: TextLabel? = nil
	local latest: any = nil
	local rendering = false
	local function render()
		local status = statusLabel
		if not status or not latest or rendering then return end
		rendering = true
		for index, label in labels do
			local text = string.format("SLOT %d\n[ %s ]", index, latest.entered[index] or "EMPTY")
			if label.Text ~= text then label.Text = text end
		end
		local text = latest.feedback .. (if latest.longTask then "\nSHORT TASK: PENDING" else "")
		if status.Text ~= text then status.Text = text end
		rendering = false
	end
	remote.OnClientEvent:Connect(function(message: unknown, payload: any)
		if message == "Ready" then remote:FireServer("Ready"); return end
		if message ~= "Status" or typeof(payload) ~= "table" then return end
		if payload.longTask ~= nil and payload.longTask ~= "FuseHunt" then return end
		if payload.shortTask ~= nil or typeof(payload.longComplete) ~= "boolean"
			or payload.shortComplete ~= false or typeof(payload.feedback) ~= "string"
			or typeof(payload.entered) ~= "table" or #payload.entered > 4 then return end
		for _, symbol in payload.entered do
			if typeof(symbol) ~= "string" or not table.find(Config.FuseRoom.Symbols, symbol) then return end
		end
		latest = payload
		render()
		if RunService:IsStudio() then
			print("[Midnight Hotel][Client] My tasks: " .. payload.feedback
				.. (if payload.longTask then "; Short Task pending." else "."))
		end
	end)
	remote:FireServer("Ready")
	-- Capture only our local replicas. These text changes never replicate to other players.
	local room = workspace:WaitForChild(Config.World.FolderName):WaitForChild("Hotel"):WaitForChild("FuseRoom")
	local status = room:WaitForChild("StatusSign"):WaitForChild("Display"):WaitForChild("Text")
	assert(status:IsA("TextLabel"))
	statusLabel = status
	for index = 1, #Config.FuseRoom.Symbols do
		local label = room:WaitForChild("Slot" .. index):WaitForChild("Display"):WaitForChild("Text")
		assert(label:IsA("TextLabel"))
		labels[index] = label
		label:GetPropertyChangedSignal("Text"):Connect(function() render() end)
	end
	status:GetPropertyChangedSignal("Text"):Connect(function() render() end)
	render()
end

return table.freeze(TaskDisplay)
