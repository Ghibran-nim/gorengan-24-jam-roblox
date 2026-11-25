--!strict
--[[
    UpgradesConfig.luau
    Konfigurasi modular seluruh peningkatan gerobak, wajan, kapasitas penyimpanan,
    kecepatan memasak, bisnis, kasir NPC, dan dekorasi dengan dampak gameplay nyata.
]]

export type UpgradeCategory = "Gerobak" | "Wajan" | "Kecepatan" | "Penyimpanan" | "Bisnis" | "Kasir" | "Dekorasi"

export type UpgradeItem = {
    Id: string,
    Name: string,
    Category: UpgradeCategory,
    Cost: number,
    RequiredLevel: number,
    PrerequisiteId: string?,
    Description: string,
    MultiplierBonus: number,
}

local Upgrades: { [string]: UpgradeItem } = {
    ["wajan_jumbo"] = {
        Id = "wajan_jumbo",
        Name = "Wajan Baja Jumbo",
        Category = "Wajan",
        Cost = 25000,
        RequiredLevel = 1,
        PrerequisiteId = nil,
        Description = "Wajan berdiameter lebar. Mempercepat waktu memasak sebesar +15%.",
        MultiplierBonus = 0.15,
    },
    ["roda_bearing"] = {
        Id = "roda_bearing",
        Name = "Roda Bearing Halus",
        Category = "Gerobak",
        Cost = 30000,
        RequiredLevel = 1,
        PrerequisiteId = nil,
        Description = "Roda karet presisi. Dorong gerobak +35% lebih cepat (13.5 studs/s) saat kabur razia.",
        MultiplierBonus = 0.35,
    },
    ["kotak_bahan_xl"] = {
        Id = "kotak_bahan_xl",
        Name = "Kotak Bahan Kulkas Mini",
        Category = "Penyimpanan",
        Cost = 32000,
        RequiredLevel = 2,
        PrerequisiteId = nil,
        Description = "Kapasitas penyimpanan bahan baku per jenis naik 2x lipat (30 -> 60 porsi).",
        MultiplierBonus = 2.0,
    },
    ["kompor_turbo"] = {
        Id = "kompor_turbo",
        Name = "Kompor Gas Turbo",
        Category = "Kecepatan",
        Cost = 35000,
        RequiredLevel = 2,
        PrerequisiteId = nil,
        Description = "Api biru stabil merata: memasak +15% lebih cepat & zona Crispy +12% lebih lebar.",
        MultiplierBonus = 0.15,
    },
    ["spanduk_neon"] = {
        Id = "spanduk_neon",
        Name = "Spanduk Neon Kaki Lima",
        Category = "Dekorasi",
        Cost = 50000,
        RequiredLevel = 2,
        PrerequisiteId = nil,
        Description = "Papan neon bercahaya di gerobak! Menarik pelanggan datang 25% lebih cepat.",
        MultiplierBonus = 0.25,
    },
    ["etalase_2tingkat"] = {
        Id = "etalase_2tingkat",
        Name = "Etalase Kaca 2 Tingkat",
        Category = "Penyimpanan",
        Cost = 55000,
        RequiredLevel = 3,
        PrerequisiteId = nil,
        Description = "Menambah rak kaca tingkat-2! Kapasitas display gorengan siap saji naik (12 -> 28 porsi).",
        MultiplierBonus = 2.33,
    },
    ["rangka_anti_razia"] = {
        Id = "rangka_anti_razia",
        Name = "Rangka Baja & Terpal Lipat",
        Category = "Gerobak",
        Cost = 65000,
        RequiredLevel = 3,
        PrerequisiteId = "roda_bearing",
        Description = "Pelindung gerobak tangguh: denda kas razia Satpol PP berkurang dari 25% menjadi 12%!",
        MultiplierBonus = 0.12,
    },
    ["lampu_tenda_hias"] = {
        Id = "lampu_tenda_hias",
        Name = "Lampu Tenda Pasar Malam",
        Category = "Dekorasi",
        Cost = 75000,
        RequiredLevel = 4,
        PrerequisiteId = "spanduk_neon",
        Description = "Lampu hias hangat bikin pembeli betah! Menambah bonus tip pelanggan sebesar +15%.",
        MultiplierBonus = 0.15,
    },
    ["wajan_anti_lengket"] = {
        Id = "wajan_anti_lengket",
        Name = "Wajan Anti-Lengket Teflon",
        Category = "Wajan",
        Cost = 85000,
        RequiredLevel = 4,
        PrerequisiteId = "wajan_jumbo",
        Description = "Distribusi panas sempurna: masak +10% lebih cepat & cegah gosong (+8% zona Crispy).",
        MultiplierBonus = 0.10,
    },
    ["papan_promo"] = {
        Id = "papan_promo",
        Name = "Papan Menu & Promo Viral",
        Category = "Bisnis",
        Cost = 95000,
        RequiredLevel = 4,
        PrerequisiteId = nil,
        Description = "Branding profesional menaikkan harga jual dasar seluruh gorengan sebesar +15%!",
        MultiplierBonus = 0.15,
    },
    ["kompor_mawar"] = {
        Id = "kompor_mawar",
        Name = "Kompor Tekanan Tinggi Mawar",
        Category = "Kecepatan",
        Cost = 115000,
        RequiredLevel = 5,
        PrerequisiteId = "kompor_turbo",
        Description = "Semburan api koki profesional! Mempercepat durasi penggorengan ekstra +20%.",
        MultiplierBonus = 0.20,
    },
    ["kasir_npc"] = {
        Id = "kasir_npc",
        Name = "Rekrut Kasir NPC (Mas Budi)",
        Category = "Kasir",
        Cost = 145000,
        RequiredLevel = 5,
        PrerequisiteId = nil,
        Description = "Mempekerjakan Kasir Mas Budi di gerobakmu! Otomatis melayani antrean pembeli setiap 2.5 detik.",
        MultiplierBonus = 1.0,
    },
}

local UpgradesConfig = {
    Upgrades = Upgrades,

    GetUpgrade = function(id: string): UpgradeItem?
        return Upgrades[id]
    end,

    GetAllUpgrades = function(): { UpgradeItem }
        local list = {}
        for _, item in pairs(Upgrades) do
            table.insert(list, item)
        end
        table.sort(list, function(a, b)
            if a.RequiredLevel == b.RequiredLevel then
                return a.Cost < b.Cost
            end
            return a.RequiredLevel < b.RequiredLevel
        end)
        return list
    end,
}

return table.freeze(UpgradesConfig)