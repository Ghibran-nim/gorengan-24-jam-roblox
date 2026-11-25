--!strict
--[[
    GameplayTypes.luau
    Definisi tipe data dan kontrak terpusat untuk Gorengan 24 Jam: Awas Satpol!
]]

export type QualityResult = "Undercooked" | "Crispy" | "Burnt"

export type CookState = "Empty" | "Cooking" | "Ready"

export type RecipeDifficulty = "Mudah" | "Sedang" | "Menengah" | "Sulit" | "Ahli"

export type Recipe = {
    Id: string,
    Name: string,
    Icon: string,
    Difficulty: RecipeDifficulty,
    UnlockLevel: number,
    UnlockCost: number,
    BasePrice: number,
    TotalCookDuration: number, -- Total detik siklus memasak (100%)
    UndercookedMaxPercent: number, -- 0..UndercookedMaxPercent
    CrispyMaxPercent: number,      -- UndercookedMaxPercent..CrispyMaxPercent
    BurntMaxPercent: number,       -- CrispyMaxPercent..1.00
    RequiredIngredients: { [string]: number },
    Description: string,
}

export type ProgressionData = {
    Level: number,
    XP: number,
    TotalXP: number,
    NextLevelXP: number,
    Title: string,
    UnlockedRecipes: { [string]: boolean },
    SelectedRecipeId: string,
    TotalSales: number,
    TotalEarnings: number,
}

export type ChiliRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic"

export type ChiliCollectionEntry = {
    Count: number,
    FirstObtainedAt: number,
}

export type ChiliCollectionData = {
    SchemaVersion: number,
    TotalRolls: number,
    PityCounter: number,
    EquippedChiliId: string?,
    OwnedChilis: { [string]: ChiliCollectionEntry },
}

export type DayPhaseId = "Pagi" | "Siang" | "Sore" | "Malam"

export type TimeState = {
    ClockTime: number,
    Hour: number,
    Minute: number,
    PhaseId: DayPhaseId,
    PhaseName: string,
    DayCount: number,
}

export type ActiveWorldEvent = {
    EventId: string,
    Name: string,
    Icon: string?,
    StartTime: number,
    Duration: number,
    RemainingSeconds: number?,
    Description: string,
    BannerColor: Color3?,
}

export type LeaderboardEntry = {
    UserId: number,
    PlayerName: string,
    Rank: number,
    PlotId: number?,
    Level: number,
    Title: string,
    TotalEarnings: number,
    TotalSales: number,
    NetWorth: number,
    Reputation: number,
    IsLeader: boolean,
}

export type CartVisitSummary = {
    OwnerUserId: number,
    OwnerName: string,
    PlotId: number?,
    Level: number,
    Reputation: number,
    StockByRecipe: { [string]: number },
    TotalCrispy: number,
    PricesByRecipe: { [string]: number },
    ReactionsCount: number,
}

export type PlayerStatsData = {
    TotalCooked: number,
    TotalCrispy: number,
    TotalUndercooked: number,
    TotalBurnt: number,
    RaidsSurvived: number,
    RaidsCaptured: number,
    PlayTimeSeconds: number,
    FirstJoinedAt: number,
    LastSavedAt: number,
}

export type PlayerSaveProfile = {
    SchemaVersion: number,
    Meta: {
        SaveCount: number,
        SessionLock: {
            JobId: string,
            LockedAt: number,
        }?,
    },
    Economy: PlayerEconomyData,
    Inventory: PlayerInventory,
    Upgrades: { [string]: boolean },
    Progression: ProgressionData & {
        TutorialStep: number,
        TutorialCompleted: boolean,
        TutorialSkipped: boolean,
    },
    ChiliCollection: ChiliCollectionData,
    Stats: PlayerStatsData,
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
