--!strict
-- Server-defined prototype layout. Coordinates are relative to HotelCenter.
return table.freeze({
	AreaSize = Vector3.new(44, 0.15, 26),
	Areas = table.freeze({
		table.freeze({ name = "Bedroom", offset = Vector3.new(-32, 1.1, 23) }),
		table.freeze({ name = "Bathroom", offset = Vector3.new(32, 1.1, 23) }),
		table.freeze({ name = "Reception", offset = Vector3.new(-32, 1.1, 56) }),
		table.freeze({ name = "Hallway", offset = Vector3.new(32, 1.1, 56) }),
		table.freeze({ name = "Maintenance", offset = Vector3.new(-32, 1.1, 88) }),
		table.freeze({ name = "Storage", offset = Vector3.new(32, 1.1, 88) }),
	}),
	-- Eight unique reachable wall locations, all outside the northern Fuse panel area.
	ClueLocations = table.freeze({
		table.freeze({ name = "Bedroom_West", offset = Vector3.new(-58, 7, 20), yaw = 90 }),
		table.freeze({ name = "Bedroom_Nook", offset = Vector3.new(-58, 7, 36), yaw = 90 }),
		table.freeze({ name = "Bathroom_East", offset = Vector3.new(58, 7, 20), yaw = -90 }),
		table.freeze({ name = "Bathroom_Nook", offset = Vector3.new(58, 7, 36), yaw = -90 }),
		table.freeze({ name = "Reception_West", offset = Vector3.new(-58, 7, 58), yaw = 90 }),
		table.freeze({ name = "Hallway_East", offset = Vector3.new(58, 7, 58), yaw = -90 }),
		table.freeze({ name = "Maintenance_South", offset = Vector3.new(-30, 7, 103), yaw = 180 }),
		table.freeze({ name = "Storage_South", offset = Vector3.new(30, 7, 103), yaw = 180 }),
	}),
})
