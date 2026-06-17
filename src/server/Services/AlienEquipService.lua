local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AlienConfig = require(ReplicatedStorage.Configs.AlienConfig)
local Store = require(ServerScriptService.Store)

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getAlienState(player: Player)
    return Store:getState().players.aliens[getPlayerId(player)]
end

local function makeResult(success: boolean, reason: string?, errorMessage: string?, uid: string?)
    return {
        Success = success,
        Reason = reason,
        Error = errorMessage,
        UID = uid,
    }
end

local function getOwnedAlien(player: Player, uid: string)
    local alienState = getAlienState(player)

    if not alienState or typeof(uid) ~= "string" then
        return nil, alienState
    end

    return alienState.AlienInventory[uid], alienState
end

function Shared.EquipAlien(player: Player, uid: string)
    local ownedAlien, alienState = getOwnedAlien(player, uid)
    if not ownedAlien then
        return makeResult(false, "NotOwned", "You do not own that alien.", uid)
    end

    local equipped = table.clone(alienState.EquippedAliens)

    if table.find(equipped, uid) then
        return makeResult(true, nil, nil, uid)
    end

    if #equipped >= AlienConfig.MaxEquipped then
        table.remove(equipped, 1)
    end

    table.insert(equipped, uid)
    Store.setEquippedAliens(getPlayerId(player), equipped)

    return makeResult(true, nil, nil, uid)
end

function Shared.UnequipAlien(player: Player, uid: string)
    local ownedAlien, alienState = getOwnedAlien(player, uid)
    if not ownedAlien then
        return makeResult(false, "NotOwned", "You do not own that alien.", uid)
    end

    local equipped = {}

    for _, equippedUid in alienState.EquippedAliens do
        if equippedUid ~= uid then
            table.insert(equipped, equippedUid)
        end
    end

    Store.setEquippedAliens(getPlayerId(player), equipped)

    return makeResult(true, nil, nil, uid)
end

function Shared.EquipBest(player: Player)
    local alienState = getAlienState(player)
    if not alienState then
        return makeResult(false, "DataNotLoaded", "Player data is still loading.")
    end

    local ownedAliens = {}

    for uid, ownedAlien in alienState.AlienInventory do
        local definition = AlienConfig.ById[ownedAlien.AlienId]

        if definition and not ownedAlien.Locked then
            table.insert(ownedAliens, {
                UID = uid,
                Power = definition.Power,
                RarityRank = AlienConfig.RarityOrder[definition.Rarity] or 0,
            })
        end
    end

    table.sort(ownedAliens, function(left, right)
        if left.Power == right.Power then
            return left.RarityRank > right.RarityRank
        end

        return left.Power > right.Power
    end)

    local equipped = {}

    for index = 1, math.min(#ownedAliens, AlienConfig.MaxEquipped) do
        table.insert(equipped, ownedAliens[index].UID)
    end

    Store.setEquippedAliens(getPlayerId(player), equipped)

    return makeResult(true)
end

function Shared.LockAlien(player: Player, uid: string)
    local ownedAlien = getOwnedAlien(player, uid)
    if not ownedAlien then
        return makeResult(false, "NotOwned", "You do not own that alien.", uid)
    end

    Store.setAlienLocked(getPlayerId(player), uid, true)

    return makeResult(true, nil, nil, uid)
end

function Shared.UnlockAlien(player: Player, uid: string)
    local ownedAlien = getOwnedAlien(player, uid)
    if not ownedAlien then
        return makeResult(false, "NotOwned", "You do not own that alien.", uid)
    end

    Store.setAlienLocked(getPlayerId(player), uid, false)

    return makeResult(true, nil, nil, uid)
end

function Shared.DeleteAlien(player: Player, uid: string)
    local ownedAlien, alienState = getOwnedAlien(player, uid)
    if not ownedAlien then
        return makeResult(false, "NotOwned", "You do not own that alien.", uid)
    end

    if ownedAlien.Locked then
        return makeResult(false, "Locked", "Unlock this alien before deleting it.", uid)
    end

    if table.find(alienState.EquippedAliens, uid) then
        Shared.UnequipAlien(player, uid)
    end

    Store.removeAlien(getPlayerId(player), uid)

    return makeResult(true, nil, nil, uid)
end

function Shared.GetCrewPower(player: Player): number
    local alienState = getAlienState(player)
    if not alienState then
        return 0
    end

    local power = 0

    for _, uid in alienState.EquippedAliens do
        local ownedAlien = alienState.AlienInventory[uid]
        local definition = ownedAlien and AlienConfig.ById[ownedAlien.AlienId]

        if definition then
            power += definition.Power
        end
    end

    return power
end

return Shared
