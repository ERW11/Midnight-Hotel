--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print(string.format("[Midnight Hotel][Client] Bootstrap ready. DevelopmentMode=%s", tostring(Config.DevelopmentMode)))
