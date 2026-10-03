--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Settings = Config.World

type Area = "Lobby" | "Hotel"
type Destination = { area: Area, slot: number }
local WorldService = {}
local world: Folder? = nil
local destinations: { [Player]: Destination } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local pending: { [Player]: thread } = {}
export type FuseView = {
	controls: { [string]: Part },
	prompts: { [string]: ProximityPrompt },
	slots: { TextLabel },
	clues: { TextLabel },
	status: TextLabel,
}
local fuseView: FuseView? = nil

local function position(area: Area, slot: number): CFrame
	local center = if area == "Hotel" then Settings.HotelCenter else Settings.LobbyCenter
	local columns = Settings.SpawnColumns
	local row = math.floor((slot - 1) / columns)
	local column = (slot - 1) % columns
	return CFrame.new(center + Vector3.new(
		(column - (columns - 1) / 2) * Settings.SpawnSpacing,
		Settings.FloorSize.Y / 2 + Settings.SpawnLift,
		row * Settings.SpawnSpacing
	))
end

local function part(parent: Instance, name: string, size: Vector3, location: Vector3, color: Color3): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.Size = size
	item.Position = location
	item.Color = color
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function display(parent: BasePart, text: string): TextLabel
	-- Text occupies only its physical sign face; it cannot float over nearby signs.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Adornee = parent
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.FuseRoom.PixelsPerStud
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(Config.FuseRoom.TextPadding, 0)
	padding.PaddingRight = UDim.new(Config.FuseRoom.TextPadding, 0)
	padding.PaddingTop = UDim.new(Config.FuseRoom.TextPadding, 0)
	padding.PaddingBottom = UDim.new(Config.FuseRoom.TextPadding, 0)
	padding.Parent = label
	return label
end

local function buildFuseRoom(hotel: Instance)
	local tuning = Config.FuseRoom
	local center = Settings.HotelCenter
	local room = Instance.new("Folder")
	room.Name = "FuseRoom"
	room.Parent = hotel
	local panel = part(room, "ControlPanel", tuning.PanelSize, center + tuning.PanelOffset, Color3.fromRGB(60, 65, 70))
	local statusSign = part(room, "StatusSign", tuning.StatusSize, center + tuning.StatusOffset, panel.Color)
	local status = display(statusSign, "WAITING FOR ROUND")
	local objective = part(room, "ObjectiveSign", tuning.ObjectiveSize, center + tuning.ObjectiveOffset, panel.Color)
	display(objective, "RESTORE POWER\nFind the clues and enter the fuse sequence.")
	local roomSign = part(room, "RoomSign", tuning.RoomSignSize, center + tuning.RoomSignOffset, panel.Color)
	roomSign.CFrame *= CFrame.Angles(0, math.pi, 0)
	display(roomSign, "ROOM 1 - THE FUSE ROOM")
	local view: FuseView = { controls = {}, prompts = {}, slots = {}, clues = {}, status = status }
	for index, symbol in tuning.Symbols do
		local centeredIndex = index - (#tuning.Symbols + 1) / 2
		local slot = part(room, "Slot" .. index, tuning.SlotSize,
			center + tuning.PanelOffset + Vector3.new(centeredIndex * tuning.SlotSpacing, 0, 2), panel.Color)
		view.slots[index] = display(slot, string.format("SLOT %d\n[ EMPTY ]", index))
		local control = part(room, "Control_" .. symbol, tuning.ControlSize,
			center + tuning.ControlOffset + Vector3.new(centeredIndex * tuning.ControlSpacing, 0, 0), Color3.fromRGB(150, 140, 80))
		view.controls[symbol] = control
		display(control, symbol)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "InstallFuse"
		prompt.ActionText = "Install " .. symbol
		prompt.ObjectText = "Fuse control"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = tuning.InteractionDistance
		prompt.RequiresLineOfSight = true
		prompt.UIOffset = tuning.PromptOffset
		prompt.Enabled = false
		prompt.Parent = control
		view.prompts[symbol] = prompt
		local clue = part(room, "Clue" .. index, tuning.ClueSize,
			center + tuning.ClueOffsets[index], Color3.fromRGB(75, 85, 95))
		clue.CFrame *= CFrame.Angles(0, math.rad(tuning.ClueYawDegrees[index]), 0)
		view.clues[index] = display(clue, "CLUE OFFLINE")
	end
	fuseView = view
end

function WorldService.EnsureWorld()
	if world and world.Parent == workspace then
		return
	end
	-- Never delete unrelated Studio objects on a name collision.
	assert(not workspace:FindFirstChild(Settings.FolderName), "Greybox name is already owned by another object")
	local root = Instance.new("Folder")
	root.Name = Settings.FolderName
	local areas: { Area } = { "Lobby", "Hotel" }
	for _, area in areas do
		local center = if area == "Hotel" then Settings.HotelCenter else Settings.LobbyCenter
		local folder = Instance.new("Folder")
		folder.Name = area
		folder.Parent = root
		local size = if area == "Hotel" then Config.FuseRoom.FloorSize else Settings.FloorSize
		local floor = part(folder, "Floor", size, center, Color3.fromRGB(95, 95, 105))
		-- Closed shells keep ordinary walking players in their assigned area.
		local height = if area == "Hotel" then Config.FuseRoom.WallHeight else Settings.WallHeight
		local thickness = Settings.WallThickness
		local y = (size.Y + height) / 2
		part(folder, "NorthWall", Vector3.new(size.X, height, thickness), center + Vector3.new(0, y, -size.Z / 2), floor.Color)
		part(folder, "SouthWall", Vector3.new(size.X, height, thickness), center + Vector3.new(0, y, size.Z / 2), floor.Color)
		part(folder, "EastWall", Vector3.new(thickness, height, size.Z), center + Vector3.new(size.X / 2, y, 0), floor.Color)
		part(folder, "WestWall", Vector3.new(thickness, height, size.Z), center + Vector3.new(-size.X / 2, y, 0), floor.Color)
		for slot = 1, Config.Players.MaximumPlayers do
			local marker = part(folder, string.format("Spawn%02d", slot), Settings.MarkerSize,
				position(area, slot).Position - Vector3.new(0, Settings.SpawnLift, 0),
				if area == "Hotel" then Color3.fromRGB(180, 150, 80) else Color3.fromRGB(80, 150, 180))
			marker.CanCollide = false
		end
		if area == "Lobby" then
			local label = Instance.new("BillboardGui")
			label.Name = "AreaLabel"
			label.Adornee = floor
			label.Size = UDim2.fromOffset(Settings.LabelSize.X, Settings.LabelSize.Y)
			label.StudsOffset = Settings.LabelOffset
			label.MaxDistance = Settings.LabelMaxDistance
			label.Parent = floor
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextScaled = true
			text.Text = "MIDNIGHT HOTEL - LOBBY"
			text.Parent = label
		end
		if area == "Hotel" then
			buildFuseRoom(folder)
		end
	end
	-- A neutral lobby spawn also provides a safe initial engine spawn location.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Settings.MarkerSize
	spawn.Position = Settings.LobbyCenter + Vector3.new(0, Settings.FloorSize.Y / 2, -Settings.SpawnSpacing)
	spawn.Parent = root
	root.Parent = workspace
	world = root
	print("[Midnight Hotel][WorldService] Greybox ready: Lobby and Hotel.")
end

-- Server-only view references; authoritative puzzle state is never stored here.
function WorldService.GetFuseRoom(): FuseView
	WorldService.EnsureWorld()
	assert(fuseView, "Fuse Room was not initialized")
	return fuseView
end

local function cancelMove(player: Player)
	local thread = pending[player]
	if thread then
		task.cancel(thread)
		pending[player] = nil
	end
end

local function tryMove(player: Player, destination: Destination): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not character.Parent or not root or not root:IsA("BasePart")
		or not humanoid or humanoid.Health <= 0 then
		return false
	end
	character:PivotTo(position(destination.area, destination.slot))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function requestMove(player: Player)
	cancelMove(player)
	local destination = destinations[player]
	if not destination or tryMove(player, destination) then
		return
	end
	pending[player] = task.defer(function()
		local deadline = os.clock() + Config.Timing.CharacterPositionTimeout
		repeat
			if player.Parent ~= Players or destinations[player] ~= destination then
				pending[player] = nil
				return
			end
			if tryMove(player, destination) then
				pending[player] = nil
				return
			end
			task.wait(Config.Timing.CharacterPositionPollInterval)
		until os.clock() >= deadline
		pending[player] = nil
		warn("[Midnight Hotel][WorldService] Character positioning timed out; next respawn will retry.")
	end)
end

function WorldService.SetDestination(player: Player, area: Area, slot: number)
	WorldService.EnsureWorld()
	destinations[player] = { area = area, slot = slot }
	if not characterConnections[player] then
		characterConnections[player] = player.CharacterAdded:Connect(function()
			requestMove(player)
		end)
	end
	requestMove(player)
end

function WorldService.RemovePlayer(player: Player)
	cancelMove(player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	destinations[player] = nil
end

function WorldService.Stop()
	for player, destination in destinations do
		-- Immediate best effort only; stopping must not leave a waiting task behind.
		tryMove(player, { area = "Lobby", slot = destination.slot })
		WorldService.RemovePlayer(player)
	end
	-- Geometry belongs to the server session, not a round; reuse it on Start.
end

return table.freeze(WorldService)
