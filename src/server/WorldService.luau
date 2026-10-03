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
		local floor = part(folder, "Floor", Settings.FloorSize, center, Color3.fromRGB(95, 95, 105))
		-- Closed shells keep ordinary walking players in their assigned area.
		local height = Settings.WallHeight
		local thickness = Settings.WallThickness
		local size = Settings.FloorSize
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
		text.Text = if area == "Hotel" then "HOTEL TEST AREA" else "MIDNIGHT HOTEL - LOBBY"
		text.Parent = label
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
