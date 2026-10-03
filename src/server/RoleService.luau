--!strict

type Role = "Guest" | "Saboteur"
local RoleService = {}
local roles: { [Player]: Role } = {}
local random = Random.new()

function RoleService.AssignRoles(roster: { Player })
	assert(#roster > 0, "Cannot assign roles to an empty roster")
	local unique: { [Player]: boolean } = {}
	for _, player in roster do
		assert(not unique[player], "Roster contains a duplicate player")
		unique[player] = true
	end
	table.clear(roles)
	local saboteurIndex = random:NextInteger(1, #roster)
	for index, player in roster do
		roles[player] = if index == saboteurIndex then "Saboteur" else "Guest"
	end
end

function RoleService.GetRole(player: Player): Role?
	return roles[player]
end

function RoleService.IsSaboteur(player: Player): boolean
	return roles[player] == "Saboteur"
end

function RoleService.IsGuest(player: Player): boolean
	return roles[player] == "Guest"
end

function RoleService.HasRole(player: Player): boolean
	return roles[player] ~= nil
end

function RoleService.ClearRole(player: Player)
	roles[player] = nil
end

function RoleService.ClearRoles()
	table.clear(roles)
end

return table.freeze(RoleService)
