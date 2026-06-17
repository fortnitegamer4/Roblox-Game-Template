local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AlienConfig = require(ReplicatedStorage.Configs.AlienConfig)
local UpgradeConfig = require(ReplicatedStorage.Configs.UpgradeConfig)
local GuiController = require(script.Parent.Parent.GuiController)
local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local Store = require(script.Parent.Parent.Parent.Store)
local Selectors = require(ReplicatedStorage.Store.Selectors)

local Player = Players.LocalPlayer

local Gui = GuiController.Guis.AlienCrew
local Frame = Gui.Frame
local ScannerContent = Frame.ScannerContent
local UpgradesContent = Frame.UpgradesContent

local Local = {}
local Shared = {}

local currentFuel = 0
local currentAlienState = nil
local currentCooldown = AlienConfig.BaseScanCooldown
local cooldownReadyAt = 0
local isScannerExpanded = true
local isUpgradesExpanded = true

local function getCrewPower(alienState): number
    if not alienState then
        return 0
    end

    local power = 0

    for _, uid in alienState.EquippedAliens do
        local ownedAlien = alienState.AlienInventory[uid]
        local definition = ownedAlien and AlienConfig.ById[ownedAlien.AlienId]

        if definition then
            power += definition.Power
        end
    end

    return power
end

local function formatNumber(value: number): string
    if value % 1 == 0 then
        return tostring(value)
    end

    return string.format("%.2f", value)
end

function Local.PlayRollPlaceholder()
    ScannerContent.RollButton.Text = "Scanning..."
    ScannerContent.Status.Text = "Scanning..."
    ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 230, 150)
    Frame.ScanSound:Play()

    local tween = TweenService:Create(
        Frame,
        TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
        { BackgroundTransparency = 0 }
    )

    tween:Play()
end

function Local.ShowRollResult(result)
    if not result.Success then
        ScannerContent.RollButton.Text = "Scan"
        ScannerContent.Status.Text = result.Error or "Scan failed."
        ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 130, 130)
        return
    end

    local definition = result.Definition

    ScannerContent.Latest.Text = `{definition.DisplayName}\n{definition.Rarity} | 1 in {definition.BaseOdds} | {definition.Power} Power`
    ScannerContent.RollButton.Text = "Scan"
    ScannerContent.Status.Text = "Scanner cooling down..."
    ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 230, 150)

    currentCooldown = result.Cooldown or currentCooldown
    cooldownReadyAt = os.clock() + currentCooldown
end

function Local.UpdateLayout()
    ScannerContent.Visible = isScannerExpanded
    UpgradesContent.Visible = isUpgradesExpanded

    local y = 10
    Frame.Scanner.Position = UDim2.fromOffset(14, y)
    y += 32

    if isScannerExpanded then
        ScannerContent.Position = UDim2.fromOffset(14, y)
        y += 208
    end

    Frame.Upgrades.Position = UDim2.fromOffset(14, y)
    y += 36

    if isUpgradesExpanded then
        UpgradesContent.Position = UDim2.fromOffset(14, y)
        y += 136
    end

    Frame.Size = UDim2.fromOffset(320, y + 14)
end

function Local.UpdateUpgradeRows()
    if not currentAlienState then
        return
    end

    for _, upgradeId in UpgradeConfig.Order do
        local row = UpgradesContent:FindFirstChild(upgradeId)
        local definition = UpgradeConfig.Upgrades[upgradeId]

        if row and definition then
            local level = currentAlienState[upgradeId] or 0
            local cost = UpgradeConfig.GetCost(upgradeId, level)

            row.Label.Text = definition.DisplayName

            if cost then
                row.Detail.Text = `Level {level}/{definition.MaxLevel} | Cost {cost}`
                row.Buy.Text = "Buy"
                row.Buy.Active = true
                row.Buy.AutoButtonColor = true
                row.Buy.BackgroundColor3 = if currentFuel >= cost then Color3.fromRGB(81, 190, 120) else Color3.fromRGB(95, 95, 105)
            else
                row.Detail.Text = `Level {level}/{definition.MaxLevel} | Maxed`
                row.Buy.Text = "Max"
                row.Buy.Active = false
                row.Buy.AutoButtonColor = false
                row.Buy.BackgroundColor3 = Color3.fromRGB(95, 95, 105)
            end
        end
    end
end

function Local.UpdateScanState()
    local remaining = math.max(cooldownReadyAt - os.clock(), 0)

    if remaining > 0 then
        ScannerContent.RollButton.Active = false
        ScannerContent.RollButton.AutoButtonColor = false
        ScannerContent.RollButton.Text = string.format("%.1fs", remaining)
        ScannerContent.Status.Text = `Cooldown: {string.format("%.1f", remaining)}s`
        ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 230, 150)
        return
    end

    ScannerContent.RollButton.Active = true
    ScannerContent.RollButton.AutoButtonColor = true
    ScannerContent.RollButton.Text = "Scan"

    if currentFuel < AlienConfig.ScanCost then
        ScannerContent.ScanCost.Text = `Scan Cost: {AlienConfig.ScanCost} Fuel`
        ScannerContent.Status.Text = `Need {AlienConfig.ScanCost} Fuel to scan`
        ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 130, 130)
    else
        ScannerContent.ScanCost.Text = `Scan Cost: {AlienConfig.ScanCost} Fuel`
        ScannerContent.Status.Text = "Scanner Ready"
        ScannerContent.Status.TextColor3 = Color3.fromRGB(170, 255, 190)
    end
end

function Local.ShowUpgradeResult(result)
    if result.Success then
        local definition = UpgradeConfig.Upgrades[result.UpgradeId]
        local displayName = if definition then definition.DisplayName else "Upgrade"

        ScannerContent.Status.Text = `{displayName} upgraded to level {result.Level}`
        ScannerContent.Status.TextColor3 = Color3.fromRGB(170, 255, 190)
        return
    end

    ScannerContent.Status.Text = result.Error or "Upgrade failed."
    ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 130, 130)
end

function Shared.OnStart()
    local requestAlienRoll = Remotes.Client:Get("requestAlienRoll") :: Net.ClientSenderEvent
    local requestEquipBestAliens = Remotes.Client:Get("requestEquipBestAliens") :: Net.ClientSenderEvent
    local requestUpgradePurchase = Remotes.Client:Get("requestUpgradePurchase") :: Net.ClientSenderEvent
    local alienRollResult = Remotes.Client:Get("alienRollResult") :: Net.ClientListenerEvent
    local upgradePurchaseResult = Remotes.Client:Get("upgradePurchaseResult") :: Net.ClientListenerEvent

    ScannerContent.ScanCost.Text = `Scan Cost: {AlienConfig.ScanCost} Fuel`
    Local.UpdateLayout()

    Store:subscribe(Selectors.SelectPlayerFuel(tostring(Player.UserId)), function(fuel)
        currentFuel = fuel or 0
        Local.UpdateScanState()
        Local.UpdateUpgradeRows()
    end)

    Store:subscribe(Selectors.SelectPlayerAliens(tostring(Player.UserId)), function(alienState)
        currentAlienState = alienState

        local crewPower = getCrewPower(alienState)
        local incomeLevel = if alienState then alienState.FuelIncomeLevel else 0
        local rollSpeedLevel = if alienState then alienState.RollSpeedLevel else 0
        local fuelPerTick = crewPower * AlienConfig.FuelPerPowerPerTick * (1 + incomeLevel * AlienConfig.FuelIncomePerLevel)
        local fuelPerSecond = fuelPerTick / AlienConfig.PassiveFuelTickSeconds

        currentCooldown = AlienConfig.GetScanCooldown(rollSpeedLevel)
        ScannerContent.CrewPower.Text = `Crew Power: {crewPower}`
        ScannerContent.FuelPerSecond.Text = `Fuel/sec: {formatNumber(fuelPerSecond)}`
        Local.UpdateScanState()
        Local.UpdateUpgradeRows()
    end)

    Frame.Scanner.Activated:Connect(function()
        isScannerExpanded = not isScannerExpanded
        Local.UpdateLayout()
    end)

    Frame.Upgrades.Activated:Connect(function()
        isUpgradesExpanded = not isUpgradesExpanded
        Local.UpdateLayout()
    end)

    ScannerContent.RollButton.Activated:Connect(function()
        if os.clock() < cooldownReadyAt then
            return
        end

        Local.PlayRollPlaceholder()
        requestAlienRoll:SendToServer()
    end)

    ScannerContent.EquipBestButton.Activated:Connect(function()
        requestEquipBestAliens:SendToServer()
    end)

    for _, upgradeId in UpgradeConfig.Order do
        local row = UpgradesContent:FindFirstChild(upgradeId)

        if row then
            row.Buy.Activated:Connect(function()
                requestUpgradePurchase:SendToServer(upgradeId)
            end)
        end
    end

    alienRollResult:Connect(Local.ShowRollResult)
    upgradePurchaseResult:Connect(Local.ShowUpgradeResult)

    task.spawn(function()
        while true do
            Local.UpdateScanState()
            task.wait(0.1)
        end
    end)
end

return Shared
