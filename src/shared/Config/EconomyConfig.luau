--!strict
--[[
    EconomyConfig.luau
    Parameter ekonomi terpusat: harga bahan baku toko, upgrade, aturan tabungan ATM,
    dan batas kapasitas kas.
]]

export type IngredientPack = {
    Id: string,
    Name: string,
    Amount: number,
    Price: number,
    Icon: string,
    Description: string,
}

local IngredientPacks: { [string]: IngredientPack } = {
    ["batter"] = {
        Id = "batter",
        Name = "Adonan Tepung Bumbu",
        Amount = 5,
        Price = 2500,
        Icon = "🥟",
        Description = "Bahan dasar wajib untuk aneka gorengan renyah.",
    },
    ["veggies"] = {
        Id = "veggies",
        Name = "Sayuran Kol & Wortel Segar",
        Amount = 5,
        Price = 2500,
        Icon = "🥬",
        Description = "Irisan kol dan wortel segar untuk Bakwan Sayur & Tahu Isi.",
    },
    ["banana"] = {
        Id = "banana",
        Name = "Pisang Kepok Manis",
        Amount = 5,
        Price = 3000,
        Icon = "🍌",
        Description = "Pisang pilihan manis legit untuk Pisang Goreng Crispy.",
    },
    ["tofu"] = {
        Id = "tofu",
        Name = "Tahu Pong Gurih",
        Amount = 5,
        Price = 3500,
        Icon = "🧈",
        Description = "Tahu pong kopong siap diisi sayuran pedas.",
    },
    ["tempeh"] = {
        Id = "tempeh",
        Name = "Tempe Daun Kedelai",
        Amount = 5,
        Price = 3000,
        Icon = "🥢",
        Description = "Tempe tipis lembut khas Banyumas untuk Mendoan.",
    },
    ["acitapioca"] = {
        Id = "acitapioca",
        Name = "Tepung Tapioka Super",
        Amount = 5,
        Price = 4000,
        Icon = "🥣",
        Description = "Pati singkong kenyal untuk Cireng Bumbu Rujak.",
    },
    ["egg"] = {
        Id = "egg",
        Name = "Telur Ayam Kampung",
        Amount = 5,
        Price = 5000,
        Icon = "🥚",
        Description = "Telur segar pilihan untuk Martabak Mini & Risol Mayo.",
    },
    ["risol_skin"] = {
        Id = "risol_skin",
        Name = "Kulit Lumpia & Saus Mayo",
        Amount = 5,
        Price = 6000,
        Icon = "🌯",
        Description = "Paket kulit renyah & mayones spesial untuk Risol Mayo.",
    },
}

local EconomyConfig = {
    -- Saldo awal pemain baru
    StartingCarriedCash = 50000, -- Rp 50.000 modal awal
    StartingBankedCash = 0,
    StartingReputation = 100,

    -- Kapasitas penyimpanan bahan mentah & etalase gorengan
    BaseIngredientCapacity = 30,
    UpgradedIngredientCapacity = 60,
    BaseEtalaseCapacity = 12,
    UpgradedEtalaseCapacity = 28,

    -- Multiplier nilai jual berdasarkan kualitas masakan
    QualityMultipliers = {
        Undercooked = 0.5, -- Penalti 50%
        Crispy = 1.0,      -- Harga penuh + bonus tip
        Burnt = 0.0,       -- Gosong (tidak dapat dijual ke pelanggan)
    },

    -- Bonus tips jika gorengan disajikan dalam kualitas Crispy
    CrispyTipBonusPercent = 0.20,

    -- Persentase sitaan uang tunai jika tertangkap razia Satpol PP
    RaidCarriedCashPenaltyPercent = 0.25,

    -- Biaya transaksi ATM (0 = gratis)
    ATMFeePercent = 0.0,

    -- Batas maksimal uang tunai kas pedagang
    BaseCarriedCashCapacity = 1000000, -- Rp 1.000.000

    -- Paket penjualan di Toko Bahan Baku
    IngredientPacks = IngredientPacks,

    GetIngredientPack = function(id: string): IngredientPack?
        return IngredientPacks[id]
    end,

    GetAllPacks = function(): { IngredientPack }
        local list = {}
        for _, pack in pairs(IngredientPacks) do
            table.insert(list, pack)
        end
        return list
    end,
}

return table.freeze(EconomyConfig)
