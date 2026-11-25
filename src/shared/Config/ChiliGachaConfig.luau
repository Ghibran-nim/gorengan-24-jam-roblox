--!strict
--[[
    ChiliGachaConfig.luau
    Konfigurasi terpusat sistem Gacha & Koleksi Cabai Nusantara (Kios Cabai "Pedas Mampus").
    Seluruh probabilitas berbasis integer basis-points (Total = 10.000 = 100.00%) untuk presisi mutlak.
]]

local GameplayTypes = require(script.Parent.Parent:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ChiliRarity = GameplayTypes.ChiliRarity

export type ChiliItem = {
    Id: string,
    Name: string,
    Rarity: ChiliRarity,
    Icon: string,
    Color: Color3,
    Weight: number,              -- Basis points out of 10000
    ProbabilityPercent: number,  -- Exact disclosed percentage (e.g. 55.00, 0.80)
    ProfitMultiplier: number,    -- Sales payout multiplier (e.g. 1.05 .. 1.55)
    DuplicateCashback: number,   -- Cashback jika dapat duplikat (< RollCost rata-rata)
    CookSpeedBonus: number,      -- Extra cook speed bonus (e.g. 0.10 for Cabai Setan)
    XPBonusPercent: number,      -- Extra sale XP bonus
    SpecialEffectText: string,
    Lore: string,
}

local Chilis: { [string]: ChiliItem } = {
    ["cabai_hijau"] = {
        Id = "cabai_hijau",
        Name = "Cabai Rawit Hijau",
        Rarity = "Common",
        Icon = "🫑",
        Color = Color3.fromRGB(80, 195, 75),
        Weight = 5500,
        ProbabilityPercent = 55.00,
        ProfitMultiplier = 1.05,
        DuplicateCashback = 2000,
        CookSpeedBonus = 0,
        XPBonusPercent = 0,
        SpecialEffectText = "+5% Harga Jual Gorengan",
        Lore = "Cabai rawit hijau segar wajib setiap bungkus gorengan pinggir jalan.",
    },
    ["cabai_merah"] = {
        Id = "cabai_merah",
        Name = "Cabai Rawit Merah Domba",
        Rarity = "Uncommon",
        Icon = "🌶️",
        Color = Color3.fromRGB(235, 55, 45),
        Weight = 2800,
        ProbabilityPercent = 28.00,
        ProfitMultiplier = 1.12,
        DuplicateCashback = 3500,
        CookSpeedBonus = 0,
        XPBonusPercent = 0,
        SpecialEffectText = "+12% Harga Jual Gorengan",
        Lore = "Pedasnya nampol bikin mahasiswa dan ojol ketagihan nambah terus!",
    },
    ["cabai_hantu"] = {
        Id = "cabai_hantu",
        Name = "Cabai Setan Nusantara",
        Rarity = "Rare",
        Icon = "🔥",
        Color = Color3.fromRGB(255, 120, 20),
        Weight = 1200,
        ProbabilityPercent = 12.00,
        ProfitMultiplier = 1.22,
        DuplicateCashback = 6000,
        CookSpeedBonus = 0.10,
        XPBonusPercent = 0,
        SpecialEffectText = "+22% Harga Jual & +10% Kecepatan Masak",
        Lore = "Panasnya membara hingga wajan penggorengan ikut ngebut!",
    },
    ["cabai_emas"] = {
        Id = "cabai_emas",
        Name = "Cabai Keriting Emas Sultan",
        Rarity = "Epic",
        Icon = "✨",
        Color = Color3.fromRGB(255, 210, 45),
        Weight = 420,
        ProbabilityPercent = 4.20,
        ProfitMultiplier = 1.35,
        DuplicateCashback = 10000,
        CookSpeedBonus = 0,
        XPBonusPercent = 0.15,
        SpecialEffectText = "+35% Harga Jual & +15% Bonus XP",
        Lore = "Ditanam di kebun rahasia para Sultan, berkilau emas di atas etalase.",
    },
    ["cabai_pelangi"] = {
        Id = "cabai_pelangi",
        Name = "Cabai Pelangi Legendaris",
        Rarity = "Mythic",
        Icon = "🌈",
        Color = Color3.fromRGB(215, 85, 255),
        Weight = 80,
        ProbabilityPercent = 0.80,
        ProfitMultiplier = 1.55,
        DuplicateCashback = 20000,
        CookSpeedBonus = 0,
        XPBonusPercent = 0.25,
        SpecialEffectText = "+55% Harga Jual, +25% XP & Aura Pelangi",
        Lore = "Mitos jalanan 24 jam! Konon rasanya membuat Mbak Kunti pun ikut antre rapi.",
    },
}

local ORDERED_IDS = { "cabai_hijau", "cabai_merah", "cabai_hantu", "cabai_emas", "cabai_pelangi" }

local ChiliGachaConfig = {
    RollCost = 10000,
    PityThreshold = 15, -- Jaminan minimal Rare+ pada tarikan ke-15 berturut-turut
    TotalWeight = 10000,
    SchemaVersion = 1,
    Chilis = Chilis,
    OrderedIds = ORDERED_IDS,

    GetChili = function(id: string): ChiliItem?
        return Chilis[id]
    end,

    GetAllChilis = function(): { ChiliItem }
        local list = {}
        for _, id in ipairs(ORDERED_IDS) do
            table.insert(list, Chilis[id])
        end
        return list
    end,

    IsRareOrHigher = function(rarity: ChiliRarity): boolean
        return rarity == "Rare" or rarity == "Epic" or rarity == "Mythic"
    end,
}

return table.freeze(ChiliGachaConfig)