local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local AlienEquipService = require(ServerScriptService.Services.AlienEquipService)

local Shared = {}

function Shared.OnStart()
    local requestEquipBestAliens = Remotes.Server:Get("requestEquipBestAliens") :: Net.ServerListenerEvent

    requestEquipBestAliens:Connect(function(player: Player)
        AlienEquipService.EquipBest(player)
    end)
end

return Shared
