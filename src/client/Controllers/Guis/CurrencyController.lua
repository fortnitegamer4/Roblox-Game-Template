local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuiController = require(script.Parent.Parent.GuiController)
local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local Store = require(script.Parent.Parent.Parent.Store)
local Selectors = require(ReplicatedStorage.Store.Selectors)

local Player = Players.LocalPlayer

local Gui = GuiController.Guis.Fuel
local Frame = Gui.Frame

local Local = {}
local Shared = {}

function Shared.OnStart()
    local selector = Selectors.SelectPlayerFuel(tostring(Player.UserId))

    Store:subscribe(selector, function(fuel)
        Frame.Amount.Text = tostring(fuel or 0)
    end)

    Frame.TestGrant.Visible = RunService:IsStudio()

    if RunService:IsStudio() then
        local requestFuelTestGrant = Remotes.Client:Get("requestFuelTestGrant") :: Net.ClientSenderEvent

        Frame.TestGrant.Activated:Connect(function()
            requestFuelTestGrant:SendToServer()
        end)
    end
end

return Shared
