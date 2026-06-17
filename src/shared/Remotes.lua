local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

return Net.CreateDefinitions({
    alienRollResult = Net.Definitions.ServerToClientEvent(),
    broadcast = Net.Definitions.ServerToClientEvent(),
    requestAlienRoll = Net.Definitions.ClientToServerEvent(),
    requestEquipBestAliens = Net.Definitions.ClientToServerEvent(),
    requestUpgradePurchase = Net.Definitions.ClientToServerEvent(),
    start = Net.Definitions.ClientToServerEvent(),
    upgradePurchaseResult = Net.Definitions.ServerToClientEvent(),
    requestFuelTestGrant = Net.Definitions.ClientToServerEvent(),
})
