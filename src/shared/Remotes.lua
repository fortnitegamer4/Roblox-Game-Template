local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

return Net.CreateDefinitions({
    alienRollResult = Net.Definitions.ServerToClientEvent(),
    broadcast = Net.Definitions.ServerToClientEvent(),
    requestAlienRoll = Net.Definitions.ClientToServerEvent(),
    requestEquipBestAliens = Net.Definitions.ClientToServerEvent(),
    start = Net.Definitions.ClientToServerEvent(),
    requestFuelTestGrant = Net.Definitions.ClientToServerEvent(),
})
