local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Local = {}
local Shared = {}

function Local.CreateFuelGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Fuel"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(16, 16)
    frame.Size = UDim2.fromOffset(220, 56)
    frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 6)
    title.Size = UDim2.fromOffset(80, 18)
    title.Font = Enum.Font.GothamMedium
    title.Text = "Fuel"
    title.TextColor3 = Color3.fromRGB(170, 220, 255)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local amount = Instance.new("TextLabel")
    amount.Name = "Amount"
    amount.BackgroundTransparency = 1
    amount.Position = UDim2.fromOffset(12, 24)
    amount.Size = UDim2.fromOffset(120, 24)
    amount.Font = Enum.Font.GothamBold
    amount.Text = "0"
    amount.TextColor3 = Color3.fromRGB(255, 255, 255)
    amount.TextSize = 22
    amount.TextXAlignment = Enum.TextXAlignment.Left
    amount.Parent = frame

    local testGrant = Instance.new("TextButton")
    testGrant.Name = "TestGrant"
    testGrant.AnchorPoint = Vector2.new(1, 0.5)
    testGrant.Position = UDim2.new(1, -10, 0.5, 0)
    testGrant.Size = UDim2.fromOffset(72, 30)
    testGrant.BackgroundColor3 = Color3.fromRGB(44, 117, 255)
    testGrant.BorderSizePixel = 0
    testGrant.Font = Enum.Font.GothamMedium
    testGrant.Text = "+100"
    testGrant.TextColor3 = Color3.fromRGB(255, 255, 255)
    testGrant.TextSize = 14
    testGrant.Parent = frame

    gui.Parent = PlayerGui

    return gui
end

function Local.CreateAlienGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AlienCrew"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(16, 84)
    frame.Size = UDim2.fromOffset(320, 420)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local scannerHeader = Instance.new("TextButton")
    scannerHeader.Name = "Scanner"
    scannerHeader.BackgroundTransparency = 1
    scannerHeader.Position = UDim2.fromOffset(14, 10)
    scannerHeader.Size = UDim2.fromOffset(292, 26)
    scannerHeader.Font = Enum.Font.GothamBold
    scannerHeader.Text = "Scanner"
    scannerHeader.TextColor3 = Color3.fromRGB(180, 235, 255)
    scannerHeader.TextSize = 18
    scannerHeader.TextXAlignment = Enum.TextXAlignment.Left
    scannerHeader.Parent = frame

    local scannerContent = Instance.new("Frame")
    scannerContent.Name = "ScannerContent"
    scannerContent.BackgroundTransparency = 1
    scannerContent.Position = UDim2.fromOffset(14, 42)
    scannerContent.Size = UDim2.fromOffset(292, 196)
    scannerContent.Parent = frame

    local latest = Instance.new("TextLabel")
    latest.Name = "Latest"
    latest.BackgroundTransparency = 1
    latest.Position = UDim2.fromOffset(0, 0)
    latest.Size = UDim2.fromOffset(292, 50)
    latest.Font = Enum.Font.GothamMedium
    latest.Text = "No alien scanned yet"
    latest.TextColor3 = Color3.fromRGB(255, 255, 255)
    latest.TextSize = 15
    latest.TextWrapped = true
    latest.TextXAlignment = Enum.TextXAlignment.Left
    latest.TextYAlignment = Enum.TextYAlignment.Top
    latest.Parent = scannerContent

    local scanCost = Instance.new("TextLabel")
    scanCost.Name = "ScanCost"
    scanCost.BackgroundTransparency = 1
    scanCost.Position = UDim2.fromOffset(0, 50)
    scanCost.Size = UDim2.fromOffset(292, 20)
    scanCost.Font = Enum.Font.Gotham
    scanCost.Text = "Scan Cost: 0 Fuel"
    scanCost.TextColor3 = Color3.fromRGB(230, 240, 255)
    scanCost.TextSize = 14
    scanCost.TextXAlignment = Enum.TextXAlignment.Left
    scanCost.Parent = scannerContent

    local crewPower = Instance.new("TextLabel")
    crewPower.Name = "CrewPower"
    crewPower.BackgroundTransparency = 1
    crewPower.Position = UDim2.fromOffset(0, 74)
    crewPower.Size = UDim2.fromOffset(292, 20)
    crewPower.Font = Enum.Font.Gotham
    crewPower.Text = "Crew Power: 0"
    crewPower.TextColor3 = Color3.fromRGB(230, 240, 255)
    crewPower.TextSize = 14
    crewPower.TextXAlignment = Enum.TextXAlignment.Left
    crewPower.Parent = scannerContent

    local fuelPerSecond = Instance.new("TextLabel")
    fuelPerSecond.Name = "FuelPerSecond"
    fuelPerSecond.BackgroundTransparency = 1
    fuelPerSecond.Position = UDim2.fromOffset(0, 98)
    fuelPerSecond.Size = UDim2.fromOffset(292, 20)
    fuelPerSecond.Font = Enum.Font.Gotham
    fuelPerSecond.Text = "Fuel/sec: 0"
    fuelPerSecond.TextColor3 = Color3.fromRGB(230, 240, 255)
    fuelPerSecond.TextSize = 14
    fuelPerSecond.TextXAlignment = Enum.TextXAlignment.Left
    fuelPerSecond.Parent = scannerContent

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(0, 122)
    status.Size = UDim2.fromOffset(292, 20)
    status.Font = Enum.Font.GothamMedium
    status.Text = "Scanner Ready"
    status.TextColor3 = Color3.fromRGB(170, 255, 190)
    status.TextSize = 14
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = scannerContent

    local rollButton = Instance.new("TextButton")
    rollButton.Name = "RollButton"
    rollButton.Position = UDim2.fromOffset(0, 160)
    rollButton.Size = UDim2.fromOffset(118, 36)
    rollButton.BackgroundColor3 = Color3.fromRGB(49, 132, 255)
    rollButton.BorderSizePixel = 0
    rollButton.Font = Enum.Font.GothamBold
    rollButton.Text = "Scan"
    rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    rollButton.TextSize = 15
    rollButton.Parent = scannerContent

    local equipBestButton = Instance.new("TextButton")
    equipBestButton.Name = "EquipBestButton"
    equipBestButton.Position = UDim2.fromOffset(136, 160)
    equipBestButton.Size = UDim2.fromOffset(120, 36)
    equipBestButton.BackgroundColor3 = Color3.fromRGB(81, 190, 120)
    equipBestButton.BorderSizePixel = 0
    equipBestButton.Font = Enum.Font.GothamBold
    equipBestButton.Text = "Equip Best"
    equipBestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    equipBestButton.TextSize = 15
    equipBestButton.Parent = scannerContent

    local upgradesHeader = Instance.new("TextButton")
    upgradesHeader.Name = "Upgrades"
    upgradesHeader.BackgroundTransparency = 1
    upgradesHeader.Position = UDim2.fromOffset(14, 250)
    upgradesHeader.Size = UDim2.fromOffset(292, 26)
    upgradesHeader.Font = Enum.Font.GothamBold
    upgradesHeader.Text = "Upgrades"
    upgradesHeader.TextColor3 = Color3.fromRGB(180, 235, 255)
    upgradesHeader.TextSize = 18
    upgradesHeader.TextXAlignment = Enum.TextXAlignment.Left
    upgradesHeader.Parent = frame

    local upgrades = Instance.new("Frame")
    upgrades.Name = "UpgradesContent"
    upgrades.BackgroundTransparency = 1
    upgrades.Position = UDim2.fromOffset(14, 286)
    upgrades.Size = UDim2.fromOffset(292, 128)
    upgrades.Parent = frame

    local upgradeIds = {
        "LuckLevel",
        "RollSpeedLevel",
        "FuelIncomeLevel",
    }

    for index, upgradeId in upgradeIds do
        local row = Instance.new("Frame")
        row.Name = upgradeId
        row.BackgroundTransparency = 1
        row.Position = UDim2.fromOffset(0, (index - 1) * 42)
        row.Size = UDim2.fromOffset(292, 38)
        row.Parent = upgrades

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(0, 0)
        label.Size = UDim2.fromOffset(190, 18)
        label.Font = Enum.Font.GothamMedium
        label.Text = upgradeId
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local detail = Instance.new("TextLabel")
        detail.Name = "Detail"
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(0, 18)
        detail.Size = UDim2.fromOffset(190, 18)
        detail.Font = Enum.Font.Gotham
        detail.Text = "Level 0"
        detail.TextColor3 = Color3.fromRGB(210, 220, 235)
        detail.TextSize = 12
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.Parent = row

        local buy = Instance.new("TextButton")
        buy.Name = "Buy"
        buy.AnchorPoint = Vector2.new(1, 0.5)
        buy.Position = UDim2.new(1, 0, 0.5, 0)
        buy.Size = UDim2.fromOffset(88, 28)
        buy.BackgroundColor3 = Color3.fromRGB(81, 190, 120)
        buy.BorderSizePixel = 0
        buy.Font = Enum.Font.GothamBold
        buy.Text = "Buy"
        buy.TextColor3 = Color3.fromRGB(255, 255, 255)
        buy.TextSize = 12
        buy.Parent = row
    end

    local scanSound = Instance.new("Sound")
    scanSound.Name = "ScanSound"
    scanSound.Volume = 0.25
    scanSound.Parent = frame

    gui.Parent = PlayerGui

    return gui
end

Shared.Guis = {
    AlienCrew = PlayerGui:FindFirstChild("AlienCrew") or Local.CreateAlienGui(),
    Fuel = PlayerGui:FindFirstChild("Fuel") or Local.CreateFuelGui(),
}

return Shared
