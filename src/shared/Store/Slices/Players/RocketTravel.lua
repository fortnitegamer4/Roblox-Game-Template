local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Sift = require(ReplicatedStorage.Packages.Sift)

local PlayerData = require(ReplicatedStorage.Configs.PlayerData)

type RocketTravelProducer = Reflex.Producer<RocketTravelState, RocketTravelActions>

export type PlayerRocketTravelState = {
    HighestHeight: number,
    TotalLaunches: number,
    LastLaunchHeight: number,
}

export type RocketTravelState = {
    [string]: PlayerRocketTravelState,
}

export type RocketTravelActions = {
    loadPlayerData: (playerId: string, data: PlayerData.PlayerData) -> (),
    closePlayerData: (playerId: string) -> (),
    completeRocketLaunch: (playerId: string, height: number) -> (),
}

local rocketTravelSlice: RocketTravelProducer = Reflex.createProducer({}, {
    loadPlayerData = function(state, playerId: string, data: PlayerData.PlayerData)
        return Sift.Dictionary.set(state, playerId, {
            HighestHeight = data.HighestHeight or 0,
            TotalLaunches = data.TotalLaunches or 0,
            LastLaunchHeight = data.LastLaunchHeight or 0,
        })
    end,

    closePlayerData = function(state, playerId: string)
        return Sift.Dictionary.removeKey(state, playerId)
    end,

    completeRocketLaunch = function(state, playerId: string, height: number)
        return Sift.Dictionary.update(state, playerId, function(travelState: PlayerRocketTravelState?)
            if not travelState then
                return
            end

            local safeHeight = math.max(math.floor(height), 0)

            return Sift.Dictionary.merge(travelState, {
                HighestHeight = math.max(travelState.HighestHeight, safeHeight),
                TotalLaunches = travelState.TotalLaunches + 1,
                LastLaunchHeight = safeHeight,
            })
        end)
    end,
})

return rocketTravelSlice
