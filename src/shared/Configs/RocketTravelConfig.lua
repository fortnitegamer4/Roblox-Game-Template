local RocketTravelConfig = {
    LaunchCostFuel = 50,
    BaseLaunchDurationSeconds = 30,
    BaseHeightPerSecond = 25,
    FuelDrainPerSecond = 1,

    FlightBounds = {
        MinX = -18,
        MaxX = 18,
        MinY = -3,
        MaxY = 3,
        MinZ = -18,
        MaxZ = 18,
    },

    MoveAcceleration = 55,
    MaxMoveSpeed = 24,
    Drag = 5,
    TiltAngleDegrees = 16,
    TiltSmoothing = 8,
    CameraDistance = 32,
    CameraHeight = 3,
    CameraFieldOfView = 58,
    ObstacleSpawnInterval = 1.5,
    FuelOrbSpawnInterval = 2.5,
    ObstacleSpeed = 16,
    FuelOrbSpeed = 13,
    EntitySpawnOffsetY = 9,
    MaxHitsBeforeCrash = 3,
    EndRunReturnDelay = 2,
    StartingZoneName = "Atmosphere",

    FuelOrbReward = 5,
    AsteroidRadius = 2.8,
    FuelOrbRadius = 1.5,
    RocketCollisionRadius = 1.8,

    AtmosphereTopColor = Color3.fromRGB(42, 113, 196),
    AtmosphereMiddleColor = Color3.fromRGB(82, 168, 226),
    AtmosphereBottomColor = Color3.fromRGB(157, 222, 247),
}

return RocketTravelConfig
