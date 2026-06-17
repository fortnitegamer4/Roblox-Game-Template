local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GuiController = require(script.Parent.GuiController)
local Net = require(ReplicatedStorage.Packages.Net)
local Remotes = require(ReplicatedStorage.Remotes)
local RocketTravelConfig = require(ReplicatedStorage.Configs.RocketTravelConfig)
local Store = require(script.Parent.Parent.Store)
local Selectors = require(ReplicatedStorage.Store.Selectors)

local Player = Players.LocalPlayer
local Gui = GuiController.Guis.RocketTravel
local Frame = Gui.Frame
local Content = Frame.Content

local ACTION_NAME = "RocketTravelMovement"
local ARENA_ORIGIN = Vector3.new(0, 80, 600)
local CAMERA_OFFSET = Vector3.new(0, 0, 55)

local Local = {}
local Shared = {}

local active = false
local returning = false
local inputDirection = Vector2.zero
local rocketPosition = Vector2.zero
local rocketPart = nil
local arenaFolder = nil
local renderConnection = nil
local previousCameraType = nil
local previousCameraSubject = nil
local previousCharacterState = nil
local previousGuiEnabled = nil
local startedLocallyAt = 0
local runFuel = 0
local hitsRemaining = RocketTravelConfig.MaxHitsBeforeCrash
local entities = {}
local requestRocketTravelAction = nil
local positionSendAccumulator = 0

local function setStatus(text: string, color: Color3?)
    Content.Status.Text = text
    Content.Status.TextColor3 = color or Color3.fromRGB(230, 240, 255)
end

local function setCharacterFlightState(enabled: boolean)
    local character = Player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoidRootPart or not humanoid then
        return
    end

    if enabled then
        previousCharacterState = {
            Anchored = humanoidRootPart.Anchored,
            AutoRotate = humanoid.AutoRotate,
        }
        humanoidRootPart.Anchored = true
        humanoid.AutoRotate = false
    elseif previousCharacterState then
        humanoidRootPart.Anchored = previousCharacterState.Anchored
        humanoid.AutoRotate = previousCharacterState.AutoRotate
        previousCharacterState = nil
    end
end

local function createArena()
    local existing = Workspace:FindFirstChild("RocketTravelArena")
    arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "RocketTravelArenaClient"
    arenaFolder.Parent = existing or Workspace

    local backdrop = Instance.new("Part")
    backdrop.Name = "Backdrop"
    backdrop.Anchored = true
    backdrop.CanCollide = false
    backdrop.Color = Color3.fromRGB(12, 22, 48)
    backdrop.Material = Enum.Material.SmoothPlastic
    backdrop.Size = Vector3.new(46, 32, 2)
    backdrop.CFrame = CFrame.new(ARENA_ORIGIN + Vector3.new(0, 0, 5))
    backdrop.Parent = arenaFolder

    for _ = 1, 24 do
        local star = Instance.new("Part")
        star.Name = "Star"
        star.Shape = Enum.PartType.Ball
        star.Anchored = true
        star.CanCollide = false
        star.Material = Enum.Material.Neon
        star.Color = Color3.fromRGB(210, 235, 255)
        star.Size = Vector3.one * Random.new():NextNumber(0.15, 0.45)
        star.Position = ARENA_ORIGIN
            + Vector3.new(
                Random.new():NextNumber(RocketTravelConfig.FlightBounds.MinX, RocketTravelConfig.FlightBounds.MaxX),
                Random.new():NextNumber(RocketTravelConfig.FlightBounds.MinY, RocketTravelConfig.FlightBounds.MaxY),
                2
            )
        star.Parent = arenaFolder
    end

    rocketPart = Instance.new("Part")
    rocketPart.Name = "Rocket"
    rocketPart.Anchored = true
    rocketPart.CanCollide = false
    rocketPart.Color = Color3.fromRGB(235, 240, 250)
    rocketPart.Material = Enum.Material.Metal
    rocketPart.Size = Vector3.new(2.4, 5.5, 2)
    rocketPart.CFrame = CFrame.new(ARENA_ORIGIN)
    rocketPart.Parent = arenaFolder

    local flame = Instance.new("Part")
    flame.Name = "Flame"
    flame.Anchored = true
    flame.CanCollide = false
    flame.Color = Color3.fromRGB(255, 150, 45)
    flame.Material = Enum.Material.Neon
    flame.Size = Vector3.new(1.2, 2.2, 1.2)
    flame.CFrame = rocketPart.CFrame * CFrame.new(0, -3.6, 0)
    flame.Parent = arenaFolder
end

local function clearArena()
    table.clear(entities)
    if arenaFolder then
        arenaFolder:Destroy()
        arenaFolder = nil
    end
    rocketPart = nil
end

local function setCameraForFlight(enabled: boolean)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if enabled then
        previousCameraType = camera.CameraType
        previousCameraSubject = camera.CameraSubject
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(ARENA_ORIGIN + CAMERA_OFFSET, ARENA_ORIGIN)
    else
        camera.CameraType = previousCameraType or Enum.CameraType.Custom
        local character = Player.Character
        local currentHumanoid = character and character:FindFirstChildOfClass("Humanoid")
        camera.CameraSubject = if previousCameraSubject and previousCameraSubject.Parent
            then previousCameraSubject
            else currentHumanoid
        previousCameraType = nil
        previousCameraSubject = nil
    end
end

local function setOtherGuisVisible(visible: boolean)
    local alienGui = GuiController.Guis.AlienCrew
    local fuelGui = GuiController.Guis.Fuel

    if not visible then
        previousGuiEnabled = {
            AlienCrew = alienGui.Enabled,
            Fuel = fuelGui.Enabled,
        }
        alienGui.Enabled = false
        fuelGui.Enabled = false
    elseif previousGuiEnabled then
        alienGui.Enabled = previousGuiEnabled.AlienCrew
        fuelGui.Enabled = previousGuiEnabled.Fuel
        previousGuiEnabled = nil
    end
end

local function movementAction(_, inputState: Enum.UserInputState, inputObject: InputObject)
    local value = if inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change then 1 else 0
    local keyCode = inputObject.KeyCode

    if keyCode == Enum.KeyCode.W or keyCode == Enum.KeyCode.Up then
        inputDirection = Vector2.new(inputDirection.X, value)
    elseif keyCode == Enum.KeyCode.S or keyCode == Enum.KeyCode.Down then
        inputDirection = Vector2.new(inputDirection.X, -value)
    elseif keyCode == Enum.KeyCode.A or keyCode == Enum.KeyCode.Left then
        inputDirection = Vector2.new(-value, inputDirection.Y)
    elseif keyCode == Enum.KeyCode.D or keyCode == Enum.KeyCode.Right then
        inputDirection = Vector2.new(value, inputDirection.Y)
    end

    return Enum.ContextActionResult.Sink
end

local function spawnVisual(entity)
    if not active or entities[entity.Id] then
        return
    end

    local part = Instance.new("Part")
    part.Name = entity.Kind
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Material = if entity.Kind == "FuelOrb" then Enum.Material.Neon else Enum.Material.Slate
    part.Color = if entity.Kind == "FuelOrb" then Color3.fromRGB(80, 255, 145) else Color3.fromRGB(105, 92, 100)
    local diameter = if entity.Kind == "FuelOrb" then RocketTravelConfig.FuelOrbRadius * 2 else RocketTravelConfig.AsteroidRadius * 2
    part.Size = Vector3.one * diameter
    part.Position = ARENA_ORIGIN + Vector3.new(entity.X, RocketTravelConfig.FlightBounds.MaxY + 5, 0)
    part.Parent = arenaFolder

    entities[entity.Id] = {
        Part = part,
        Kind = entity.Kind,
        Speed = entity.Speed,
        ContactSent = false,
    }
end

local function updateFlight(deltaTime: number)
    if not active or not rocketPart then
        return
    end

    local direction = if inputDirection.Magnitude > 1 then inputDirection.Unit else inputDirection
    rocketPosition += direction * RocketTravelConfig.RocketMoveSpeed * deltaTime

    local bounds = RocketTravelConfig.FlightBounds
    rocketPosition = Vector2.new(
        math.clamp(rocketPosition.X, bounds.MinX, bounds.MaxX),
        math.clamp(rocketPosition.Y, bounds.MinY, bounds.MaxY)
    )
    rocketPart.CFrame = CFrame.new(ARENA_ORIGIN + Vector3.new(rocketPosition.X, rocketPosition.Y, 0))

    positionSendAccumulator += deltaTime
    if positionSendAccumulator >= 0.1 then
        positionSendAccumulator = 0
        requestRocketTravelAction:SendToServer("Position", rocketPosition.X, rocketPosition.Y)
    end

    local flame = arenaFolder and arenaFolder:FindFirstChild("Flame")
    if flame then
        flame.CFrame = rocketPart.CFrame * CFrame.new(0, -3.6, 0)
    end

    for _, star in arenaFolder:GetChildren() do
        if star.Name == "Star" then
            star.Position -= Vector3.new(0, 10 * deltaTime, 0)
            if star.Position.Y < ARENA_ORIGIN.Y + bounds.MinY then
                star.Position += Vector3.new(0, bounds.MaxY - bounds.MinY, 0)
            end
        end
    end

    for entityId, entity in entities do
        local part = entity.Part
        if not part.Parent then
            entities[entityId] = nil
            continue
        end

        part.Position -= Vector3.new(0, entity.Speed * deltaTime, 0)

        local entityRadius = if entity.Kind == "FuelOrb"
            then RocketTravelConfig.FuelOrbRadius
            else RocketTravelConfig.AsteroidRadius
        local collisionRadius = RocketTravelConfig.RocketCollisionRadius + entityRadius
        local distance = (Vector2.new(part.Position.X, part.Position.Y) - Vector2.new(rocketPart.Position.X, rocketPart.Position.Y)).Magnitude

        if distance <= collisionRadius and not entity.ContactSent then
            entity.ContactSent = true
            requestRocketTravelAction:SendToServer("Position", rocketPosition.X, rocketPosition.Y)
            requestRocketTravelAction:SendToServer("Contact", entityId)
            part:Destroy()
            entities[entityId] = nil
        elseif part.Position.Y < ARENA_ORIGIN.Y + bounds.MinY - 6 then
            part:Destroy()
            entities[entityId] = nil
        end
    end

    local height = math.floor((os.clock() - startedLocallyAt) * RocketTravelConfig.BaseHeightPerSecond)
    Content.Height.Text = `Height: {height}m`
end

local function beginFlight(result)
    active = true
    returning = false
    startedLocallyAt = os.clock()
    rocketPosition = Vector2.zero
    runFuel = 0
    hitsRemaining = result.MaxHits or RocketTravelConfig.MaxHitsBeforeCrash
    positionSendAccumulator = 0

    createArena()
    setCharacterFlightState(true)
    setCameraForFlight(true)
    setOtherGuisVisible(false)

    ContextActionService:BindAction(
        ACTION_NAME,
        movementAction,
        false,
        Enum.KeyCode.W,
        Enum.KeyCode.A,
        Enum.KeyCode.S,
        Enum.KeyCode.D,
        Enum.KeyCode.Up,
        Enum.KeyCode.Left,
        Enum.KeyCode.Down,
        Enum.KeyCode.Right
    )

    Content.LaunchButton.Text = "Cancel"
    Content.Height.Text = "Height: 0m"
    Content.Hits.Text = `Hits remaining: {hitsRemaining}`
    Content.RunFuel.Text = "Fuel collected: 0"
    setStatus(`Launching through {result.ZoneName}`, Color3.fromRGB(170, 255, 190))

    renderConnection = RunService.RenderStepped:Connect(updateFlight)
end

local function finishFlight(result)
    active = false
    returning = true
    ContextActionService:UnbindAction(ACTION_NAME)
    inputDirection = Vector2.zero

    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end

    Content.LaunchButton.Text = "Returning..."
    Content.LaunchButton.Active = false
    Content.LaunchButton.AutoButtonColor = false
    Content.Height.Text = `Last height: {result.Height or 0}m`
    Content.RunFuel.Text = `Fuel collected: {result.FuelCollected or 0}`
    Content.Best.Text = `Best height: {result.HighestHeight or 0}m`

    local reason = result.Reason or "Ended"
    local bestText = if result.IsNewBest then " | New best!" else ""
    setStatus(`{reason}{bestText}`, if reason == "Crash" then Color3.fromRGB(255, 130, 130) else Color3.fromRGB(170, 255, 190))

    task.delay(RocketTravelConfig.EndRunReturnDelay, function()
        setCameraForFlight(false)
        setCharacterFlightState(false)
        setOtherGuisVisible(true)
        clearArena()

        returning = false
        Content.LaunchButton.Text = "Launch"
        Content.LaunchButton.Active = true
        Content.LaunchButton.AutoButtonColor = true
    end)
end

function Shared.OnStart()
    local requestStartLaunch = Remotes.Client:Get("requestStartLaunch") :: Net.ClientSenderEvent
    requestRocketTravelAction = Remotes.Client:Get("requestRocketTravelAction") :: Net.ClientSenderEvent
    local launchStarted = Remotes.Client:Get("launchStarted") :: Net.ClientListenerEvent
    local launchEnded = Remotes.Client:Get("launchEnded") :: Net.ClientListenerEvent
    local launchStateUpdate = Remotes.Client:Get("launchStateUpdate") :: Net.ClientListenerEvent

    Content.LaunchCost.Text = `Launch cost: {RocketTravelConfig.LaunchCostFuel} Fuel`

    Store:subscribe(Selectors.SelectPlayerRocketTravel(tostring(Player.UserId)), function(travelState)
        if travelState and not active then
            Content.Height.Text = `Last height: {travelState.LastLaunchHeight}m`
            Content.Best.Text = `Best height: {travelState.HighestHeight}m`
        end
    end)

    Frame.Header.Activated:Connect(function()
        Content.Visible = not Content.Visible
        Frame.Size = UDim2.fromOffset(270, if Content.Visible then 230 else 42)
    end)

    Content.LaunchButton.Activated:Connect(function()
        if returning then
            return
        end

        if active then
            requestRocketTravelAction:SendToServer("Cancel")
        else
            setStatus("Requesting launch...", Color3.fromRGB(255, 230, 150))
            requestStartLaunch:SendToServer()
        end
    end)

    launchStarted:Connect(function(result)
        if not result.Success then
            setStatus(result.Error or "Launch failed.", Color3.fromRGB(255, 130, 130))
            return
        end

        if not active then
            beginFlight(result)
        end
    end)

    launchStateUpdate:Connect(function(update)
        if not active then
            return
        end

        if update.Kind == "Spawn" then
            spawnVisual(update.Entity)
        elseif update.Kind == "Hit" then
            hitsRemaining = update.HitsRemaining or hitsRemaining
            Content.Hits.Text = `Hits remaining: {hitsRemaining}`
            TweenService:Create(Content, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
                BackgroundColor3 = Color3.fromRGB(110, 35, 40),
            }):Play()
        elseif update.Kind == "Collected" then
            runFuel = update.FuelCollected or runFuel
            Content.RunFuel.Text = `Fuel collected: {runFuel}`
        end
    end)

    launchEnded:Connect(function(result)
        if active then
            finishFlight(result)
        end
    end)
end

return Shared
