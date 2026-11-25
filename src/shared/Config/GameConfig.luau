--!strict
--[[
    GameConfig.luau
    Konfigurasi sentral aturan global permainan.
]]

local GameConfig = {
    -- Batas kapasitas server
    MaxPlayers = 8,

    -- Jarak interaksi maksimal wajar (studs)
    InteractionMaxDistance = 16,

    -- Rate limit permintaan remote per pemain (permintaan per detik)
    RateLimitRequestsPerSecond = 12,

    -- Siklus siang/malam (720 detik = 12 menit real-time untuk 24 jam in-game)
    DayCycleDurationSeconds = 720,

    -- Peringatan razia Satpol PP sebelum pasukan tiba (15 detik sesuai GDD & Prompt)
    RaidWarningDurationSeconds = 15,

    -- Durasi razia aktif berlangsung (detik)
    RaidActiveDurationSeconds = 45,

    -- Jarak interval antar razia berkala (detik)
    RaidIntervalSeconds = 120,

    -- Kecepatan jalan normal karakter (studs/detik)
    NormalWalkSpeed = 16,

    -- Kecepatan dorong gerobak standar (studs/detik)
    PushCartWalkSpeed = 10,

    -- Kecepatan dorong gerobak dengan upgrade Roda Bearing (studs/detik)
    PushCartBearingSpeed = 13.5,

    -- Kecepatan patroli & pengejaran Satpol PP (adil, tidak mustahil dihindari)
    SatpolPatrolWalkSpeed = 12.0,

    -- Radius deteksi penglihatan Satpol PP (studs)
    SatpolDetectionRadius = 35,

    -- Jarak penangkapan gerobak oleh Satpol PP (studs)
    SatpolCaptureDistance = 8,

    -- Persentase pemotongan kas pedagang saat tertangkap razia (25%)
    SatpolPenaltyCashPercent = 0.25,

    -- Pengaturan item lempar gorengan gosong (Throwable & Social Chaos)
    BurntThrowCooldownSeconds = 3.5,
    BurntThrowMaxDistance = 55,
    BurntThrowProjectileSpeed = 65,
    BurntThrowGravity = 38,
    BurntThrowHitRadius = 3.2,
    BurntRagdollDurationSeconds = 2.0,
    BurntTargetImmunitySeconds = 8.0,
    BurntSpawnProtectionSeconds = 5.0,
    BurntPairHarassmentCooldownSeconds = 10.0,

    -- Pengaturan Multiplayer, Interaksi Antargerobak & Kompetisi
    SocialBuyCooldownSeconds = 2.0,
    SocialReactionCooldownSeconds = 10.0,
    CartNeighborBonusCash = 250,
    LeaderboardBroadcastThrottleSeconds = 1.0,
    CompetitionEventDurationSeconds = 45,

    -- Nama folder remote di ReplicatedStorage
    RemotesFolderName = "NetworkRemotes",

    -- Nama tag CollectionService untuk area Safe Zone
    SafeZoneTag = "SafeZone",

    -- Interval auto-save data pemain (detik)
    AutoSaveIntervalSeconds = 60,
}

return table.freeze(GameConfig)
