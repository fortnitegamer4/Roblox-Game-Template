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

local function ownsAlien(player: Player, uid: string): boolean
    local alienState = getAlienState(player)
    return alienState ~= nil and alienState.AlienInventory[uid] ~= nil
end

function Shared.EquipAlien(player: Player, uid: string): boolean
    if typeof(uid) ~= "string" or not ownsAlien(player, uid) then
        return false
    end

    local playerId = getPlayerId(player)
    local alienState = getAlienState(player)
    local equipped = table.clone(alienState.EquippedAliens)

    if table.find(equipped, uid) then
        return true
    end

    if #equipped >= AlienConfig.MaxEquipped then
        table.remove(equipped, 1)
    end

    table.insert(equipped, uid)
    Store.setEquippedAliens(playerId, equipped)

    return true
end

function Shared.UnequipAlien(player: Player, uid: string): boolean
    local alienState = getAlienState(player)
    if typeof(uid) ~= "string" or not alienState then
        return false
    end

    local equipped = {}

    for _, equippedUid in alienState.EquippedAliens do
        if equippedUid ~= uid then
            table.insert(equipped, equippedUid)
        end
    end

    Store.setEquippedAliens(getPlayerId(player), equipped)

    return true
end

function Shared.EquipBest(player: Player): boolean
    local alienState = getAlienState(player)
    if not alienState then
        return false
    end

    local ownedAliens = {}

    for uid, ownedAlien in alienState.AlienInventory do
        local definition = AlienConfig.ById[ownedAlien.AlienId]

        if definition then
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

    return true
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
