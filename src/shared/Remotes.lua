local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

return Net.CreateDefinitions({
    alienRollResult = Net.Definitions.ServerToClientEvent(),
    autoScanState = Net.Definitions.ServerToClientEvent(),
    alienInventoryActionResult = Net.Definitions.ServerToClientEvent(),
    indexRewardResult = Net.Definitions.ServerToClientEvent(),
    broadcast = Net.Definitions.ServerToClientEvent(),
    requestAlienRoll = Net.Definitions.ClientToServerEvent(),
    requestAutoScanToggle = Net.Definitions.ClientToServerEvent(),
    requestEquipBestAliens = Net.Definitions.ClientToServerEvent(),
    requestAlienInventoryAction = Net.Definitions.ClientToServerEvent(),
    requestIndexRewardClaim = Net.Definitions.ClientToServerEvent(),
    requestUpgradePurchase = Net.Definitions.ClientToServerEvent(),
    start = Net.Definitions.ClientToServerEvent(),
    upgradePurchaseResult = Net.Definitions.ServerToClientEvent(),
    requestFuelTestGrant = Net.Definitions.ClientToServerEvent(),
    requestStartLaunch = Net.Definitions.ClientToServerEvent(),
    requestRocketTravelAction = Net.Definitions.ClientToServerEvent(),
    launchStarted = Net.Definitions.ServerToClientEvent(),
    launchEnded = Net.Definitions.ServerToClientEvent(),
    launchStateUpdate = Net.Definitions.ServerToClientEvent(),
})
