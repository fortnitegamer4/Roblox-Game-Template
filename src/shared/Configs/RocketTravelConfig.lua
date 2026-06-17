local RocketTravelConfig = {
    LaunchCostFuel = 50,
    BaseLaunchDurationSeconds = 30,
    BaseHeightPerSecond = 25,
    FuelDrainPerSecond = 1,

    FlightBounds = {
        MinX = -18,
        MaxX = 18,
        MinY = -11,
        MaxY = 11,
    },

    RocketMoveSpeed = 28,
    ObstacleSpawnInterval = 1.5,
    FuelOrbSpawnInterval = 2.5,
    ObstacleSpeed = 16,
    FuelOrbSpeed = 13,
    MaxHitsBeforeCrash = 3,
    EndRunReturnDelay = 2,
    StartingZoneName = "Atmosphere",

    FuelOrbReward = 5,
    AsteroidRadius = 2.2,
    FuelOrbRadius = 1.3,
    RocketCollisionRadius = 1.8,
}

return RocketTravelConfig
