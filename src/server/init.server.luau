--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print(string.format("[Midnight Hotel][Server] Bootstrap ready. DevelopmentMode=%s", tostring(Config.DevelopmentMode)))
