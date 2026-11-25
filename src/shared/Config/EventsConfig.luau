--!strict
--[[
    EventsConfig.luau
    Konfigurasi terpusat seluruh Random Events (Hujan Deras, Food Vlogger, Pelanggan Misterius,
    Copet, Preman, Razia Satpol PP, dan Event Khusus Malam) beserta durasi, cooldown,
    reward, dan konsekuensi seimbang.
]]

local GameplayTypes = require(script.Parent.Parent:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type DayPhaseId = GameplayTypes.DayPhaseId

export type WorldEventDefinition = {
    Id: string,
    Name: string,
    Icon: string,
    Duration: number,
    Cooldown: number,
    Weight: number,
    AllowedPhases: { DayPhaseId },
    IsNightSpecial: boolean,
    RewardText: string,
    ConsequenceText: string,
    Description: string,
    BannerColor: Color3,
}

local Events: { [string]: WorldEventDefinition } = {
    ["hujan_deras"] = {
        Id = "hujan_deras",
        Name = "Hujan Deras Tropis",
        Icon = "🌧️",
        Duration = 45,
        Cooldown = 180,
        Weight = 22,
        AllowedPhases = { "Pagi", "Siang", "Sore", "Malam" },
        IsNightSpecial = false,
        RewardText = "+25% Harga Jual Gorengan Hangat",
        ConsequenceText = "Langkah agak lambat di luar Safe Zone",
        Description = "Hujan mengguyur jalanan! Pembeli rela bayar lebih mahal demi gorengan hangat.",
        BannerColor = Color3.fromRGB(45, 110, 190),
    },
    ["food_vlogger"] = {
        Id = "food_vlogger",
        Name = "Food Vlogger Viral",
        Icon = "🎥",
        Duration = 40,
        Cooldown = 200,
        Weight = 18,
        AllowedPhases = { "Pagi", "Siang", "Sore" },
        IsNightSpecial = false,
        RewardText = "2.0x Tip + 6 Reputasi + Bonus Pembeli",
        ConsequenceText = "-4 Reputasi jika gagal / gosong",
        Description = "Konten kreator mampir mereview gerobakmu! Sajikan gorengan Crispy segera!",
        BannerColor = Color3.fromRGB(215, 65, 105),
    },
    ["pelanggan_misterius"] = {
        Id = "pelanggan_misterius",
        Name = "Pelanggan Sultan Misterius",
        Icon = "🕶️",
        Duration = 45,
        Cooldown = 240,
        Weight = 14,
        AllowedPhases = { "Sore", "Malam" },
        IsNightSpecial = false,
        RewardText = "3.5x Tip Sultan + 8 Reputasi",
        ConsequenceText = "-3 Reputasi jika telat menyajikan",
        Description = "Sosok berjas hitam misterius mencari gorengan paling renyah di kota.",
        BannerColor = Color3.fromRGB(165, 130, 40),
    },
    ["copet"] = {
        Id = "copet",
        Name = "Aksi Copet Jalanan",
        Icon = "🥷",
        Duration = 25,
        Cooldown = 180,
        Weight = 15,
        AllowedPhases = { "Siang", "Sore", "Malam" },
        IsNightSpecial = false,
        RewardText = "Usir/lempar gosong berhadiah Rp 3.000 + 15 XP",
        ConsequenceText = "Mencuri 10% Kas (maks Rp 15rb); ATM 100% Aman",
        Description = "Copet mengincar uang kas pedagang di jalan! Usir atau lari ke Gang Aman!",
        BannerColor = Color3.fromRGB(135, 55, 155),
    },
    ["preman"] = {
        Id = "preman",
        Name = "Preman Palak Lapak",
        Icon = "💪",
        Duration = 30,
        Cooldown = 210,
        Weight = 14,
        AllowedPhases = { "Sore", "Malam" },
        IsNightSpecial = false,
        RewardText = "Lempar gosong / usir -> +20 XP & +5 Reputasi",
        ConsequenceText = "Palak maks Rp 5.000 jika dibiarkan mengancam",
        Description = "Preman kampung datang memalak lapak! Hadapi, bayar, atau lempar gorengan gosong!",
        BannerColor = Color3.fromRGB(190, 85, 35),
    },
    ["razia_satpol"] = {
        Id = "razia_satpol",
        Name = "Razia Satpol PP Mendadak",
        Icon = "🚨",
        Duration = 60,
        Cooldown = 150,
        Weight = 15,
        AllowedPhases = { "Pagi", "Siang", "Sore" },
        IsNightSpecial = false,
        RewardText = "Selamatkan gerobak ke Safe Zone!",
        ConsequenceText = "Sitaan 25% kas & etalase jika tertangkap",
        Description = "Kentongan berbunyi! Peringatan 15 detik sebelum patroli Satpol PP turun ke jalan!",
        BannerColor = Color3.fromRGB(200, 35, 35),
    },
    ["pasar_malam_hantu"] = {
        Id = "pasar_malam_hantu",
        Name = "Malam Jumat Pasar Malam",
        Icon = "👻",
        Duration = 50,
        Cooldown = 240,
        Weight = 24,
        AllowedPhases = { "Malam" },
        IsNightSpecial = true,
        RewardText = "+30% Bonus Tip Malam + Kemunculan Mbak Kunti (2.5x Tip)",
        ConsequenceText = "Suasana mistis malam hari",
        Description = "Event khusus malam! Pasar malam ramai pengunjung unik hingga Mbak Kunti ikut antre!",
        BannerColor = Color3.fromRGB(85, 65, 175),
    },
}

local ORDERED_EVENT_IDS = {
    "hujan_deras",
    "food_vlogger",
    "pelanggan_misterius",
    "copet",
    "preman",
    "razia_satpol",
    "pasar_malam_hantu",
}

local EventsConfig = {
    MaxConcurrentEvents = 2,
    SchedulerMinIntervalSeconds = 45,
    SchedulerMaxIntervalSeconds = 75,
    Events = Events,
    OrderedIds = ORDERED_EVENT_IDS,

    GetEvent = function(id: string): WorldEventDefinition?
        return Events[id]
    end,

    GetAllEvents = function(): { WorldEventDefinition }
        local list = {}
        for _, id in ipairs(ORDERED_EVENT_IDS) do
            table.insert(list, Events[id])
        end
        return list
    end,
}

return table.freeze(EventsConfig)