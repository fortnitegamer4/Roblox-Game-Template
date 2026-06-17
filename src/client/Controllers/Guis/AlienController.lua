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
local IndexContent = Frame.IndexContent

local Local = {}
local Shared = {}

local currentFuel = 0
local currentAlienState = nil
local currentCooldown = AlienConfig.BaseScanCooldown
local cooldownReadyAt = 0
local autoScanEnabled = false
local lastAutoScanReason = nil
local isScannerExpanded = true
local isUpgradesExpanded = true
local isInventoryExpanded = false
local isIndexExpanded = false

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

local function getDiscoveryCount(alienState): number
    if not alienState then
        return 0
    end

    local count = 0

    for _ in alienState.AlienIndex do
        count += 1
    end

    return count
end

local function isIndexRewardUnlocked(alienState, reward): boolean
    if not alienState then
        return false
    end

    local discoveryCount = getDiscoveryCount(alienState)

    if reward.RequiresAllEarth then
        return discoveryCount >= AlienConfig.GetEarthAlienCount()
    end

    return discoveryCount >= (reward.RequiredDiscoveries or 0)
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
    IndexContent.Visible = isIndexExpanded

    local y = 10
    Frame.Scanner.Position = UDim2.fromOffset(14, y)
    y += 32

    if isScannerExpanded then
        ScannerContent.Position = UDim2.fromOffset(14, y)
        y += 256
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

    Frame.Index.Position = UDim2.fromOffset(14, y)
    y += 36

    if isIndexExpanded then
        IndexContent.Position = UDim2.fromOffset(14, y)
        y += 294
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

function Local.UpdateAutoScanUi()
    local totalScans = if currentAlienState then currentAlienState.TotalScans or 0 else 0
    local unlocked = currentAlienState
        and (currentAlienState.AutoScanUnlocked == true or totalScans >= AlienConfig.AutoScanUnlockScans)
    local progress = `{math.min(totalScans, AlienConfig.AutoScanUnlockScans)}/{AlienConfig.AutoScanUnlockScans} scans`

    if not unlocked then
        ScannerContent.AutoScanButton.Text = "Auto Scan: Locked"
        ScannerContent.AutoScanButton.Active = false
        ScannerContent.AutoScanButton.AutoButtonColor = false
        ScannerContent.AutoScanButton.BackgroundColor3 = Color3.fromRGB(95, 95, 105)
        ScannerContent.AutoScanStatus.Text = `Auto Scan Locked ({progress})`
        ScannerContent.AutoScanStatus.TextColor3 = Color3.fromRGB(230, 240, 255)
        return
    end

    ScannerContent.AutoScanButton.Active = true
    ScannerContent.AutoScanButton.AutoButtonColor = true
    ScannerContent.AutoScanButton.Text = if autoScanEnabled then "Auto Scan: ON" else "Auto Scan: OFF"
    ScannerContent.AutoScanButton.BackgroundColor3 = if autoScanEnabled then Color3.fromRGB(81, 190, 120) else Color3.fromRGB(49, 132, 255)

    if autoScanEnabled then
        ScannerContent.AutoScanStatus.Text = if lastAutoScanReason then `Auto Scan ON ({lastAutoScanReason})` else "Auto Scan ON"
        ScannerContent.AutoScanStatus.TextColor3 = Color3.fromRGB(170, 255, 190)
    elseif lastAutoScanReason and lastAutoScanReason ~= "Stopped" then
        ScannerContent.AutoScanStatus.Text = `Auto Scan stopped: {lastAutoScanReason}`
        ScannerContent.AutoScanStatus.TextColor3 = Color3.fromRGB(255, 130, 130)
    else
        ScannerContent.AutoScanStatus.Text = "Auto Scan Ready"
        ScannerContent.AutoScanStatus.TextColor3 = Color3.fromRGB(230, 240, 255)
    end
end

function Local.RenderIndex(requestIndexRewardClaim)
    local list = IndexContent.List
    local rewards = IndexContent.Rewards

    for _, child in list:GetChildren() do
        child:Destroy()
    end

    for _, child in rewards:GetChildren() do
        child:Destroy()
    end

    local discoveredCount = getDiscoveryCount(currentAlienState)
    IndexContent.Count.Text = `Discovered {discoveredCount}/{#AlienConfig.Aliens}`
    list.CanvasSize = UDim2.fromOffset(0, math.max(#AlienConfig.Aliens * 58, list.AbsoluteSize.Y))

    for index, definition in AlienConfig.Aliens do
        local alienIndex = if currentAlienState then currentAlienState.AlienIndex or {} else {}
        local discovered = alienIndex[definition.AlienId] == true
        local row = Instance.new("Frame")
        row.Name = definition.AlienId
        row.BackgroundColor3 = if discovered then Color3.fromRGB(18, 22, 32) else Color3.fromRGB(33, 35, 43)
        row.BackgroundTransparency = 0.12
        row.BorderSizePixel = 0
        row.Position = UDim2.fromOffset(0, (index - 1) * 58)
        row.Size = UDim2.fromOffset(284, 52)
        row.Parent = list

        local name = Instance.new("TextLabel")
        name.Name = "Name"
        name.BackgroundTransparency = 1
        name.Position = UDim2.fromOffset(8, 5)
        name.Size = UDim2.fromOffset(268, 18)
        name.Font = Enum.Font.GothamBold
        name.Text = if discovered then definition.DisplayName else "???"
        name.TextColor3 = if discovered then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(175, 180, 190)
        name.TextSize = 13
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Parent = row

        local powerText = if discovered then `{definition.Power} Power` else "Power ???"
        local detail = Instance.new("TextLabel")
        detail.Name = "Detail"
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(8, 25)
        detail.Size = UDim2.fromOffset(268, 20)
        detail.Font = Enum.Font.Gotham
        detail.Text = `{definition.Rarity} | 1 in {definition.BaseOdds} | {powerText}`
        detail.TextColor3 = Color3.fromRGB(210, 220, 235)
        detail.TextSize = 12
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.Parent = row
    end

    rewards.CanvasSize = UDim2.fromOffset(0, math.max(#AlienConfig.IndexRewardOrder * 52, rewards.AbsoluteSize.Y))

    for index, rewardId in AlienConfig.IndexRewardOrder do
        local reward = AlienConfig.IndexRewards[rewardId]
        local claimedRewards = if currentAlienState then currentAlienState.ClaimedIndexRewards or {} else {}
        local claimed = claimedRewards[rewardId] == true
        local unlocked = isIndexRewardUnlocked(currentAlienState, reward)
        local requirement = if reward.RequiresAllEarth then `Discover {AlienConfig.GetEarthAlienCount()} Earth aliens` else `Discover {reward.RequiredDiscoveries} aliens`

        local row = Instance.new("Frame")
        row.Name = rewardId
        row.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
        row.BackgroundTransparency = 0.12
        row.BorderSizePixel = 0
        row.Position = UDim2.fromOffset(0, (index - 1) * 52)
        row.Size = UDim2.fromOffset(284, 46)
        row.Parent = rewards

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(8, 4)
        label.Size = UDim2.fromOffset(166, 18)
        label.Font = Enum.Font.GothamBold
        label.Text = reward.DisplayName
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local detail = Instance.new("TextLabel")
        detail.Name = "Detail"
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(8, 22)
        detail.Size = UDim2.fromOffset(174, 20)
        detail.Font = Enum.Font.Gotham
        detail.Text = `{requirement} | {reward.Description}`
        detail.TextColor3 = Color3.fromRGB(210, 220, 235)
        detail.TextSize = 10
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextTruncate = Enum.TextTruncate.AtEnd
        detail.Parent = row

        local claim = Instance.new("TextButton")
        claim.Name = "Claim"
        claim.AnchorPoint = Vector2.new(1, 0.5)
        claim.Position = UDim2.new(1, -8, 0.5, 0)
        claim.Size = UDim2.fromOffset(84, 28)
        claim.BackgroundColor3 = if claimed then Color3.fromRGB(95, 95, 105) elseif unlocked then Color3.fromRGB(81, 190, 120) else Color3.fromRGB(95, 95, 105)
        claim.BorderSizePixel = 0
        claim.Font = Enum.Font.GothamBold
        claim.Text = if claimed then "Claimed" elseif unlocked then "Claim" else "Locked"
        claim.TextColor3 = Color3.fromRGB(255, 255, 255)
        claim.TextSize = 11
        claim.Active = unlocked and not claimed
        claim.AutoButtonColor = unlocked and not claimed
        claim.Parent = row

        claim.Activated:Connect(function()
            if unlocked and not claimed then
                requestIndexRewardClaim:SendToServer(rewardId)
            end
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
        Local.UpdateAutoScanUi()
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

    Local.UpdateAutoScanUi()
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
    local requestAutoScanToggle = Remotes.Client:Get("requestAutoScanToggle") :: Net.ClientSenderEvent
    local requestEquipBestAliens = Remotes.Client:Get("requestEquipBestAliens") :: Net.ClientSenderEvent
    local requestAlienInventoryAction = Remotes.Client:Get("requestAlienInventoryAction") :: Net.ClientSenderEvent
    local requestIndexRewardClaim = Remotes.Client:Get("requestIndexRewardClaim") :: Net.ClientSenderEvent
    local requestUpgradePurchase = Remotes.Client:Get("requestUpgradePurchase") :: Net.ClientSenderEvent
    local alienRollResult = Remotes.Client:Get("alienRollResult") :: Net.ClientListenerEvent
    local autoScanState = Remotes.Client:Get("autoScanState") :: Net.ClientListenerEvent
    local alienInventoryActionResult = Remotes.Client:Get("alienInventoryActionResult") :: Net.ClientListenerEvent
    local indexRewardResult = Remotes.Client:Get("indexRewardResult") :: Net.ClientListenerEvent
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
        local indexFuelIncomeBonus = if alienState then alienState.IndexFuelIncomeBonus or 0 else 0
        local indexRollSpeedBonus = if alienState then alienState.IndexRollSpeedBonus or 0 else 0
        local fuelPerTick = crewPower
            * AlienConfig.FuelPerPowerPerTick
            * (1 + incomeLevel * AlienConfig.FuelIncomePerLevel + indexFuelIncomeBonus)
        local fuelPerSecond = fuelPerTick / AlienConfig.PassiveFuelTickSeconds

        currentCooldown = AlienConfig.GetScanCooldown(rollSpeedLevel, indexRollSpeedBonus)
        ScannerContent.CrewPower.Text = `Crew Power: {crewPower}`
        ScannerContent.FuelPerSecond.Text = `Fuel/sec: {formatNumber(fuelPerSecond)}`
        Local.UpdateScanState()
        Local.UpdateUpgradeRows()
        Local.RenderInventory(requestAlienInventoryAction)
        Local.RenderIndex(requestIndexRewardClaim)
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

    Frame.Index.Activated:Connect(function()
        isIndexExpanded = not isIndexExpanded
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

    ScannerContent.AutoScanButton.Activated:Connect(function()
        if not currentAlienState then
            return
        end

        local totalScans = currentAlienState.TotalScans or 0
        local unlocked = currentAlienState.AutoScanUnlocked == true or totalScans >= AlienConfig.AutoScanUnlockScans

        if not unlocked then
            return
        end

        requestAutoScanToggle:SendToServer(not autoScanEnabled)
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
    autoScanState:Connect(function(result)
        autoScanEnabled = result.Enabled == true
        lastAutoScanReason = result.Reason
        Local.UpdateAutoScanUi()
    end)
    alienInventoryActionResult:Connect(function(result)
        if result.Success then
            ScannerContent.Status.Text = "Inventory updated"
            ScannerContent.Status.TextColor3 = Color3.fromRGB(170, 255, 190)
            return
        end

        ScannerContent.Status.Text = result.Error or "Inventory action failed."
        ScannerContent.Status.TextColor3 = Color3.fromRGB(255, 130, 130)
    end)
    indexRewardResult:Connect(function(result)
        if result.Success then
            ScannerContent.Status.Text = "Index reward claimed"
            ScannerContent.Status.TextColor3 = Color3.fromRGB(170, 255, 190)
            return
        end

        ScannerContent.Status.Text = result.Error or "Index reward failed."
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
