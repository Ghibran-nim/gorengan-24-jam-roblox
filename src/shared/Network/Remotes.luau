--!strict
--[[
    Remotes.luau
    Definisi konstan nama-nama RemoteEvent dan RemoteFunction yang digunakan di seluruh permainan.
]]

local Remotes = {
    -- RemoteEvent (Sinyal satu arah, Server->Client atau Client->Server)
    Events = {
        -- Notifikasi perubahan status memasak ke client
        CookStateChanged = "CookStateChanged",

        -- Notifikasi hasil makanan yang diambil dari wajan
        FoodCollected = "FoodCollected",

        -- Notifikasi sinkronisasi inventaris pemain (bahan & gorengan jadi)
        InventoryUpdated = "InventoryUpdated",

        -- Notifikasi perubahan status gerobak (wajan, etalase, level)
        CartStatusUpdated = "CartStatusUpdated",

        -- Notifikasi sinkronisasi upgrade yang telah dibeli
        UpgradesUpdated = "UpgradesUpdated",

        -- Notifikasi pelanggan baru tiba di gerobak
        CustomerOrderCreated = "CustomerOrderCreated",

        -- Notifikasi pelanggan selesai dilayani
        CustomerOrderCompleted = "CustomerOrderCompleted",

        -- Peringatan razia Satpol PP (Kentongan/Sirine)
        RaidAlert = "RaidAlert",

        -- Notifikasi tertangkap razia Satpol PP
        PlayerCapturedBySatpol = "PlayerCapturedBySatpol",

        -- Notifikasi perubahan status mendorong gerobak
        CartPushStateChanged = "CartPushStateChanged",

        -- Notifikasi update saldo uang & reputasi pemain
        PlayerEconomyUpdated = "PlayerEconomyUpdated",

        -- Notifikasi perkembangan langkah tutorial pemula
        TutorialStepUpdated = "TutorialStepUpdated",

        -- Notifikasi pesan HUD umum (toast alert)
        NotificationFired = "NotificationFired",
    },

    -- RemoteFunction (Permintaan Client->Server dengan response balikan)
    Functions = {
        -- Memulai proses memasak adonan
        RequestStartCooking = "RequestStartCooking",

        -- Mengangkat hasil gorengan dari wajan
        RequestCollectFood = "RequestCollectFood",

        -- Mengambil persediaan bahan dari kotak gerobak
        RequestTakeIngredients = "RequestTakeIngredients",

        -- Membeli paket bahan baku dari Toko Bahan
        RequestBuyIngredient = "RequestBuyIngredient",

        -- Meminta data inventaris lengkap
        RequestGetInventory = "RequestGetInventory",

        -- Menyajikan pesanan ke pelanggan
        RequestServeCustomer = "RequestServeCustomer",

        -- Setor uang tunai ke rekening ATM
        RequestDepositATM = "RequestDepositATM",

        -- Tarik uang tabungan dari ATM
        RequestWithdrawATM = "RequestWithdrawATM",

        -- Beli upgrade gerobak/peralatan
        RequestBuyUpgrade = "RequestBuyUpgrade",

        -- Meminta daftar upgrade yang telah dimiliki
        RequestGetUpgrades = "RequestGetUpgrades",

        -- Meminta status tutorial pemula saat ini
        RequestGetTutorialState = "RequestGetTutorialState",

        -- Lewati tutorial pemula
        RequestSkipTutorial = "RequestSkipTutorial",

        -- Mulai mendorong gerobak
        RequestStartPushCart = "RequestStartPushCart",

        -- Berhenti mendorong gerobak
        RequestStopPushCart = "RequestStopPushCart",

        -- Sinkronisasi posisi dorong gerobak dengan validasi anti-exploit
        RequestUpdateCartPosition = "RequestUpdateCartPosition",

        -- Picu razia Satpol PP (Testing & Scheduled Events)
        RequestForceRaidEvent = "RequestForceRaidEvent",

        -- Cek apakah posisi gerobak pemain saat ini berada di Safe Zone
        RequestCheckSafeZone = "RequestCheckSafeZone",
    },
}

return table.freeze(Remotes)
