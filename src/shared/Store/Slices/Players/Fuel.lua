local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Sift = require(ReplicatedStorage.Packages.Sift)

local PlayerData = require(ReplicatedStorage.Configs.PlayerData)

type FuelProducer = Reflex.Producer<FuelState, FuelActions>

export type FuelState = {
    [string]: number
}

export type FuelActions = {
    loadPlayerData: (playerId: string, data: PlayerData.PlayerData) -> (),
    closePlayerData: (playerId: string) -> (),
    addFuel: (playerId: string, amount: number) -> (),
    removeFuel: (playerId: string, amount: number) -> (),
}

local initialState: FuelState = {}

local fuelSlice: FuelProducer = Reflex.createProducer(initialState, {
    loadPlayerData = function(state, playerId: string, data: PlayerData.PlayerData)
        return Sift.Dictionary.set(state, playerId, data.Fuel or 0)
    end,

    closePlayerData = function(state, playerId: string)
        return Sift.Dictionary.removeKey(state, playerId)
    end,

    addFuel = function(state, playerId: string, amount: number)
        return Sift.Dictionary.update(state, playerId, function(fuel: number?)
            if fuel == nil then
                return
            end

            return fuel + amount
        end)
    end,

    removeFuel = function(state, playerId: string, amount: number)
        return Sift.Dictionary.update(state, playerId, function(fuel: number?)
            if fuel == nil then
                return
            end

            return math.max(fuel - amount, 0)
        end)
    end,
})

return fuelSlice
