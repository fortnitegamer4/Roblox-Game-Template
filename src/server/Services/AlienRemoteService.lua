local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local AlienEquipService = require(ServerScriptService.Services.AlienEquipService)

local Shared = {}

function Shared.OnStart()
    local requestEquipBestAliens = Remotes.Server:Get("requestEquipBestAliens") :: Net.ServerListenerEvent
    local requestAlienInventoryAction = Remotes.Server:Get("requestAlienInventoryAction") :: Net.ServerListenerEvent
    local alienInventoryActionResult = Remotes.Server:Get("alienInventoryActionResult") :: Net.ServerSenderEvent

    requestEquipBestAliens:Connect(function(player: Player)
        alienInventoryActionResult:SendToPlayer(player, AlienEquipService.EquipBest(player))
    end)

    requestAlienInventoryAction:Connect(function(player: Player, action: string, uid: string)
        local result

        if action == "Equip" then
            result = AlienEquipService.EquipAlien(player, uid)
        elseif action == "Unequip" then
            result = AlienEquipService.UnequipAlien(player, uid)
        elseif action == "Lock" then
            result = AlienEquipService.LockAlien(player, uid)
        elseif action == "Unlock" then
            result = AlienEquipService.UnlockAlien(player, uid)
        elseif action == "Delete" then
            result = AlienEquipService.DeleteAlien(player, uid)
        else
            result = {
                Success = false,
                Reason = "InvalidAction",
                Error = "That inventory action does not exist.",
                UID = uid,
            }
        end

        alienInventoryActionResult:SendToPlayer(player, result)
    end)
end

return Shared
