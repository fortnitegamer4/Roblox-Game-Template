--Future step: cost of roll will not be stationary. different zones will give higher chances for better aliens at a higher price proportional to the achievement itself.


export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type AlienDefinition = {
    AlienId: string,
    DisplayName: string,
    Rarity: Rarity,
    BaseOdds: number,
    Power: number,
    Zone: string,
    Variant: string?,
}

local AlienConfig = {}

AlienConfig.MaxEquipped = 3
AlienConfig.MaxAlienInventory = 100
AlienConfig.ScanCost = 25
AlienConfig.StarterAlienId = "cosmic_slime"
AlienConfig.AutoScanUnlockScans = 10
AlienConfig.BaseScanCooldown = 3
AlienConfig.RollSpeedCooldownReduction = 0.12
AlienConfig.MinScanCooldown = 0.75
AlienConfig.PassiveFuelTickSeconds = 3
AlienConfig.FuelPerPowerPerTick = 1
AlienConfig.LuckPerLevel = 0.08
AlienConfig.FuelIncomePerLevel = 0.1

function AlienConfig.GetScanCooldown(rollSpeedLevel: number, bonusRollSpeed: number?): number
    local reductionMultiplier = 1 + (rollSpeedLevel * AlienConfig.RollSpeedCooldownReduction) + (bonusRollSpeed or 0)

    return math.max(AlienConfig.BaseScanCooldown / reductionMultiplier, AlienConfig.MinScanCooldown)
end

AlienConfig.RarityOrder = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Secret = 7,
}

AlienConfig.RarityLuckExponent = {
    Common = 0.05,
    Uncommon = 0.2,
    Rare = 0.45,
    Epic = 0.75,
    Legendary = 1.1,
    Mythic = 1.45,
    Secret = 1.8,
}

AlienConfig.Aliens = {
    {
        AlienId = "moon_sprout",
        DisplayName = "Moon Sprout",
        Rarity = "Common",
        BaseOdds = 2,
        Power = 1,
        Zone = "Earth",
    },
    {
        AlienId = "tin_orbiter",
        DisplayName = "Tin Orbiter",
        Rarity = "Common",
        BaseOdds = 5,
        Power = 2,
        Zone = "Earth",
    },
    {
        AlienId = "cosmic_slime",
        DisplayName = "Cosmic Slime",
        Rarity = "Uncommon",
        BaseOdds = 10,
        Power = 4,
        Zone = "Earth",
    },
    {
        AlienId = "nebula_nibbler",
        DisplayName = "Nebula Nibbler",
        Rarity = "Uncommon",
        BaseOdds = 25,
        Power = 7,
        Zone = "Earth",
    },
    {
        AlienId = "astro_mite",
        DisplayName = "Astro Mite",
        Rarity = "Rare",
        BaseOdds = 50,
        Power = 12,
        Zone = "Earth",
    },
    {
        AlienId = "plasma_pod",
        DisplayName = "Plasma Pod",
        Rarity = "Rare",
        BaseOdds = 100,
        Power = 18,
        Zone = "Earth",
    },
    {
        AlienId = "star_peeper",
        DisplayName = "Star Peeper",
        Rarity = "Epic",
        BaseOdds = 250,
        Power = 35,
        Zone = "Earth",
    },
    {
        AlienId = "void_jelly",
        DisplayName = "Void Jelly",
        Rarity = "Legendary",
        BaseOdds = 1000,
        Power = 90,
        Zone = "Earth",
    },
    {
        AlienId = "quantum_buddy",
        DisplayName = "Quantum Buddy",
        Rarity = "Mythic",
        BaseOdds = 5000,
        Power = 240,
        Zone = "Earth",
    },
    {
        AlienId = "earthbound_secret",
        DisplayName = "Earthbound Secret",
        Rarity = "Secret",
        BaseOdds = 25000,
        Power = 900,
        Zone = "Earth",
        Variant = "Secret",
    },
} :: { AlienDefinition }

AlienConfig.IndexRewards = {
    discover_3 = {
        DisplayName = "First Contact",
        RequiredDiscoveries = 3,
        Description = "+5% Fuel Income",
        Reward = {
            FuelIncomeBonus = 0.05,
        },
    },
    discover_5 = {
        DisplayName = "Lucky Signals",
        RequiredDiscoveries = 5,
        Description = "+0.25 Luck",
        Reward = {
            LuckBonus = 0.25,
        },
    },
    discover_8 = {
        DisplayName = "Fast Frequency",
        RequiredDiscoveries = 8,
        Description = "+5% Roll Speed",
        Reward = {
            RollSpeedBonus = 0.05,
        },
    },
    discover_all_earth = {
        DisplayName = "Earth Collection",
        RequiresAllEarth = true,
        Description = "+10% Fuel Income",
        Reward = {
            FuelIncomeBonus = 0.1,
        },
    },
}

AlienConfig.IndexRewardOrder = {
    "discover_3",
    "discover_5",
    "discover_8",
    "discover_all_earth",
}

function AlienConfig.GetEarthAlienCount(): number
    local count = 0

    for _, alien in AlienConfig.Aliens do
        if alien.Zone == "Earth" then
            count += 1
        end
    end

    return count
end

local byId = {}

for _, alien in AlienConfig.Aliens do
    byId[alien.AlienId] = alien
end

AlienConfig.ById = byId

return AlienConfig
