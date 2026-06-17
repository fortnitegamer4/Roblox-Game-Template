local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Sift = require(ReplicatedStorage.Packages.Sift)

local PlayerData = require(ReplicatedStorage.Configs.PlayerData)

type AliensProducer = Reflex.Producer<AliensState, AliensActions>

export type PlayerAlienState = {
    AlienInventory: PlayerData.AlienInventory,
    EquippedAliens: { string },
    AlienIndex: PlayerData.AlienIndex,
    HasUsedFreeScan: boolean,
    TotalScans: number,
    AutoScanUnlocked: boolean,
    LuckLevel: number,
    RollSpeedLevel: number,
    FuelIncomeLevel: number,
    ClaimedIndexRewards: { [string]: boolean },
    IndexFuelIncomeBonus: number,
    IndexLuckBonus: number,
    IndexRollSpeedBonus: number,
}

export type AliensState = {
    [string]: PlayerAlienState
}

export type AliensActions = {
    loadPlayerData: (playerId: string, data: PlayerData.PlayerData) -> (),
    closePlayerData: (playerId: string) -> (),
    addAlien: (playerId: string, alien: PlayerData.OwnedAlien) -> (),
    incrementUpgradeLevel: (playerId: string, upgradeId: string) -> (),
    markFreeScanUsed: (playerId: string) -> (),
    incrementTotalScans: (playerId: string) -> (),
    setAutoScanUnlocked: (playerId: string, unlocked: boolean) -> (),
    claimIndexReward: (playerId: string, rewardId: string) -> (),
    addIndexFuelIncomeBonus: (playerId: string, amount: number) -> (),
    addIndexLuckBonus: (playerId: string, amount: number) -> (),
    addIndexRollSpeedBonus: (playerId: string, amount: number) -> (),
    removeAlien: (playerId: string, uid: string) -> (),
    setAlienLocked: (playerId: string, uid: string, locked: boolean) -> (),
    setEquippedAliens: (playerId: string, equippedAliens: { string }) -> (),
    setRollSpeedLevel: (playerId: string, level: number) -> (),
}

local function getData(data: PlayerData.PlayerData): PlayerAlienState
    return {
        AlienInventory = data.AlienInventory or {},
        EquippedAliens = data.EquippedAliens or {},
        AlienIndex = data.AlienIndex or {},
        HasUsedFreeScan = data.HasUsedFreeScan or false,
        TotalScans = data.TotalScans or 0,
        AutoScanUnlocked = data.AutoScanUnlocked or false,
        LuckLevel = data.LuckLevel or 0,
        RollSpeedLevel = data.RollSpeedLevel or 0,
        FuelIncomeLevel = data.FuelIncomeLevel or 0,
        ClaimedIndexRewards = data.ClaimedIndexRewards or {},
        IndexFuelIncomeBonus = data.IndexFuelIncomeBonus or 0,
        IndexLuckBonus = data.IndexLuckBonus or 0,
        IndexRollSpeedBonus = data.IndexRollSpeedBonus or 0,
    }
end

local aliensSlice: AliensProducer = Reflex.createProducer({}, {
    loadPlayerData = function(state, playerId: string, data: PlayerData.PlayerData)
        return Sift.Dictionary.set(state, playerId, getData(data))
    end,

    closePlayerData = function(state, playerId: string)
        return Sift.Dictionary.removeKey(state, playerId)
    end,

    addAlien = function(state, playerId: string, alien: PlayerData.OwnedAlien)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            local inventory = Sift.Dictionary.set(playerAliens.AlienInventory, alien.UID, alien)
            local index = Sift.Dictionary.set(playerAliens.AlienIndex, alien.AlienId, true)

            return Sift.Dictionary.merge(playerAliens, {
                AlienInventory = inventory,
                AlienIndex = index,
            })
        end)
    end,

    incrementUpgradeLevel = function(state, playerId: string, upgradeId: string)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            local currentLevel = playerAliens[upgradeId]
            if typeof(currentLevel) ~= "number" then
                return playerAliens
            end

            return Sift.Dictionary.set(playerAliens, upgradeId, currentLevel + 1)
        end)
    end,

    markFreeScanUsed = function(state, playerId: string)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "HasUsedFreeScan", true)
        end)
    end,

    incrementTotalScans = function(state, playerId: string)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "TotalScans", (playerAliens.TotalScans or 0) + 1)
        end)
    end,

    setAutoScanUnlocked = function(state, playerId: string, unlocked: boolean)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "AutoScanUnlocked", unlocked)
        end)
    end,

    claimIndexReward = function(state, playerId: string, rewardId: string)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            local claimedRewards = Sift.Dictionary.set(playerAliens.ClaimedIndexRewards or {}, rewardId, true)

            return Sift.Dictionary.set(playerAliens, "ClaimedIndexRewards", claimedRewards)
        end)
    end,

    addIndexFuelIncomeBonus = function(state, playerId: string, amount: number)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "IndexFuelIncomeBonus", (playerAliens.IndexFuelIncomeBonus or 0) + amount)
        end)
    end,

    addIndexLuckBonus = function(state, playerId: string, amount: number)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "IndexLuckBonus", (playerAliens.IndexLuckBonus or 0) + amount)
        end)
    end,

    addIndexRollSpeedBonus = function(state, playerId: string, amount: number)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "IndexRollSpeedBonus", (playerAliens.IndexRollSpeedBonus or 0) + amount)
        end)
    end,

    removeAlien = function(state, playerId: string, uid: string)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            local inventory = Sift.Dictionary.removeKey(playerAliens.AlienInventory, uid)
            local equipped = {}

            for _, equippedUid in playerAliens.EquippedAliens do
                if equippedUid ~= uid then
                    table.insert(equipped, equippedUid)
                end
            end

            return Sift.Dictionary.merge(playerAliens, {
                AlienInventory = inventory,
                EquippedAliens = equipped,
            })
        end)
    end,

    setAlienLocked = function(state, playerId: string, uid: string, locked: boolean)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            local ownedAlien = playerAliens.AlienInventory[uid]
            if not ownedAlien then
                return playerAliens
            end

            local updatedAlien = Sift.Dictionary.set(ownedAlien, "Locked", locked)
            local inventory = Sift.Dictionary.set(playerAliens.AlienInventory, uid, updatedAlien)

            return Sift.Dictionary.set(playerAliens, "AlienInventory", inventory)
        end)
    end,

    setEquippedAliens = function(state, playerId: string, equippedAliens: { string })
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "EquippedAliens", equippedAliens)
        end)
    end,

    setRollSpeedLevel = function(state, playerId: string, level: number)
        return Sift.Dictionary.update(state, playerId, function(playerAliens: PlayerAlienState?)
            if not playerAliens then
                return
            end

            return Sift.Dictionary.set(playerAliens, "RollSpeedLevel", math.max(math.floor(level), 0))
        end)
    end,
})

return aliensSlice
