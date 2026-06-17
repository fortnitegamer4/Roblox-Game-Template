export type OwnedAlien = {
    UID: string,
    AlienId: string,
    Variant: string?,
    Locked: boolean?,
}

export type AlienInventory = {
    [string]: OwnedAlien,
}

export type AlienIndex = {
    [string]: boolean,
}

export type PlayerData = {
    Fuel: number,
    AlienInventory: AlienInventory,
    EquippedAliens: { string },
    AlienIndex: AlienIndex,
    HasUsedFreeScan: boolean,
    TotalScans: number,
    AutoScanUnlocked: boolean,
    LuckLevel: number,
    RollSpeedLevel: number,
    FuelIncomeLevel: number,
    ClaimedIndexRewards: { [string]: boolean },
    IndexFuelIncomeBonus: number,
    IndexLuckBonus: number,
    IndexRollSpeedBonus: number,
    HighestHeight: number,
    TotalLaunches: number,
    LastLaunchHeight: number,
}

local PlayerData: PlayerData = {
    Fuel = 25,
    AlienInventory = {},
    EquippedAliens = {},
    AlienIndex = {},
    HasUsedFreeScan = false,
    TotalScans = 0,
    AutoScanUnlocked = false,
    LuckLevel = 0,
    RollSpeedLevel = 0,
    FuelIncomeLevel = 0,
    ClaimedIndexRewards = {},
    IndexFuelIncomeBonus = 0,
    IndexLuckBonus = 0,
    IndexRollSpeedBonus = 0,
    HighestHeight = 0,
    TotalLaunches = 0,
    LastLaunchHeight = 0,
}

return PlayerData
