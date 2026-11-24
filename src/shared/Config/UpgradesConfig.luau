--!strict
--[[
    UpgradesConfig.luau
    Konfigurasi peningkatan peralatan gerobak, wajan, kompor, dan roda gerobak.
]]

export type UpgradeItem = {
    Id: string,
    Name: string,
    Category: "Wajan" | "Kompor" | "Roda" | "Etalase" | "Dekorasi",
    Cost: number,
    Description: string,
    MultiplierBonus: number, -- Nilai efek mekanik (misal +15% kecepatan masak)
}

local Upgrades: { [string]: UpgradeItem } = {
    ["wajan_jumbo"] = {
        Id = "wajan_jumbo",
        Name = "Wajan Baja Jumbo",
        Category = "Wajan",
        Cost = 25000,
        Description = "Wajan baja tebal berdiameter lebih lebar. Mempercepat waktu memasak sebesar 15%.",
        MultiplierBonus = 0.15,
    },
    ["kompor_turbo"] = {
        Id = "kompor_turbo",
        Name = "Kompor Gas Turbo",
        Category = "Kompor",
        Cost = 35000,
        Description = "Api biru stabil merata. Memperlebar window kematangan 'Crispy' sebesar 20%.",
        MultiplierBonus = 0.20,
    },
    ["roda_bearing"] = {
        Id = "roda_bearing",
        Name = "Roda Bearing Halus",
        Category = "Roda",
        Cost = 40000,
        Description = "Roda karet dengan bearing presisi. Mendorong gerobak menjadi 25% lebih cepat dan ringan saat kabur dari Satpol PP.",
        MultiplierBonus = 0.25,
    },
    ["etalase_2tingkat"] = {
        Id = "etalase_2tingkat",
        Name = "Etalase Kaca 2 Tingkat",
        Category = "Etalase",
        Cost = 50000,
        Description = "Kapasitas display gorengan meningkat 2x lipat. Mencegah gorengan cepat dingin.",
        MultiplierBonus = 2.0,
    },
    ["spanduk_neon"] = {
        Id = "spanduk_neon",
        Name = "Spanduk Neon Kaki Lima",
        Category = "Dekorasi",
        Cost = 60000,
        Description = "Lampu neon warna-warni menarik perhatian pembeli. Pelanggan datang 25% lebih sering.",
        MultiplierBonus = 0.25,
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
            return a.Cost < b.Cost
        end)
        return list
    end,
}

return table.freeze(UpgradesConfig)
