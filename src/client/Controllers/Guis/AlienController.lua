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
local InventoryContent = Frame.InventoryContent

local Local = {}
local Shared = {}

local currentFuel = 0
local currentAlienState = nil
local currentCooldown = AlienConfig.BaseScanCooldown
local cooldownReadyAt = 0
local isScannerExpanded = true
local isUpgradesExpanded = true
local isInventoryExpanded = true

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
    InventoryContent.Visible = isInventoryExpanded

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

    Frame.Inventory.Position = UDim2.fromOffset(14, y)
    y += 36

    if isInventoryExpanded then
        InventoryContent.Position = UDim2.fromOffset(14, y)
        y += 238
    end

    Frame.Size = UDim2.fromOffset(320, y + 14)
end

function Local.GetInventoryRows(alienState)
    local rows = {}
    if not alienState then
        return rows
    end

    local equippedSet = {}

    for _, uid in alienState.EquippedAliens do
        equippedSet[uid] = true
    end

    for uid, ownedAlien in alienState.AlienInventory do
        local definition = AlienConfig.ById[ownedAlien.AlienId]

        if definition then
            table.insert(rows, {
                UID = uid,
                Definition = definition,
                Equipped = equippedSet[uid] == true,
                Locked = ownedAlien.Locked == true,
            })
        end
    end

    table.sort(rows, function(left, right)
        if left.Equipped ~= right.Equipped then
            return left.Equipped
        end

        if left.Definition.Power == right.Definition.Power then
            return (AlienConfig.RarityOrder[left.Definition.Rarity] or 0) > (AlienConfig.RarityOrder[right.Definition.Rarity] or 0)
        end

        return left.Definition.Power > right.Definition.Power
    end)

    return rows
end

function Local.RenderInventory(requestAlienInventoryAction)
    local list = InventoryContent.List

    for _, child in list:GetChildren() do
        child:Destroy()
    end

    local rows = Local.GetInventoryRows(currentAlienState)
    InventoryContent.Count.Text = `{#rows}/{AlienConfig.MaxAlienInventory}`
    list.CanvasSize = UDim2.fromOffset(0, math.max(#rows * 88, list.AbsoluteSize.Y))

    for index, rowData in rows do
        local row = Instance.new("Frame")
        row.Name = rowData.UID
        row.BackgroundColor3 = if rowData.Equipped then Color3.fromRGB(27, 42, 52) else Color3.fromRGB(18, 22, 32)
        row.BackgroundTransparency = 0.15
        row.BorderSizePixel = 0
        row.Position = UDim2.fromOffset(0, (index - 1) * 88)
        row.Size = UDim2.fromOffset(284, 80)
        row.Parent = list

        local name = Instance.new("TextLabel")
        name.Name = "Name"
        name.BackgroundTransparency = 1
        name.Position = UDim2.fromOffset(8, 6)
        name.Size = UDim2.fromOffset(150, 18)
        name.Font = Enum.Font.GothamBold
        name.Text = rowData.Definition.DisplayName
        name.TextColor3 = Color3.fromRGB(255, 255, 255)
        name.TextSize = 13
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Parent = row

        local detail = Instance.new("TextLabel")
        detail.Name = "Detail"
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(8, 25)
        detail.Size = UDim2.fromOffset(164, 34)
        detail.Font = Enum.Font.Gotham
        detail.Text = `{rowData.Definition.Rarity} | 1 in {rowData.Definition.BaseOdds}\n{rowData.Definition.Power} Power`
        detail.TextColor3 = Color3.fromRGB(210, 220, 235)
        detail.TextSize = 12
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextYAlignment = Enum.TextYAlignment.Top
        detail.Parent = row

        local state = Instance.new("TextLabel")
        state.Name = "State"
        state.BackgroundTransparency = 1
        state.Position = UDim2.fromOffset(8, 58)
        state.Size = UDim2.fromOffset(164, 16)
        state.Font = Enum.Font.GothamMedium
        state.Text = `{if rowData.Equipped then "Equipped" else "Stored"} | {if rowData.Locked then "Locked" else "Unlocked"}`
        state.TextColor3 = if rowData.Locked then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(170, 255, 190)
        state.TextSize = 11
        state.TextXAlignment = Enum.TextXAlignment.Left
        state.Parent = row

        local equip = Instance.new("TextButton")
        equip.Name = "Equip"
        equip.Position = UDim2.fromOffset(180, 6)
        equip.Size = UDim2.fromOffset(96, 20)
        equip.BackgroundColor3 = Color3.fromRGB(49, 132, 255)
        equip.BorderSizePixel = 0
        equip.Font = Enum.Font.GothamBold
        equip.Text = if rowData.Equipped then "Unequip" else "Equip"
        equip.TextColor3 = Color3.fromRGB(255, 255, 255)
        equip.TextSize = 11
        equip.Parent = row

        local lock = Instance.new("TextButton")
        lock.Name = "Lock"
        lock.Position = UDim2.fromOffset(180, 30)
        lock.Size = UDim2.fromOffset(96, 20)
        lock.BackgroundColor3 = Color3.fromRGB(81, 190, 120)
        lock.BorderSizePixel = 0
        lock.Font = Enum.Font.GothamBold
        lock.Text = if rowData.Locked then "Unlock" else "Lock"
        lock.TextColor3 = Color3.fromRGB(255, 255, 255)
        lock.TextSize = 11
        lock.Parent = row

        local delete = Instance.new("TextButton")
        delete.Name = "Delete"
        delete.Position = UDim2.fromOffset(180, 54)
        delete.Size = UDim2.fromOffset(96, 20)
        delete.BackgroundColor3 = Color3.fromRGB(205, 72, 72)
        delete.BorderSizePixel = 0
        delete.Font = Enum.Font.GothamBold
        delete.Text = "Delete"
        delete.TextColor3 = Color3.fromRGB(255, 255, 255)
        delete.TextSize = 11
        delete.Parent = row

        local uid = rowData.UID

        equip.Activated:Connect(function()
            requestAlienInventoryAction:SendToServer(if rowData.Equipped then "Unequip" else "Equip", uid)
        end)

        lock.Activated:Connect(function()
            requestAlienInventoryAction:SendToServer(if rowData.Locked then "Unlock" else "Lock", uid)
        end)

        delete.Activated:Connect(function()
            requestAlienInventoryAction:SendToServer("Delete", uid)
        end)
    end
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
    local requestAlienInventoryAction = Remotes.Client:Get("requestAlienInventoryAction") :: Net.ClientSenderEvent
    local requestUpgradePurchase = Remotes.Client:Get("requestUpgradePurchase") :: Net.ClientSenderEvent
    local alienRollResult = Remotes.Client:Get("alienRollResult") :: Net.ClientListenerEvent
    local alienInventoryActionResult = Remotes.Client:Get("alienInventoryActionResult") :: Net.ClientListenerEvent
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
        Local.RenderInventory(requestAlienInventoryAction)
    end)

    Frame.Scanner.Activated:Connect(function()
        isScannerExpanded = not isScannerExpanded
        Local.UpdateLayout()
    end)

    Frame.Upgrades.Activated:Connect(function()
        isUpgradesExpanded = not isUpgradesExpanded
        Local.UpdateLayout()
    end)

    Frame.Inventory.Activated:Connect(function()
        isInventoryExpanded = not isInventoryExpanded
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

    InventoryContent.EquipBestButton.Activated:Connect(function()
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
    alienInventoryActionResult:Connect(function(result)
        if result.Success then
            ScannerContent.Status.Text = "Inventory updated"
            ScannerContent.Status.TextColor3 = Color3.fromRGB(170, 255, 190)
            return
        end

        ScannerContent.Status.Text = result.Error or "Inventory action failed."
        ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 130, 130)
    end)
    upgradePurchaseResult:Connect(Local.ShowUpgradeResult)

    task.spawn(function()
        while true do
            Local.UpdateScanState()
            task.wait(0.1)
        end
    end)
end

return Shared
