export type OwnedAlien = {
    UID: string,
    AlienId: string,
    Variant: string?,
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
    LuckLevel: number,
    RollSpeedLevel: number,
    FuelIncomeLevel: number,
}

local PlayerData: PlayerData = {
    Fuel = 25,
    AlienInventory = {},
    EquippedAliens = {},
    AlienIndex = {},
    HasUsedFreeScan = false,
    LuckLevel = 0,
    RollSpeedLevel = 0,
    FuelIncomeLevel = 0,
}

return PlayerData
