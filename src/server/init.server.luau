--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RoundService = require(script:WaitForChild("RoundService"))

print(string.format("[Midnight Hotel][Server] Bootstrap ready. DevelopmentMode=%s", tostring(Config.DevelopmentMode)))

RoundService.Start()
game:BindToClose(function()
	RoundService.Stop()
end)
