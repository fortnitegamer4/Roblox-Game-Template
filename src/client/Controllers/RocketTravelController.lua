local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
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

local Local = {}
local Shared = {}

local active = false
local returning = false
local inputDirection = Vector2.zero
local rocketPosition = Vector3.zero
local rocketVelocity = Vector3.zero
local rocketRotation = CFrame.identity
local rocketPart = nil
local rocketModel = nil
local cameraFocusPart = nil
local arenaFolder = nil
local renderConnection = nil
local previousCameraType = nil
local previousCameraSubject = nil
local previousCameraFieldOfView = nil
local previousCameraMode = nil
local previousMinZoomDistance = nil
local previousMaxZoomDistance = nil
local previousCharacterState = nil
local previousGuiEnabled = nil
local previousLighting = nil
local startedLocallyAt = 0
local runFuel = 0
local hitsRemaining = RocketTravelConfig.MaxHitsBeforeCrash
local entities = {}
local requestRocketTravelAction = nil
local positionSendAccumulator = 0
local cameraShakeRemaining = 0
local heldDirections = {
    Up = false,
    Down = false,
    Left = false,
    Right = false,
}

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

local function makeVisualPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material, cframe: CFrame)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = size
    part.Color = color
    part.Material = material
    part.CFrame = cframe
    part.Parent = parent

    return part
end

local function createRocket()
    rocketModel = Instance.new("Model")
    rocketModel.Name = "Rocket"
    rocketModel.Parent = arenaFolder

    rocketPart = makeVisualPart(
        rocketModel,
        "Body",
        Vector3.new(3.2, 6.2, 2.8),
        Color3.fromRGB(244, 248, 255),
        Enum.Material.Metal,
        CFrame.new(ARENA_ORIGIN)
    )
    rocketModel.PrimaryPart = rocketPart

    local nose = makeVisualPart(
        rocketModel,
        "Nose",
        Vector3.new(2.8, 2.8, 2.5),
        Color3.fromRGB(255, 78, 64),
        Enum.Material.SmoothPlastic,
        CFrame.new(ARENA_ORIGIN + Vector3.new(0, 3.7, 0))
    )
    nose.Shape = Enum.PartType.Ball

    local window = makeVisualPart(
        rocketModel,
        "Window",
        Vector3.new(1.5, 1.5, 0.35),
        Color3.fromRGB(76, 210, 255),
        Enum.Material.Neon,
        CFrame.new(ARENA_ORIGIN + Vector3.new(0, 1, 1.55))
    )
    window.Shape = Enum.PartType.Ball

    makeVisualPart(
        rocketModel,
        "LeftFin",
        Vector3.new(1.5, 2.8, 1),
        Color3.fromRGB(255, 78, 64),
        Enum.Material.SmoothPlastic,
        CFrame.new(ARENA_ORIGIN + Vector3.new(-2, -2, 0))
    )
    makeVisualPart(
        rocketModel,
        "RightFin",
        Vector3.new(1.5, 2.8, 1),
        Color3.fromRGB(255, 78, 64),
        Enum.Material.SmoothPlastic,
        CFrame.new(ARENA_ORIGIN + Vector3.new(2, -2, 0))
    )

    local flame = makeVisualPart(
        rocketModel,
        "Flame",
        Vector3.new(1.5, 3.2, 1.5),
        Color3.fromRGB(255, 154, 45),
        Enum.Material.Neon,
        CFrame.new(ARENA_ORIGIN + Vector3.new(0, -4.7, 0))
    )

    local flameAttachment = Instance.new("Attachment")
    flameAttachment.Parent = flame

    local flameEmitter = Instance.new("ParticleEmitter")
    flameEmitter.Name = "FlameEmitter"
    flameEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 245, 125), Color3.fromRGB(255, 85, 20))
    flameEmitter.LightEmission = 1
    flameEmitter.Lifetime = NumberRange.new(0.25, 0.45)
    flameEmitter.Rate = 45
    flameEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    flameEmitter.Speed = NumberRange.new(5, 8)
    flameEmitter.SpreadAngle = Vector2.new(12, 12)
    flameEmitter.Parent = flameAttachment

    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "HitSparks"
    sparks.Enabled = false
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 70, 35))
    sparks.LightEmission = 1
    sparks.Lifetime = NumberRange.new(0.2, 0.45)
    sparks.Rate = 0
    sparks.Size = NumberSequence.new(0.25)
    sparks.Speed = NumberRange.new(8, 14)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Parent = rocketPart

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.78
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.05
    highlight.Parent = rocketModel
end

local function createArena()
    local existing = Workspace:FindFirstChild("RocketTravelArena")
    local staleArena = Workspace:FindFirstChild("RocketTravelArenaClient", true)
    if staleArena then
        staleArena:Destroy()
    end

    arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "RocketTravelArenaClient"
    arenaFolder.Parent = existing or Workspace

    for _ = 1, 28 do
        local cloud = makeVisualPart(
            arenaFolder,
            "Cloud",
            Vector3.new(
                Random.new():NextNumber(5, 11),
                Random.new():NextNumber(1.2, 2.8),
                Random.new():NextNumber(2, 5)
            ),
            Color3.fromRGB(235, 248, 255),
            Enum.Material.SmoothPlastic,
            CFrame.new(
                ARENA_ORIGIN
                    + Vector3.new(
                        Random.new():NextNumber(-45, 45),
                        Random.new():NextNumber(-30, 35),
                        Random.new():NextNumber(-45, 45)
                    )
            )
        )
        cloud.Shape = Enum.PartType.Ball
        cloud.Transparency = Random.new():NextNumber(0.2, 0.55)
    end

    createRocket()

    cameraFocusPart = makeVisualPart(
        arenaFolder,
        "CameraFocus",
        Vector3.one,
        Color3.new(1, 1, 1),
        Enum.Material.SmoothPlastic,
        CFrame.new(ARENA_ORIGIN + Vector3.new(0, RocketTravelConfig.CameraHeight, 0))
    )
    cameraFocusPart.Transparency = 1
end

local function clearArena()
    table.clear(entities)
    if arenaFolder then
        arenaFolder:Destroy()
        arenaFolder = nil
    end
    rocketPart = nil
    rocketModel = nil
    cameraFocusPart = nil
end

local function setCameraForFlight(enabled: boolean)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if enabled then
        previousCameraType = camera.CameraType
        previousCameraSubject = camera.CameraSubject
        previousCameraFieldOfView = camera.FieldOfView
        previousCameraMode = Player.CameraMode
        previousMinZoomDistance = Player.CameraMinZoomDistance
        previousMaxZoomDistance = Player.CameraMaxZoomDistance

        Player.CameraMode = Enum.CameraMode.Classic
        Player.CameraMinZoomDistance = RocketTravelConfig.CameraDistance * 0.75
        Player.CameraMaxZoomDistance = RocketTravelConfig.CameraDistance * 1.4
        camera.CameraSubject = cameraFocusPart
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = RocketTravelConfig.CameraFieldOfView
        camera.CFrame = CFrame.lookAt(
            ARENA_ORIGIN
                + Vector3.new(
                    0,
                    RocketTravelConfig.CameraHeight,
                    RocketTravelConfig.CameraDistance
                ),
            cameraFocusPart.Position
        )
    else
        camera.CameraType = previousCameraType or Enum.CameraType.Custom
        local character = Player.Character
        local currentHumanoid = character and character:FindFirstChildOfClass("Humanoid")
        camera.CameraSubject = if previousCameraSubject and previousCameraSubject.Parent
            then previousCameraSubject
            else currentHumanoid
        camera.FieldOfView = previousCameraFieldOfView or 70
        Player.CameraMode = previousCameraMode or Enum.CameraMode.Classic
        Player.CameraMinZoomDistance = previousMinZoomDistance or 0.5
        Player.CameraMaxZoomDistance = previousMaxZoomDistance or 128
        previousCameraType = nil
        previousCameraSubject = nil
        previousCameraFieldOfView = nil
        previousCameraMode = nil
        previousMinZoomDistance = nil
        previousMaxZoomDistance = nil
    end
end

local function setLightingForFlight(enabled: boolean)
    if enabled then
        previousLighting = {
            Ambient = Lighting.Ambient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogColor = Lighting.FogColor,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Ambient = Color3.fromRGB(115, 145, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(145, 180, 215)
        Lighting.Brightness = 2.5
        Lighting.ClockTime = 13
        Lighting.FogColor = RocketTravelConfig.AtmosphereMiddleColor
        Lighting.FogStart = 120
        Lighting.FogEnd = 300
    elseif previousLighting then
        Lighting.Ambient = previousLighting.Ambient
        Lighting.Brightness = previousLighting.Brightness
        Lighting.ClockTime = previousLighting.ClockTime
        Lighting.FogColor = previousLighting.FogColor
        Lighting.FogEnd = previousLighting.FogEnd
        Lighting.FogStart = previousLighting.FogStart
        Lighting.OutdoorAmbient = previousLighting.OutdoorAmbient
        previousLighting = nil
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
    local pressed = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
    local keyCode = inputObject.KeyCode

    if keyCode == Enum.KeyCode.W or keyCode == Enum.KeyCode.Up then
        heldDirections.Up = pressed
    elseif keyCode == Enum.KeyCode.S or keyCode == Enum.KeyCode.Down then
        heldDirections.Down = pressed
    elseif keyCode == Enum.KeyCode.A or keyCode == Enum.KeyCode.Left then
        heldDirections.Left = pressed
    elseif keyCode == Enum.KeyCode.D or keyCode == Enum.KeyCode.Right then
        heldDirections.Right = pressed
    end

    inputDirection = Vector2.new(
        (if heldDirections.Right then 1 else 0) - (if heldDirections.Left then 1 else 0),
        (if heldDirections.Up then 1 else 0) - (if heldDirections.Down then 1 else 0)
    )

    return Enum.ContextActionResult.Sink
end

local function spawnVisual(entity)
    if not active or entities[entity.Id] then
        return
    end

    local isFuelOrb = entity.Kind == "FuelOrb"
    local radius = if isFuelOrb then RocketTravelConfig.FuelOrbRadius else RocketTravelConfig.AsteroidRadius
    local part = makeVisualPart(
        arenaFolder,
        entity.Kind,
        Vector3.one * radius * 2,
        if isFuelOrb then Color3.fromRGB(60, 255, 160) else Color3.fromRGB(181, 104, 55),
        if isFuelOrb then Enum.Material.Neon else Enum.Material.Slate,
        CFrame.new(
            ARENA_ORIGIN
                + Vector3.new(
                    entity.X,
                    RocketTravelConfig.FlightBounds.MaxY + RocketTravelConfig.EntitySpawnOffsetY,
                    entity.Z
                )
        )
    )
    part.Shape = if isFuelOrb then Enum.PartType.Ball else Enum.PartType.Block

    local highlight = Instance.new("Highlight")
    highlight.FillColor = if isFuelOrb then Color3.fromRGB(105, 255, 190) else Color3.fromRGB(255, 166, 75)
    highlight.FillTransparency = if isFuelOrb then 0.45 else 0.72
    highlight.OutlineColor = if isFuelOrb then Color3.fromRGB(220, 255, 235) else Color3.fromRGB(255, 210, 125)
    highlight.OutlineTransparency = 0.05
    highlight.Parent = part

    local light = Instance.new("PointLight")
    light.Color = highlight.OutlineColor
    light.Brightness = if isFuelOrb then 2.5 else 1.2
    light.Range = if isFuelOrb then 12 else 8
    light.Parent = part

    entities[entity.Id] = {
        Part = part,
        Kind = entity.Kind,
        Speed = entity.Speed,
        ContactSent = false,
        Rotation = Vector3.new(
            Random.new():NextNumber(-2.2, 2.2),
            Random.new():NextNumber(-2.2, 2.2),
            Random.new():NextNumber(-2.2, 2.2)
        ),
    }
end

local function getCameraRelativeMoveDirection(): Vector3
    local camera = Workspace.CurrentCamera
    if not camera then
        return Vector3.zero
    end

    local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

    if forward.Magnitude < 0.01 then
        forward = Vector3.new(0, 0, -1)
    else
        forward = forward.Unit
    end

    if right.Magnitude < 0.01 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end

    local direction = right * inputDirection.X + forward * inputDirection.Y

    return if direction.Magnitude > 1 then direction.Unit else direction
end

local function moveVelocityToward(current: Vector3, target: Vector3, maxDelta: number): Vector3
    local delta = target - current
    if delta.Magnitude <= maxDelta then
        return target
    end

    return current + delta.Unit * maxDelta
end

local function updateFlight(deltaTime: number)
    if not active or not rocketPart then
        return
    end

    local moveDirection = getCameraRelativeMoveDirection()

    if moveDirection.Magnitude > 0 then
        local targetVelocity = moveDirection.Unit * RocketTravelConfig.MaxMoveSpeed
        rocketVelocity = moveVelocityToward(
            rocketVelocity,
            targetVelocity,
            RocketTravelConfig.MoveAcceleration * deltaTime
        )
    else
        rocketVelocity *= math.exp(-RocketTravelConfig.Drag * deltaTime)
        if rocketVelocity.Magnitude < 0.05 then
            rocketVelocity = Vector3.zero
        end
    end

    rocketPosition += rocketVelocity * deltaTime

    local bounds = RocketTravelConfig.FlightBounds
    local clampedPosition = Vector3.new(
        math.clamp(rocketPosition.X, bounds.MinX, bounds.MaxX),
        math.clamp(rocketPosition.Y, bounds.MinY, bounds.MaxY),
        math.clamp(rocketPosition.Z, bounds.MinZ, bounds.MaxZ)
    )

    if clampedPosition.X ~= rocketPosition.X then
        rocketVelocity = Vector3.new(0, rocketVelocity.Y, rocketVelocity.Z)
    end
    if clampedPosition.Y ~= rocketPosition.Y then
        rocketVelocity = Vector3.new(rocketVelocity.X, 0, rocketVelocity.Z)
    end
    if clampedPosition.Z ~= rocketPosition.Z then
        rocketVelocity = Vector3.new(rocketVelocity.X, rocketVelocity.Y, 0)
    end
    rocketPosition = clampedPosition

    local targetRotation = CFrame.identity
    if moveDirection.Magnitude > 0.01 then
        local tiltAxis = Vector3.yAxis:Cross(moveDirection)
        if tiltAxis.Magnitude > 0.01 then
            targetRotation = CFrame.fromAxisAngle(
                tiltAxis.Unit,
                math.rad(RocketTravelConfig.TiltAngleDegrees) * math.min(inputDirection.Magnitude, 1)
            )
        end
    end

    local tiltAlpha = 1 - math.exp(-RocketTravelConfig.TiltSmoothing * deltaTime)
    rocketRotation = rocketRotation:Lerp(targetRotation, tiltAlpha)

    local rocketWorldPosition = ARENA_ORIGIN + rocketPosition
    local rocketCFrame = CFrame.new(rocketWorldPosition) * rocketRotation
    rocketModel:PivotTo(rocketCFrame)
    cameraFocusPart.CFrame = CFrame.new(rocketWorldPosition + Vector3.new(0, RocketTravelConfig.CameraHeight, 0))

    positionSendAccumulator += deltaTime
    if positionSendAccumulator >= 0.1 then
        positionSendAccumulator = 0
        requestRocketTravelAction:SendToServer(
            "Position",
            rocketPosition.X,
            rocketPosition.Y,
            rocketPosition.Z
        )
    end

    for _, backgroundPart in arenaFolder:GetChildren() do
        if backgroundPart.Name == "Cloud" then
            backgroundPart.Position -= Vector3.new(0, 8 * deltaTime, 0)
            if backgroundPart.Position.Y < ARENA_ORIGIN.Y - 32 then
                backgroundPart.Position += Vector3.new(0, 67, 0)
            end
        end
    end

    for entityId, entity in entities do
        local part = entity.Part
        if not part.Parent then
            entities[entityId] = nil
            continue
        end

        local rotation = entity.Rotation * deltaTime
        local nextPosition = part.Position - Vector3.new(0, entity.Speed * deltaTime, 0)
        part.CFrame = CFrame.new(nextPosition)
            * part.CFrame.Rotation
            * CFrame.Angles(rotation.X, rotation.Y, rotation.Z)

        local entityRadius = if entity.Kind == "FuelOrb"
            then RocketTravelConfig.FuelOrbRadius
            else RocketTravelConfig.AsteroidRadius
        local collisionRadius = RocketTravelConfig.RocketCollisionRadius + entityRadius
        local distance = (part.Position - rocketPart.Position).Magnitude

        if distance <= collisionRadius and not entity.ContactSent then
            entity.ContactSent = true
            requestRocketTravelAction:SendToServer(
                "Position",
                rocketPosition.X,
                rocketPosition.Y,
                rocketPosition.Z
            )
            requestRocketTravelAction:SendToServer("Contact", entityId)
            part:Destroy()
            entities[entityId] = nil
        elseif part.Position.Y < ARENA_ORIGIN.Y + bounds.MinY - 6 then
            part:Destroy()
            entities[entityId] = nil
        end
    end

    if cameraShakeRemaining > 0 then
        cameraShakeRemaining = math.max(cameraShakeRemaining - deltaTime, 0)
        local camera = Workspace.CurrentCamera
        if camera then
            local strength = cameraShakeRemaining * 0.75
            camera.CFrame *= CFrame.new(
                Random.new():NextNumber(-strength, strength),
                Random.new():NextNumber(-strength, strength),
                0
            )
        end
    end

    local height = math.floor((os.clock() - startedLocallyAt) * RocketTravelConfig.BaseHeightPerSecond)
    Content.Height.Text = `Height: {height}m`
end

local function beginFlight(result)
    active = true
    returning = false
    startedLocallyAt = os.clock()
    rocketPosition = Vector3.zero
    rocketVelocity = Vector3.zero
    rocketRotation = CFrame.identity
    heldDirections.Up = false
    heldDirections.Down = false
    heldDirections.Left = false
    heldDirections.Right = false
    runFuel = 0
    hitsRemaining = result.MaxHits or RocketTravelConfig.MaxHitsBeforeCrash
    positionSendAccumulator = 0

    createArena()
    setCharacterFlightState(true)
    setCameraForFlight(true)
    setLightingForFlight(true)
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
    table.clear(heldDirections)

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
        setLightingForFlight(false)
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
            cameraShakeRemaining = 0.35

            local sparks = rocketPart and rocketPart:FindFirstChild("HitSparks")
            if sparks and sparks:IsA("ParticleEmitter") then
                sparks:Emit(28)
            end

            Gui.HitFlash.BackgroundTransparency = 0.45
            TweenService:Create(Gui.HitFlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
        elseif update.Kind == "Collected" then
            runFuel = update.FuelCollected or runFuel
            Content.RunFuel.Text = `Fuel collected: {runFuel}`
            setStatus("+ Fuel collected", Color3.fromRGB(120, 255, 175))
        end
    end)

    launchEnded:Connect(function(result)
        if active then
            finishFlight(result)
        end
    end)
end

return Shared
