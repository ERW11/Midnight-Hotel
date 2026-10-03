--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print(string.format("[Midnight Hotel][Client] Bootstrap ready. DevelopmentMode=%s", tostring(Config.DevelopmentMode)))

local remote = ReplicatedStorage:WaitForChild("MidnightHotelRemotes"):WaitForChild("PrivateRole")
assert(remote:IsA("RemoteEvent"), "PrivateRole must be a RemoteEvent")

remote.OnClientEvent:Connect(function(message: unknown, role: unknown)
	if message == "Ready" then
		remote:FireServer("Ready")
	elseif message == "Role" then
		if role ~= "Guest" and role ~= "Saboteur" then
			warn("[Midnight Hotel][Client] Invalid private role received.")
			return
		end
		-- Studio-only diagnostics also support testing DevelopmentMode=false.
		if game:GetService("RunService"):IsStudio() then
			print("[Midnight Hotel][Client] Private role received: " .. role)
		end
	end
end)

-- Subscribe before announcing readiness. No role is cached on the client.
remote:FireServer("Ready")
