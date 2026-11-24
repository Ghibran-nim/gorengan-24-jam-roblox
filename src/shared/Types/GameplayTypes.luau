--!strict
--[[
    GameplayTypes.luau
    Definisi tipe data dan kontrak terpusat untuk Gorengan 24 Jam: Awas Satpol!
]]

export type QualityResult = "Undercooked" | "Crispy" | "Burnt"

export type CookState = "Empty" | "Cooking" | "Ready"

export type Recipe = {
    Id: string,
    Name: string,
    BasePrice: number,
    TotalCookDuration: number, -- Total detik siklus memasak (100%)
    UndercookedMaxPercent: number, -- 0..0.30 (0 - 30%)
    CrispyMaxPercent: number,      -- 0.31..0.80 (31 - 80%)
    BurntMaxPercent: number,       -- 0.81..1.00 (81 - 100%)
    RequiredIngredients: { [string]: number },
    Description: string,
}

export type ActiveCookingBatch = {
    PlayerId: number,
    PlotId: number,
    RecipeId: string,
    StartTime: number,
    TotalCookDuration: number,
    IsCompleted: boolean,
}

export type PlayerInventory = {
    Ingredients: { [string]: number },
    CookedFood: { [string]: { Undercooked: number, Crispy: number, Burnt: number } },
}

export type PlayerEconomyData = {
    CarriedCash: number,
    BankedCash: number,
    Reputation: number,
}

export type CustomerOrder = {
    CustomerId: string,
    ArchetypeId: string,
    PlotId: number,
    RecipeId: string,
    Quantity: number,
    CreatedAt: number,
    PatienceDuration: number,
    State: "Approaching" | "InQueue" | "WaitingForFood" | "Served" | "Leaving" | "LostPatience",
    QueueSlot: number,
}

export type RaidState = "Idle" | "Warning" | "RaidActive" | "CoolingDown"

export type Service = {
    Name: string,
    Init: (self: any) -> (),
    Start: (self: any) -> (),
}

export type Controller = {
    Name: string,
    Init: (self: any) -> (),
    Start: (self: any) -> (),
}

return {}
