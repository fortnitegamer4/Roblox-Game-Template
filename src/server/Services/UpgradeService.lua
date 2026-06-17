local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local UpgradeConfig = require(ReplicatedStorage.Configs.UpgradeConfig)
local FuelService = require(ServerScriptService.Services.FuelService)
local Store = require(ServerScriptService.Store)

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getAlienState(player: Player)
    return Store:getState().players.aliens[getPlayerId(player)]
end

function Shared.PurchaseUpgrade(player: Player, upgradeId: string)
    local alienState = getAlienState(player)
    if not alienState then
        return {
            Success = false,
            Reason = "DataNotLoaded",
            Error = "Player data is still loading.",
            UpgradeId = upgradeId,
        }
    end

    local definition = UpgradeConfig.Upgrades[upgradeId]
    if not definition then
        return {
            Success = false,
            Reason = "InvalidUpgrade",
            Error = "That upgrade does not exist.",
            UpgradeId = upgradeId,
        }
    end

    local currentLevel = alienState[upgradeId]
    if typeof(currentLevel) ~= "number" then
        return {
            Success = false,
            Reason = "InvalidUpgrade",
            Error = "That upgrade cannot be purchased.",
            UpgradeId = upgradeId,
        }
    end

    if currentLevel >= definition.MaxLevel then
        return {
            Success = false,
            Reason = "MaxLevel",
            Error = `{definition.DisplayName} is already maxed.`,
            UpgradeId = upgradeId,
            Level = currentLevel,
        }
    end

    local cost = UpgradeConfig.GetCost(upgradeId, currentLevel)
    if not cost then
        return {
            Success = false,
            Reason = "MaxLevel",
            Error = `{definition.DisplayName} is already maxed.`,
            UpgradeId = upgradeId,
            Level = currentLevel,
        }
    end

    if not FuelService.CanAfford(player, cost) then
        return {
            Success = false,
            Reason = "NotEnoughFuel",
            Error = `Not enough Fuel. Need {cost}.`,
            UpgradeId = upgradeId,
            Cost = cost,
            Fuel = FuelService.GetFuel(player) or 0,
            Level = currentLevel,
        }
    end

    if not FuelService.RemoveFuel(player, cost) then
        return {
            Success = false,
            Reason = "FuelSpendFailed",
            Error = "Unable to spend Fuel right now.",
            UpgradeId = upgradeId,
            Cost = cost,
            Level = currentLevel,
        }
    end

    Store.incrementUpgradeLevel(getPlayerId(player), upgradeId)

    return {
        Success = true,
        UpgradeId = upgradeId,
        Cost = cost,
        Level = currentLevel + 1,
    }
end

function Shared.OnStart()
    local requestUpgradePurchase = Remotes.Server:Get("requestUpgradePurchase") :: Net.ServerListenerEvent
    local upgradePurchaseResult = Remotes.Server:Get("upgradePurchaseResult") :: Net.ServerSenderEvent

    requestUpgradePurchase:Connect(function(player: Player, upgradeId: string)
        upgradePurchaseResult:SendToPlayer(player, Shared.PurchaseUpgrade(player, upgradeId))
    end)
end

return Shared
