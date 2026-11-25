--!strict
--[[
    DataConfig.luau
    Konfigurasi terpusat sistem persistensi data pemain (DataStoreService):
    - Skema versi & migrasi aman
    - Batas retry exponential backoff & jeda penyimpanan agar tidak melebihi kuota Roblox
    - Penguncian sesi (session locking) mencegah duplikasi & overwrite data stale
]]

local DataConfig = {
    CurrentSchemaVersion = 2,
    DataStoreName = "Gorengan24Jam_PlayerProfile_v2",
    AutoSaveIntervalSeconds = 60,
    MinSaveIntervalSeconds = 10,
    RetryMaxAttempts = 3,
    RetryBaseDelaySeconds = 0.6,
    SessionLockTimeoutSeconds = 90,
}

return table.freeze(DataConfig)
