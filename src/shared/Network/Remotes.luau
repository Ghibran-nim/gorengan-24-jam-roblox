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

        -- Notifikasi status pegang gorengan gosong di tangan
        BurntFoodEquippedChanged = "BurntFoodEquippedChanged",

        -- Notifikasi visual proyektil gorengan gosong diluncurkan
        BurntFoodThrown = "BurntFoodThrown",

        -- Notifikasi efek tumbukan proyektil gorengan gosong
        BurntFoodImpact = "BurntFoodImpact",

        -- Notifikasi status ragdoll sementara pemain
        PlayerRagdollStateChanged = "PlayerRagdollStateChanged",

        -- Notifikasi pembaruan level, XP, dan resep terbuka
        ProgressionUpdated = "ProgressionUpdated",

        -- Notifikasi perayaan pembukaan resep baru
        RecipeUnlocked = "RecipeUnlocked",

        -- Notifikasi perayaan kenaikan level pedagang
        LevelUpAchieved = "LevelUpAchieved",

        -- Sinkronisasi koleksi & cabai aktif pemain
        ChiliCollectionUpdated = "ChiliCollectionUpdated",

        -- Hasil gacha cabai dari server untuk animasi reveal
        ChiliGachaRolled = "ChiliGachaRolled",

        -- Sinkronisasi waktu siklus 24 jam & fase siang/malam
        TimeStateUpdated = "TimeStateUpdated",

        -- Notifikasi dimulainya random event dunia
        WorldEventStarted = "WorldEventStarted",

        -- Notifikasi berakhirnya random event dunia
        WorldEventEnded = "WorldEventEnded",

        -- Sinkronisasi papan peringkat kompetisi pendapatan multiplayer
        LeaderboardUpdated = "LeaderboardUpdated",

        -- Feedback reaksi sosial & pembelian antargerobak
        CartSocialFeedback = "CartSocialFeedback",

        -- Event kompetisi omzet server-wide
        ServerCompetitionEvent = "ServerCompetitionEvent",
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

        -- Mengambil / membekali gorengan gosong untuk dibidik
        RequestEquipBurntFood = "RequestEquipBurntFood",

        -- Melempar gorengan gosong ke arah bidikan (validasi penuh server)
        RequestThrowBurntFood = "RequestThrowBurntFood",

        -- Meminta data progression lengkap (Level, XP, Resep terbuka)
        RequestGetProgression = "RequestGetProgression",

        -- Membuka resep gorengan baru
        RequestUnlockRecipe = "RequestUnlockRecipe",

        -- Memilih resep aktif untuk dimasak di wajan gerobak
        RequestSetSelectedRecipe = "RequestSetSelectedRecipe",

        -- Meminta data koleksi cabai langka pemain
        RequestGetChiliCollection = "RequestGetChiliCollection",

        -- Melakukan 1x roll gacha cabai otoritatif di server
        RequestRollChiliGacha = "RequestRollChiliGacha",

        -- Memasang cabai koleksi pada gerobak pemain
        RequestEquipChili = "RequestEquipChili",

        -- Meminta status waktu dan event aktif saat ini
        RequestGetWorldState = "RequestGetWorldState",

        -- Memicu / menghentikan event untuk testing & administrasi server
        RequestForceWorldEvent = "RequestForceWorldEvent",

        -- Meminta daftar papan peringkat kompetisi sesi terbaru
        RequestGetLeaderboard = "RequestGetLeaderboard",

        -- Menginspeksi etalase gerobak pemain lain di sekitar
        RequestInspectPlayerCart = "RequestInspectPlayerCart",

        -- Membeli gorengan Crispy langsung dari gerobak pemain lain
        RequestBuyFromPlayerCart = "RequestBuyFromPlayerCart",

        -- Mengirim reaksi sosial ke gerobak / pemain lain
        RequestSendSocialReaction = "RequestSendSocialReaction",

        -- Memicu / menghentikan event kompetisi omzet server-wide (Testing & Event)
        RequestTriggerCompetitionEvent = "RequestTriggerCompetitionEvent",
    },
}

return table.freeze(Remotes)
