local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)

local Slices = require(ReplicatedStorage.Store.Slices)
local PlayersSlice = require(ReplicatedStorage.Store.Slices.Players)

local function SelectPlayerFuel(playerId: string)
    return function(state: Slices.SharedState)
        return state.players.fuel[playerId]
    end
end

local function SelectPlayerAliens(playerId: string)
    return function(state: Slices.SharedState)
        return state.players.aliens[playerId]
    end
end

local function SelectPlayerData(playerId: string)
    return Reflex.createSelector(
        SelectPlayerFuel(playerId),
        SelectPlayerAliens(playerId),

        function(fuel: number?, aliens): PlayersSlice.PlayerData?
            if fuel == nil or not aliens then
                return
            end

            return {
                Fuel = fuel,
                AlienInventory = aliens.AlienInventory,
                EquippedAliens = aliens.EquippedAliens,
                AlienIndex = aliens.AlienIndex,
                HasUsedFreeScan = aliens.HasUsedFreeScan,
                TotalScans = aliens.TotalScans,
                AutoScanUnlocked = aliens.AutoScanUnlocked,
                LuckLevel = aliens.LuckLevel,
                RollSpeedLevel = aliens.RollSpeedLevel,
                FuelIncomeLevel = aliens.FuelIncomeLevel,
                ClaimedIndexRewards = aliens.ClaimedIndexRewards,
                IndexFuelIncomeBonus = aliens.IndexFuelIncomeBonus,
                IndexLuckBonus = aliens.IndexLuckBonus,
                IndexRollSpeedBonus = aliens.IndexRollSpeedBonus,
            }
        end
    )
end

return {
    SelectPlayerAliens = SelectPlayerAliens,
    SelectPlayerFuel = SelectPlayerFuel,
    SelectPlayerData = SelectPlayerData,
}
