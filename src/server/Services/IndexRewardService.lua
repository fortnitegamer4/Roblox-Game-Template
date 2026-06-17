local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)
local AlienConfig = require(ReplicatedStorage.Configs.AlienConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local Store = require(ServerScriptService.Store)

local Shared = {}

local function getPlayerId(player: Player): string
    return tostring(player.UserId)
end

local function getAlienState(player: Player)
    return Store:getState().players.aliens[getPlayerId(player)]
end

local function getDiscoveryCount(alienState): number
    local count = 0

    for _ in alienState.AlienIndex do
        count += 1
    end

    return count
end

local function meetsRequirement(alienState, reward): boolean
    local discoveryCount = getDiscoveryCount(alienState)

    if reward.RequiresAllEarth then
        return discoveryCount >= AlienConfig.GetEarthAlienCount()
    end

    return discoveryCount >= (reward.RequiredDiscoveries or 0)
end

function Shared.ClaimIndexReward(player: Player, rewardId: string)
    local alienState = getAlienState(player)
    if not alienState then
        return {
            Success = false,
            Reason = "DataNotLoaded",
            Error = "Player data is still loading.",
            RewardId = rewardId,
        }
    end

    local reward = AlienConfig.IndexRewards[rewardId]
    if not reward then
        return {
            Success = false,
            Reason = "InvalidReward",
            Error = "That index reward does not exist.",
            RewardId = rewardId,
        }
    end

    local claimedRewards = alienState.ClaimedIndexRewards or {}

    if claimedRewards[rewardId] then
        return {
            Success = false,
            Reason = "AlreadyClaimed",
            Error = "That index reward is already claimed.",
            RewardId = rewardId,
        }
    end

    if not meetsRequirement(alienState, reward) then
        return {
            Success = false,
            Reason = "Locked",
            Error = "Discover more aliens to claim this reward.",
            RewardId = rewardId,
        }
    end

    local bonus = reward.Reward

    if bonus.FuelIncomeBonus then
        Store.addIndexFuelIncomeBonus(getPlayerId(player), bonus.FuelIncomeBonus)
    end

    if bonus.LuckBonus then
        Store.addIndexLuckBonus(getPlayerId(player), bonus.LuckBonus)
    end

    if bonus.RollSpeedBonus then
        Store.addIndexRollSpeedBonus(getPlayerId(player), bonus.RollSpeedBonus)
    end

    Store.claimIndexReward(getPlayerId(player), rewardId)

    return {
        Success = true,
        RewardId = rewardId,
    }
end

function Shared.OnStart()
    local requestIndexRewardClaim = Remotes.Server:Get("requestIndexRewardClaim") :: Net.ServerListenerEvent
    local indexRewardResult = Remotes.Server:Get("indexRewardResult") :: Net.ServerSenderEvent

    requestIndexRewardClaim:Connect(function(player: Player, rewardId: string)
        indexRewardResult:SendToPlayer(player, Shared.ClaimIndexReward(player, rewardId))
    end)
end

return Shared
