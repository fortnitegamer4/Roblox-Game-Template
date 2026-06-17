local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local AlienConfig = require(ReplicatedStorage.Configs.AlienConfig)
local FuelService = require(ServerScriptService.Services.FuelService)
local Remotes = require(ReplicatedStorage.Remotes)
local Store = require(ServerScriptService.Store)

local nextScanTimes = {}

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getAlienState(player: Player)
    return Store:getState().players.aliens[getPlayerId(player)]
end

local function getCooldown(alienState): number
    return AlienConfig.GetScanCooldown(alienState.RollSpeedLevel or 0)
end

local function getLuckMultiplier(player): number
    local alienState = getAlienState(player)
    local luckLevel = if alienState then alienState.LuckLevel else 0

    return 1 + (luckLevel * AlienConfig.LuckPerLevel)
end

local function getRollWeight(alien, luckMultiplier: number): number
    local exponent = AlienConfig.RarityLuckExponent[alien.Rarity] or 0
    local luckBonus = luckMultiplier ^ exponent

    return luckBonus / alien.BaseOdds
end

local function chooseAlien(player: Player)
    local luckMultiplier = getLuckMultiplier(player)
    local totalWeight = 0

    for _, alien in AlienConfig.Aliens do
        totalWeight += getRollWeight(alien, luckMultiplier)
    end

    local roll = Random.new():NextNumber(0, totalWeight)
    local cursor = 0

    for _, alien in AlienConfig.Aliens do
        cursor += getRollWeight(alien, luckMultiplier)

        if roll <= cursor then
            return alien
        end
    end

    return AlienConfig.Aliens[1]
end

function Shared.GetCooldownRemaining(player: Player): number
    local nextScanTime = nextScanTimes[player.UserId] or 0

    return math.max(nextScanTime - os.clock(), 0)
end

function Shared.RollAlien(player: Player)
    local alienState = getAlienState(player)
    if not alienState then
        return {
            Success = false,
            Error = "Player data is still loading.",
            Reason = "DataNotLoaded",
        }
    end

    local cooldownRemaining = Shared.GetCooldownRemaining(player)
    if cooldownRemaining > 0 then
        return {
            Success = false,
            Error = `Scanner cooling down: {string.format("%.1f", cooldownRemaining)}s`,
            Reason = "Cooldown",
            CooldownRemaining = cooldownRemaining,
            Cooldown = getCooldown(alienState),
            Cost = AlienConfig.ScanCost,
        }
    end

    local isFreeScan = not alienState.HasUsedFreeScan
    local scanCost = if isFreeScan then 0 else AlienConfig.ScanCost

    if scanCost > 0 and not FuelService.CanAfford(player, scanCost) then
        return {
            Success = false,
            Error = `Not enough Fuel. Need {scanCost}.`,
            Reason = "NotEnoughFuel",
            Cost = scanCost,
            IsFreeScan = false,
            Fuel = FuelService.GetFuel(player) or 0,
        }
    end

    if scanCost > 0 and not FuelService.RemoveFuel(player, scanCost) then
        return {
            Success = false,
            Error = "Unable to spend Fuel right now.",
            Reason = "FuelSpendFailed",
            Cost = scanCost,
            IsFreeScan = false,
        }
    end

    local cooldown = getCooldown(alienState)
    nextScanTimes[player.UserId] = os.clock() + cooldown

    local definition = chooseAlien(player)
    local ownedAlien = {
        UID = HttpService:GenerateGUID(false),
        AlienId = definition.AlienId,
        Variant = definition.Variant,
    }

    Store.addAlien(getPlayerId(player), ownedAlien)
    Store.markFreeScanUsed(getPlayerId(player))

    return {
        Success = true,
        OwnedAlien = ownedAlien,
        Definition = definition,
        Cost = scanCost,
        Cooldown = cooldown,
        IsFreeScan = isFreeScan,
    }
end

function Shared.OnStart()
    local requestAlienRoll = Remotes.Server:Get("requestAlienRoll") :: Net.ServerListenerEvent
    local alienRollResult = Remotes.Server:Get("alienRollResult") :: Net.ServerSenderEvent

    Players.PlayerRemoving:Connect(function(player: Player)
        nextScanTimes[player.UserId] = nil
    end)

    requestAlienRoll:Connect(function(player: Player)
        local result = Shared.RollAlien(player)

        alienRollResult:SendToPlayer(player, result)
    end)
end

return Shared
