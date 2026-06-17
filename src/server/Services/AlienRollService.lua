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
local autoScanPlayers = {}
local alienRollResultRemote = nil
local autoScanStateRemote = nil

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getAlienState(player: Player)
    return Store:getState().players.aliens[getPlayerId(player)]
end

local function getCooldown(alienState): number
    return AlienConfig.GetScanCooldown(alienState.RollSpeedLevel or 0, alienState.IndexRollSpeedBonus or 0)
end

local function getInventoryCount(alienState): number
    local count = 0

    for _ in alienState.AlienInventory do
        count += 1
    end

    return count
end

local function getLuckMultiplier(player): number
    local alienState = getAlienState(player)
    local luckLevel = if alienState then alienState.LuckLevel else 0
    local indexBonus = if alienState then alienState.IndexLuckBonus or 0 else 0

    return 1 + (luckLevel * AlienConfig.LuckPerLevel) + indexBonus
end

local function getAutoScanUnlocked(alienState): boolean
    return alienState.AutoScanUnlocked == true or (alienState.TotalScans or 0) >= AlienConfig.AutoScanUnlockScans
end

local function sendAutoScanState(player: Player, enabled: boolean, reason: string?)
    local alienState = getAlienState(player)

    if autoScanStateRemote then
        autoScanStateRemote:SendToPlayer(player, {
            Enabled = enabled,
            Reason = reason,
            Unlocked = if alienState then getAutoScanUnlocked(alienState) else false,
            TotalScans = if alienState then alienState.TotalScans or 0 else 0,
            RequiredScans = AlienConfig.AutoScanUnlockScans,
            CooldownRemaining = Shared.GetCooldownRemaining(player),
        })
    end
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

    local inventoryCount = getInventoryCount(alienState)
    if inventoryCount >= AlienConfig.MaxAlienInventory then
        return {
            Success = false,
            Error = "Alien inventory is full.",
            Reason = "InventoryFull",
            InventoryCount = inventoryCount,
            InventoryCapacity = AlienConfig.MaxAlienInventory,
            Cost = AlienConfig.ScanCost,
        }
    end

    local isStarterScan = not alienState.HasUsedFreeScan
    local scanCost = AlienConfig.ScanCost

    if scanCost > 0 and not FuelService.CanAfford(player, scanCost) then
        return {
            Success = false,
            Error = `Not enough Fuel. Need {scanCost}.`,
            Reason = "NotEnoughFuel",
            Cost = scanCost,
            IsStarterScan = isStarterScan,
            Fuel = FuelService.GetFuel(player) or 0,
        }
    end

    if scanCost > 0 and not FuelService.RemoveFuel(player, scanCost) then
        return {
            Success = false,
            Error = "Unable to spend Fuel right now.",
            Reason = "FuelSpendFailed",
            Cost = scanCost,
            IsStarterScan = isStarterScan,
        }
    end

    local cooldown = getCooldown(alienState)
    nextScanTimes[player.UserId] = os.clock() + cooldown

    local definition = if isStarterScan then AlienConfig.ById[AlienConfig.StarterAlienId] else chooseAlien(player)
    definition = definition or chooseAlien(player)
    local ownedAlien = {
        UID = HttpService:GenerateGUID(false),
        AlienId = definition.AlienId,
        Variant = definition.Variant,
    }

    Store.addAlien(getPlayerId(player), ownedAlien)
    Store.markFreeScanUsed(getPlayerId(player))
    Store.incrementTotalScans(getPlayerId(player))

    local updatedAlienState = getAlienState(player)
    local totalScans = if updatedAlienState then updatedAlienState.TotalScans or 0 else (alienState.TotalScans or 0) + 1

    if updatedAlienState and totalScans >= AlienConfig.AutoScanUnlockScans and not updatedAlienState.AutoScanUnlocked then
        Store.setAutoScanUnlocked(getPlayerId(player), true)
        updatedAlienState = getAlienState(player)
    end

    return {
        Success = true,
        OwnedAlien = ownedAlien,
        Definition = definition,
        Cost = scanCost,
        Cooldown = cooldown,
        IsStarterScan = isStarterScan,
        TotalScans = totalScans,
        AutoScanUnlocked = if updatedAlienState then getAutoScanUnlocked(updatedAlienState) else false,
    }
end

function Shared.SetAutoScan(player: Player, enabled: boolean)
    local userId = player.UserId

    if not enabled then
        autoScanPlayers[userId] = nil
        sendAutoScanState(player, false, "Stopped")

        return {
            Success = true,
            Enabled = false,
            Reason = "Stopped",
        }
    end

    local alienState = getAlienState(player)
    if not alienState then
        sendAutoScanState(player, false, "DataNotLoaded")

        return {
            Success = false,
            Enabled = false,
            Reason = "DataNotLoaded",
            Error = "Player data is still loading.",
        }
    end

    if (alienState.TotalScans or 0) >= AlienConfig.AutoScanUnlockScans and not alienState.AutoScanUnlocked then
        Store.setAutoScanUnlocked(getPlayerId(player), true)
        alienState = getAlienState(player)
    end

    if not alienState then
        sendAutoScanState(player, false, "DataNotLoaded")

        return {
            Success = false,
            Enabled = false,
            Reason = "DataNotLoaded",
            Error = "Player data is still loading.",
        }
    end

    if not getAutoScanUnlocked(alienState) then
        sendAutoScanState(player, false, "Locked")

        return {
            Success = false,
            Enabled = false,
            Reason = "Locked",
            Error = "Auto Scan is still locked.",
        }
    end

    if autoScanPlayers[userId] then
        sendAutoScanState(player, true)

        return {
            Success = true,
            Enabled = true,
        }
    end

    autoScanPlayers[userId] = true
    sendAutoScanState(player, true)

    task.spawn(function()
        while autoScanPlayers[userId] and player.Parent do
            local result = Shared.RollAlien(player)

            if alienRollResultRemote then
                alienRollResultRemote:SendToPlayer(player, result)
            end

            if result.Success then
                sendAutoScanState(player, true)
                local currentAlienState = getAlienState(player)
                local waitSeconds = result.Cooldown

                if not waitSeconds then
                    waitSeconds = if currentAlienState then getCooldown(currentAlienState) else AlienConfig.BaseScanCooldown
                end

                task.wait(waitSeconds)
            elseif result.Reason == "Cooldown" then
                sendAutoScanState(player, true, "Cooldown")
                task.wait(math.max(result.CooldownRemaining or 0.25, 0.25))
            else
                autoScanPlayers[userId] = nil
                sendAutoScanState(player, false, result.Reason)
                break
            end
        end

        autoScanPlayers[userId] = nil
    end)

    return {
        Success = true,
        Enabled = true,
    }
end

function Shared.OnStart()
    local requestAlienRoll = Remotes.Server:Get("requestAlienRoll") :: Net.ServerListenerEvent
    local requestAutoScanToggle = Remotes.Server:Get("requestAutoScanToggle") :: Net.ServerListenerEvent
    alienRollResultRemote = Remotes.Server:Get("alienRollResult") :: Net.ServerSenderEvent
    autoScanStateRemote = Remotes.Server:Get("autoScanState") :: Net.ServerSenderEvent

    Players.PlayerRemoving:Connect(function(player: Player)
        nextScanTimes[player.UserId] = nil
        autoScanPlayers[player.UserId] = nil
    end)

    requestAlienRoll:Connect(function(player: Player)
        local result = Shared.RollAlien(player)

        alienRollResultRemote:SendToPlayer(player, result)
    end)

    requestAutoScanToggle:Connect(function(player: Player, enabled: boolean)
        Shared.SetAutoScan(player, enabled == true)
    end)
end

return Shared
