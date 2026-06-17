local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local Store = require(ServerScriptService.Store)
local Selectors = require(ReplicatedStorage.Store.Selectors)

local TEST_GRANT_AMOUNT = 100

local Local = {}
local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

function Local.IsValidAmount(amount: number): boolean
    return typeof(amount) == "number" and amount > 0 and amount == amount and amount < math.huge
end

function Local.IsDataLoaded(player: Player): boolean
    return Store:getState().players.fuel[getPlayerId(player)] ~= nil
end

function Shared.GetFuel(player: Player): number?
    return Store:getState().players.fuel[getPlayerId(player)]
end

function Shared.CanAfford(player: Player, amount: number): boolean
    if not Local.IsValidAmount(amount) then
        return false
    end

    local fuel = Shared.GetFuel(player)
    return fuel ~= nil and fuel >= amount
end

-- Future server systems such as pickups, rewards, quests, shops, and rocket
-- upgrades should call FuelService.AddFuel/RemoveFuel instead of mutating the
-- store directly. That keeps validation and save-state behavior in one place.
function Shared.AddFuel(player: Player, amount: number): boolean
    if not Local.IsValidAmount(amount) or not Local.IsDataLoaded(player) then
        return false
    end

    Store.addFuel(getPlayerId(player), amount)
    return true
end

function Shared.RemoveFuel(player: Player, amount: number): boolean
    if not Local.IsValidAmount(amount) or not Shared.CanAfford(player, amount) then
        return false
    end

    Store.removeFuel(getPlayerId(player), amount)
    return true
end

function Shared.OnStart()
    if not RunService:IsStudio() then
        return
    end

    local requestFuelTestGrant = Remotes.Server:Get("requestFuelTestGrant") :: Net.ServerListenerEvent

    requestFuelTestGrant:Connect(function(player: Player)
        Shared.AddFuel(player, TEST_GRANT_AMOUNT)
    end)
end

return Shared
