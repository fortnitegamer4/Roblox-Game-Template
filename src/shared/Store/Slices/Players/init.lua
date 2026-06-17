local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)

local PlayerData = require(ReplicatedStorage.Configs.PlayerData)
local Aliens = require(script.Aliens)
local Fuel = require(script.Fuel)

export type PlayerData = PlayerData.PlayerData

type PlayersProducer = Reflex.Producer<PlayersState, PlayersActions>

export type PlayersState = {
    aliens: Aliens.AliensState,
    fuel: Fuel.FuelState
}

export type PlayersActions = Aliens.AliensActions & Fuel.FuelActions

local playersSlice: PlayersProducer = Reflex.combineProducers({
    aliens = Aliens,
    fuel = Fuel,
})

return {
    playersSlice = playersSlice,
    template = PlayerData
}
