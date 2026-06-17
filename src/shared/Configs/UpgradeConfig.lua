export type UpgradeId = "LuckLevel" | "RollSpeedLevel" | "FuelIncomeLevel"

export type UpgradeDefinition = {
    DisplayName: string,
    BaseCost: number,
    CostMultiplier: number,
    MaxLevel: number,
    Description: string,
}

local UpgradeConfig = {}

UpgradeConfig.Upgrades = {
    LuckLevel = {
        DisplayName = "Luck",
        BaseCost = 50,
        CostMultiplier = 1.6,
        MaxLevel = 25,
        Description = "Improves odds for rarer alien scans.",
    },
    RollSpeedLevel = {
        DisplayName = "Roll Speed",
        BaseCost = 40,
        CostMultiplier = 1.55,
        MaxLevel = 25,
        Description = "Reduces scanner cooldown.",
    },
    FuelIncomeLevel = {
        DisplayName = "Fuel Income",
        BaseCost = 60,
        CostMultiplier = 1.7,
        MaxLevel = 25,
        Description = "Increases passive Fuel from equipped crew power.",
    },
} :: { [UpgradeId]: UpgradeDefinition }

UpgradeConfig.Order = {
    "LuckLevel",
    "RollSpeedLevel",
    "FuelIncomeLevel",
} :: { UpgradeId }

function UpgradeConfig.GetCost(upgradeId: UpgradeId, currentLevel: number): number?
    local definition = UpgradeConfig.Upgrades[upgradeId]
    if not definition or currentLevel >= definition.MaxLevel then
        return
    end

    return math.floor(definition.BaseCost * (definition.CostMultiplier ^ currentLevel))
end

return UpgradeConfig
