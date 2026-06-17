local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local FuelService = require(ServerScriptService.Services.FuelService)
local Remotes = require(ReplicatedStorage.Remotes)
local RocketTravelConfig = require(ReplicatedStorage.Configs.RocketTravelConfig)
local Store = require(ServerScriptService.Store)

type FlightEntity = {
    Id: string,
    Kind: string,
    X: number,
    SpawnedAt: number,
    Speed: number,
}

type ActiveLaunch = {
    StartedAt: number,
    Hits: number,
    FuelCollected: number,
    Entities: { [string]: FlightEntity },
    RocketPosition: Vector2,
    LastPositionAt: number,
    CharacterDiedConnection: RBXScriptConnection?,
    Ending: boolean?,
}

local activeLaunches: { [number]: ActiveLaunch } = {}
local launchStartedRemote = nil
local launchEndedRemote = nil
local launchStateUpdateRemote = nil

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getTravelState(player: Player)
    return Store:getState().players.rocketTravel[getPlayerId(player)]
end

local function getHeight(launch: ActiveLaunch): number
    local elapsed = math.min(os.clock() - launch.StartedAt, RocketTravelConfig.BaseLaunchDurationSeconds)

    return math.max(math.floor(elapsed * RocketTravelConfig.BaseHeightPerSecond), 0)
end

local function disconnectCharacterDied(launch: ActiveLaunch)
    if launch.CharacterDiedConnection then
        launch.CharacterDiedConnection:Disconnect()
        launch.CharacterDiedConnection = nil
    end
end

local function sendState(player: Player, payload)
    if launchStateUpdateRemote then
        launchStateUpdateRemote:SendToPlayer(player, payload)
    end
end

local function spawnEntity(player: Player, kind: string)
    local launch = activeLaunches[player.UserId]
    if not launch or launch.Ending then
        return
    end

    local bounds = RocketTravelConfig.FlightBounds
    local speed = if kind == "Asteroid" then RocketTravelConfig.ObstacleSpeed else RocketTravelConfig.FuelOrbSpeed
    local entity: FlightEntity = {
        Id = HttpService:GenerateGUID(false),
        Kind = kind,
        X = Random.new():NextNumber(bounds.MinX + 2, bounds.MaxX - 2),
        SpawnedAt = os.clock(),
        Speed = speed,
    }

    launch.Entities[entity.Id] = entity
    sendState(player, {
        Kind = "Spawn",
        Entity = entity,
    })

    task.delay((bounds.MaxY - bounds.MinY + 12) / speed, function()
        local currentLaunch = activeLaunches[player.UserId]
        if currentLaunch then
            currentLaunch.Entities[entity.Id] = nil
        end
    end)
end

local function getEntityPosition(entity: FlightEntity): Vector2?
    local bounds = RocketTravelConfig.FlightBounds
    local elapsed = os.clock() - entity.SpawnedAt
    local lifetime = (bounds.MaxY - bounds.MinY + 12) / entity.Speed

    if elapsed < 0 or elapsed > lifetime then
        return nil
    end

    return Vector2.new(entity.X, bounds.MaxY + 5 - entity.Speed * elapsed)
end

local function updateRocketPosition(player: Player, x: number, y: number)
    local launch = activeLaunches[player.UserId]
    if not launch or launch.Ending or typeof(x) ~= "number" or typeof(y) ~= "number" then
        return
    end

    if x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
        return
    end

    local bounds = RocketTravelConfig.FlightBounds
    if x < bounds.MinX or x > bounds.MaxX or y < bounds.MinY or y > bounds.MaxY then
        return
    end

    local now = os.clock()
    local elapsed = math.max(now - launch.LastPositionAt, 0)
    local maxDistance = RocketTravelConfig.RocketMoveSpeed * elapsed + 2.5
    local requestedPosition = Vector2.new(x, y)

    if (requestedPosition - launch.RocketPosition).Magnitude > maxDistance then
        return
    end

    launch.RocketPosition = requestedPosition
    launch.LastPositionAt = now
end

function Shared.UpdateHighestHeight(player: Player, height: number): boolean
    local travelState = getTravelState(player)
    if not travelState or typeof(height) ~= "number" or height ~= height or height == math.huge then
        return false
    end

    Store.completeRocketLaunch(getPlayerId(player), math.max(height, 0))
    return true
end

function Shared.StartLaunch(player: Player)
    if not getTravelState(player) or FuelService.GetFuel(player) == nil then
        return {
            Success = false,
            Reason = "DataNotLoaded",
            Error = "Player data is still loading.",
        }
    end

    if activeLaunches[player.UserId] then
        return {
            Success = false,
            Reason = "AlreadyLaunching",
            Error = "A rocket launch is already active.",
        }
    end

    if not FuelService.CanAfford(player, RocketTravelConfig.LaunchCostFuel) then
        return {
            Success = false,
            Reason = "NotEnoughFuel",
            Error = `Not enough Fuel. Need {RocketTravelConfig.LaunchCostFuel}.`,
            Cost = RocketTravelConfig.LaunchCostFuel,
        }
    end

    if not FuelService.RemoveFuel(player, RocketTravelConfig.LaunchCostFuel) then
        return {
            Success = false,
            Reason = "FuelSpendFailed",
            Error = "Unable to spend Fuel right now.",
        }
    end

    local launch: ActiveLaunch = {
        StartedAt = os.clock(),
        Hits = 0,
        FuelCollected = 0,
        Entities = {},
        RocketPosition = Vector2.zero,
        LastPositionAt = os.clock(),
    }
    activeLaunches[player.UserId] = launch

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        launch.CharacterDiedConnection = humanoid.Died:Connect(function()
            Shared.EndLaunch(player, "CharacterDied")
        end)
    end

    task.spawn(function()
        while activeLaunches[player.UserId] == launch and not launch.Ending do
            task.wait(RocketTravelConfig.ObstacleSpawnInterval)
            spawnEntity(player, "Asteroid")
        end
    end)

    task.spawn(function()
        while activeLaunches[player.UserId] == launch and not launch.Ending do
            task.wait(RocketTravelConfig.FuelOrbSpawnInterval)
            spawnEntity(player, "FuelOrb")
        end
    end)

    task.delay(RocketTravelConfig.BaseLaunchDurationSeconds, function()
        if activeLaunches[player.UserId] == launch then
            Shared.EndLaunch(player, "Completed")
        end
    end)

    return {
        Success = true,
        StartedAt = launch.StartedAt,
        Duration = RocketTravelConfig.BaseLaunchDurationSeconds,
        ZoneName = RocketTravelConfig.StartingZoneName,
        Cost = RocketTravelConfig.LaunchCostFuel,
        MaxHits = RocketTravelConfig.MaxHitsBeforeCrash,
    }
end

function Shared.EndLaunch(player: Player, reason: string)
    local launch = activeLaunches[player.UserId]
    if not launch or launch.Ending then
        return {
            Success = false,
            Reason = "NotLaunching",
        }
    end

    launch.Ending = true
    disconnectCharacterDied(launch)

    local height = getHeight(launch)
    local previousState = getTravelState(player)
    local previousBest = if previousState then previousState.HighestHeight else 0
    local reward = launch.FuelCollected

    if previousState then
        Shared.UpdateHighestHeight(player, height)
    end

    if reward > 0 then
        FuelService.AddFuel(player, reward)
    end

    activeLaunches[player.UserId] = nil

    local updatedState = getTravelState(player)
    local result = {
        Success = true,
        Reason = reason,
        Height = height,
        FuelCollected = reward,
        HighestHeight = if updatedState then updatedState.HighestHeight else math.max(previousBest, height),
        IsNewBest = height > previousBest,
    }

    if launchEndedRemote and player.Parent then
        launchEndedRemote:SendToPlayer(player, result)
    end

    return result
end

local function handleEntityContact(player: Player, entityId: string)
    local launch = activeLaunches[player.UserId]
    if not launch or launch.Ending or typeof(entityId) ~= "string" then
        return
    end

    local entity = launch.Entities[entityId]
    if not entity then
        return
    end

    local entityPosition = getEntityPosition(entity)
    if not entityPosition then
        return
    end

    local entityRadius = if entity.Kind == "FuelOrb"
        then RocketTravelConfig.FuelOrbRadius
        else RocketTravelConfig.AsteroidRadius
    local collisionRadius = RocketTravelConfig.RocketCollisionRadius + entityRadius + 1

    if (entityPosition - launch.RocketPosition).Magnitude > collisionRadius then
        return
    end

    launch.Entities[entityId] = nil

    if entity.Kind == "Asteroid" then
        launch.Hits += 1
        sendState(player, {
            Kind = "Hit",
            EntityId = entityId,
            Hits = launch.Hits,
            HitsRemaining = math.max(RocketTravelConfig.MaxHitsBeforeCrash - launch.Hits, 0),
        })

        if launch.Hits >= RocketTravelConfig.MaxHitsBeforeCrash then
            Shared.EndLaunch(player, "Crash")
        end
    elseif entity.Kind == "FuelOrb" then
        launch.FuelCollected += RocketTravelConfig.FuelOrbReward
        sendState(player, {
            Kind = "Collected",
            EntityId = entityId,
            FuelCollected = launch.FuelCollected,
        })
    end
end

function Shared.OnStart()
    local requestStartLaunch = Remotes.Server:Get("requestStartLaunch") :: Net.ServerListenerEvent
    local requestRocketTravelAction = Remotes.Server:Get("requestRocketTravelAction") :: Net.ServerListenerEvent
    launchStartedRemote = Remotes.Server:Get("launchStarted") :: Net.ServerSenderEvent
    launchEndedRemote = Remotes.Server:Get("launchEnded") :: Net.ServerSenderEvent
    launchStateUpdateRemote = Remotes.Server:Get("launchStateUpdate") :: Net.ServerSenderEvent

    requestStartLaunch:Connect(function(player: Player)
        launchStartedRemote:SendToPlayer(player, Shared.StartLaunch(player))
    end)

    requestRocketTravelAction:Connect(function(player: Player, action: string, value1, value2)
        if action == "Cancel" then
            Shared.EndLaunch(player, "Cancelled")
        elseif action == "Position" then
            updateRocketPosition(player, value1, value2)
        elseif action == "Contact" and typeof(value1) == "string" then
            handleEntityContact(player, value1)
        end
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        if activeLaunches[player.UserId] then
            Shared.EndLaunch(player, "PlayerLeft")
        end
    end)
end

return Shared
