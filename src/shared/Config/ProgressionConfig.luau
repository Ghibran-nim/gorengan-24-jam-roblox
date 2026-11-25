--!strict
--[[
    ProgressionConfig.luau
    Konfigurasi terpusat sistem level pedagang, XP, gelar bisnis, dan kurva progression.
]]

local LEVEL_THRESHOLDS: { [number]: number } = {
    [1] = 0,
    [2] = 150,
    [3] = 450,
    [4] = 950,
    [5] = 1650,
    [6] = 2600,
    [7] = 3800,
    [8] = 5300,
    [9] = 7100,
    [10] = 9200,
}

local LEVEL_TITLES: { [number]: string } = {
    [1] = "Pedagang Pemula",
    [2] = "Tukang Gorengan Baru",
    [3] = "Pedagang Terampil",
    [4] = "Jagoan Kaki Lima",
    [5] = "Bos Gerobak",
    [6] = "Juragan Gorengan",
    [7] = "Maestro Krenyes",
    [8] = "Sultan Penggorengan",
    [9] = "Legenda Trotoar",
    [10] = "Raja Gorengan 24 Jam",
}

local ProgressionConfig = {
    MaxLevel = 10,
    LevelThresholds = LEVEL_THRESHOLDS,
    LevelTitles = LEVEL_TITLES,

    XPRewards = {
        CookCrispy = 12,
        CookUndercooked = 5,
        CookBurnt = 3,
        ServeCustomerBase = 20,
        ServeCrispyBonus = 10,
    },

    GetXPThreshold = function(level: number): number
        local clamped = math.clamp(level, 1, 10)
        return LEVEL_THRESHOLDS[clamped] or 9200
    end,

    GetTitleForLevel = function(level: number): string
        local clamped = math.clamp(level, 1, 10)
        return LEVEL_TITLES[clamped] or "Juragan Gorengan"
    end,

    GetLevelForTotalXP = function(totalXP: number): number
        local currentLevel = 1
        for lvl = 2, 10 do
            if totalXP >= (LEVEL_THRESHOLDS[lvl] or math.huge) then
                currentLevel = lvl
            else
                break
            end
        end
        return currentLevel
    end,
}

return table.freeze(ProgressionConfig)