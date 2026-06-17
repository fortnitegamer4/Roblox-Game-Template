local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AlienConfig = require(ReplicatedStorage.Configs.AlienConfig)
local AlienEquipService = require(ServerScriptService.Services.AlienEquipService)
local FuelService = require(ServerScriptService.Services.FuelService)
local Store = require(ServerScriptService.Store)

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getFuelIncomeMultiplier(player: Player): number
    local alienState = Store:getState().players.aliens[getPlayerId(player)]
    local incomeLevel = if alienState then alienState.FuelIncomeLevel else 0

    return 1 + (incomeLevel * AlienConfig.FuelIncomePerLevel)
end

function Shared.GetFuelPerSecond(player: Player): number
    local crewPower = AlienEquipService.GetCrewPower(player)
    local fuelPerTick = crewPower * AlienConfig.FuelPerPowerPerTick * getFuelIncomeMultiplier(player)

    return fuelPerTick / AlienConfig.PassiveFuelTickSeconds
end

function Shared.OnStart()
    task.spawn(function()
        while true do
            task.wait(AlienConfig.PassiveFuelTickSeconds)

            for _, player in Players:GetPlayers() do
                local crewPower = AlienEquipService.GetCrewPower(player)

                if crewPower > 0 then
                    local amount = crewPower * AlienConfig.FuelPerPowerPerTick * getFuelIncomeMultiplier(player)
                    FuelService.AddFuel(player, amount)
                end
            end
        end
    end)
end

return Shared
