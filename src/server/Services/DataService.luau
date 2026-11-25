--!strict
--[[
    DataService.luau
    Layanan otoritatif server untuk persistensi data pemain berbasis DataStoreService:
    - Menyimpan Ekonomi (CarriedCash, BankedCash, Reputation), Inventory (Bahan & Etalase),
      Resep Terbuka, Upgrade, Chili Collection, Progression & Tutorial, dan Statistik Pemain.
    - Session Locking via UpdateAsync + monotonic SaveCount mencegah duplikasi / overwrite data lama.
    - Exponential backoff retry (maks 3 percobaan) & dirty-flag throttling menghindari spam kuota.
    - Data Versioning & Migrasi Otomatis (v0/v1 -> v2) serta sanitasi anti-korupsi.
    - Penanganan aman PlayerRemoving & game:BindToClose.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local DataConfig = require(Shared:WaitForChild("Config"):WaitForChild("DataConfig"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local UpgradesConfig = require(Shared:WaitForChild("Config"):WaitForChild("UpgradesConfig"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local ChiliGachaConfig = require(Shared:WaitForChild("Config"):WaitForChild("ChiliGachaConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type PlayerSaveProfile = GameplayTypes.PlayerSaveProfile
type PlayerStatsData = GameplayTypes.PlayerStatsData

export type StoreAdapter = {
    GetAsync: (self: any, key: string) -> any,
    UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

type DomainHandler = {
    Apply: (player: Player, profile: PlayerSaveProfile) -> (),
    Collect: (player: Player, profile: PlayerSaveProfile) -> (),
    Cleanup: ((userId: number) -> ())?,
}

local log = Logger.new("DataService")

local SERVER_SESSION_ID = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local DEFAULT_INGREDIENTS: { [string]: number } = {
    batter = 10,
    veggies = 10,
    banana = 5,
    tofu = 5,
    tempeh = 5,
    acitapioca = 5,
    egg = 0,
    risol_skin = 0,
}

local function deepCopy(val: any): any
    if typeof(val) ~= "table" then
        return val
    end
    local copy = {}
    for k, v in pairs(val) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function safeNonNegInt(val: any, fallback: number, maxVal: number?): number
    if typeof(val) ~= "number" or val ~= val or val == math.huge or val == -math.huge then
        return fallback
    end
    local floored = math.floor(val)
    if floored < 0 then
        return fallback
    end
    if maxVal and floored > maxVal then
        return maxVal
    end
    return floored
end

local DataService = {
    Name = "DataService",
    _profiles = {} :: { [number]: PlayerSaveProfile },
    _dirtyFlags = {} :: { [number]: boolean },
    _lastSaveAttempt = {} :: { [number]: number },
    _sessionJoinTime = {} :: { [number]: number },
    _loadingLocks = {} :: { [number]: boolean },
    _savingLocks = {} :: { [number]: boolean },
    _loadedFlags = {} :: { [number]: boolean },
    _domains = {} :: { [string]: DomainHandler },
    _domainOrder = {} :: { string },
    _storeAdapter = nil :: StoreAdapter?,
    _dataStoreAvailable = false,
    _autoSaveRunning = false,
    _sessionStats = {
        SavesSucceeded = 0,
        SavesFailed = 0,
        LoadsSucceeded = 0,
        LoadsFailed = 0,
        MigrationsRun = 0,
    },
}

function DataService.CreateDefaultProfile(): PlayerSaveProfile
    local cookedFood: { [string]: { Undercooked: number, Crispy: number, Burnt: number } } = {}
    for _, recipe in ipairs(RecipesConfig.GetAllRecipes()) do
        cookedFood[recipe.Id] = { Undercooked = 0, Crispy = 0, Burnt = 0 }
    end

    local now = os.time()
    return {
        SchemaVersion = DataConfig.CurrentSchemaVersion,
        Meta = {
            SaveCount = 0,
            SessionLock = nil,
        },
        Economy = {
            CarriedCash = EconomyConfig.StartingCarriedCash,
            BankedCash = EconomyConfig.StartingBankedCash,
            Reputation = EconomyConfig.StartingReputation,
        },
        Inventory = {
            Ingredients = table.clone(DEFAULT_INGREDIENTS),
            CookedFood = cookedFood,
        },
        Upgrades = {},
        Progression = {
            Level = 1,
            XP = 0,
            TotalXP = 0,
            NextLevelXP = ProgressionConfig.GetXPThreshold(2),
            Title = ProgressionConfig.GetTitleForLevel(1),
            UnlockedRecipes = {
                ["bakwan_sayur"] = true,
            },
            SelectedRecipeId = "bakwan_sayur",
            TotalSales = 0,
            TotalEarnings = 0,
            TutorialStep = 1,
            TutorialCompleted = false,
            TutorialSkipped = false,
        },
        ChiliCollection = {
            SchemaVersion = ChiliGachaConfig.SchemaVersion,
            TotalRolls = 0,
            PityCounter = 0,
            EquippedChiliId = nil,
            OwnedChilis = {},
        },
        Stats = {
            TotalCooked = 0,
            TotalCrispy = 0,
            TotalUndercooked = 0,
            TotalBurnt = 0,
            RaidsSurvived = 0,
            RaidsCaptured = 0,
            PlayTimeSeconds = 0,
            FirstJoinedAt = now,
            LastSavedAt = 0,
        },
    }
end

--[[
    Migrasi otomatis dari skema v0 (flat/legacy) atau v1 ke skema v2 saat ini,
    disertai sanitasi ketat terhadap nilai korup/NaN/negatif/ID tidak dikenal.
]]
function DataService.MigrateAndSanitize(raw: any): (PlayerSaveProfile, boolean)
    local profile = DataService.CreateDefaultProfile()
    if typeof(raw) ~= "table" then
        return profile, false
    end

    local rawVersion = if typeof(raw.SchemaVersion) == "number" then math.floor(raw.SchemaVersion) else 0
    local migrated = rawVersion < DataConfig.CurrentSchemaVersion

    -- 1. Meta
    if typeof(raw.Meta) == "table" then
        profile.Meta.SaveCount = safeNonNegInt(raw.Meta.SaveCount, 0)
        if typeof(raw.Meta.SessionLock) == "table"
            and typeof(raw.Meta.SessionLock.JobId) == "string"
            and typeof(raw.Meta.SessionLock.LockedAt) == "number" then
            profile.Meta.SessionLock = {
                JobId = raw.Meta.SessionLock.JobId,
                LockedAt = raw.Meta.SessionLock.LockedAt,
            }
        end
    end

    -- 2. Economy (mendukung legacy v0 flat Cash/Bank/Reputation atau v1/v2 Economy)
    local srcEco = if typeof(raw.Economy) == "table" then raw.Economy else raw
    if typeof(srcEco) == "table" then
        local maxCash = EconomyConfig.BaseCarriedCashCapacity or 1000000
        local carriedRaw = srcEco.CarriedCash
        if carriedRaw == nil then carriedRaw = srcEco.Cash end
        local bankedRaw = srcEco.BankedCash
        if bankedRaw == nil then bankedRaw = srcEco.Bank end

        profile.Economy.CarriedCash = safeNonNegInt(carriedRaw, profile.Economy.CarriedCash, maxCash)
        profile.Economy.BankedCash = safeNonNegInt(bankedRaw, profile.Economy.BankedCash, 100000000)
        profile.Economy.Reputation = safeNonNegInt(srcEco.Reputation, profile.Economy.Reputation, 100000)
    end

    -- 3. Upgrades (mendukung list array v0 maupun map { [id] = true })
    if typeof(raw.Upgrades) == "table" then
        for k, v in pairs(raw.Upgrades) do
            local upgId = if typeof(k) == "number" and typeof(v) == "string" then v else (if v == true and typeof(k) == "string" then k else nil)
            if upgId and UpgradesConfig.GetUpgrade(upgId) then
                profile.Upgrades[upgId] = true
            end
        end
    end

    -- 4. Inventory (Ingredients + CookedFood)
    local maxIngCap = EconomyConfig.UpgradedIngredientCapacity or 60
    if typeof(raw.Inventory) == "table" then
        if typeof(raw.Inventory.Ingredients) == "table" then
            for ingId, qty in pairs(raw.Inventory.Ingredients) do
                if typeof(ingId) == "string" and DEFAULT_INGREDIENTS[ingId] ~= nil then
                    profile.Inventory.Ingredients[ingId] = safeNonNegInt(qty, profile.Inventory.Ingredients[ingId] or 0, maxIngCap)
                end
            end
        end
        if typeof(raw.Inventory.CookedFood) == "table" then
            for recipeId, counts in pairs(raw.Inventory.CookedFood) do
                if typeof(recipeId) == "string" and RecipesConfig.GetRecipe(recipeId) and typeof(counts) == "table" then
                    profile.Inventory.CookedFood[recipeId] = {
                        Undercooked = safeNonNegInt(counts.Undercooked, 0, 50),
                        Crispy = safeNonNegInt(counts.Crispy, 0, 50),
                        Burnt = safeNonNegInt(counts.Burnt, 0, 50),
                    }
                end
            end
        end
    end

    -- 5. Progression & UnlockedRecipes & Tutorial
    local srcProg = if typeof(raw.Progression) == "table" then raw.Progression else raw
    if typeof(srcProg) == "table" then
        local totalXP = safeNonNegInt(srcProg.TotalXP or srcProg.XP, 0, 10000000)
        local level = ProgressionConfig.GetLevelForTotalXP(totalXP)
        local floorXP = ProgressionConfig.GetXPThreshold(level)
        local nextThreshold = ProgressionConfig.GetXPThreshold(math.min(level + 1, ProgressionConfig.MaxLevel))

        profile.Progression.TotalXP = totalXP
        profile.Progression.Level = level
        profile.Progression.Title = ProgressionConfig.GetTitleForLevel(level)
        profile.Progression.XP = math.max(0, totalXP - floorXP)
        profile.Progression.NextLevelXP = if level >= ProgressionConfig.MaxLevel then 0 else (nextThreshold - floorXP)

        profile.Progression.TotalSales = safeNonNegInt(srcProg.TotalSales, 0, 10000000)
        profile.Progression.TotalEarnings = safeNonNegInt(srcProg.TotalEarnings, 0, 1000000000)

        local unlockedSrc = srcProg.UnlockedRecipes or raw.UnlockedRecipes
        if typeof(unlockedSrc) == "table" then
            for k, v in pairs(unlockedSrc) do
                local recId = if typeof(k) == "number" and typeof(v) == "string" then v else (if v == true and typeof(k) == "string" then k else nil)
                if recId and RecipesConfig.GetRecipe(recId) then
                    profile.Progression.UnlockedRecipes[recId] = true
                end
            end
        end
        profile.Progression.UnlockedRecipes["bakwan_sayur"] = true

        local sel = srcProg.SelectedRecipeId
        if typeof(sel) == "string" and profile.Progression.UnlockedRecipes[sel] then
            profile.Progression.SelectedRecipeId = sel
        end

        profile.Progression.TutorialStep = math.clamp(safeNonNegInt(srcProg.TutorialStep, 1, 6), 1, 6)
        profile.Progression.TutorialCompleted = srcProg.TutorialCompleted == true
        profile.Progression.TutorialSkipped = srcProg.TutorialSkipped == true
    end

    -- 6. Chili Collection
    if typeof(raw.ChiliCollection) == "table" then
        local cc = raw.ChiliCollection
        profile.ChiliCollection.TotalRolls = safeNonNegInt(cc.TotalRolls, 0, 1000000)
        profile.ChiliCollection.PityCounter = math.clamp(safeNonNegInt(cc.PityCounter, 0), 0, ChiliGachaConfig.PityThreshold)
        if typeof(cc.OwnedChilis) == "table" then
            for chiliId, entry in pairs(cc.OwnedChilis) do
                if typeof(chiliId) == "string" and ChiliGachaConfig.GetChili(chiliId) and typeof(entry) == "table" then
                    local cnt = safeNonNegInt(entry.Count, 0, 100000)
                    if cnt > 0 then
                        profile.ChiliCollection.OwnedChilis[chiliId] = {
                            Count = cnt,
                            FirstObtainedAt = safeNonNegInt(entry.FirstObtainedAt, os.time()),
                        }
                    end
                end
            end
        end
        if typeof(cc.EquippedChiliId) == "string" and profile.ChiliCollection.OwnedChilis[cc.EquippedChiliId] then
            profile.ChiliCollection.EquippedChiliId = cc.EquippedChiliId
        end
    end

    -- 7. Stats
    if typeof(raw.Stats) == "table" then
        local st = raw.Stats
        profile.Stats.TotalCooked = safeNonNegInt(st.TotalCooked, 0)
        profile.Stats.TotalCrispy = safeNonNegInt(st.TotalCrispy, 0)
        profile.Stats.TotalUndercooked = safeNonNegInt(st.TotalUndercooked, 0)
        profile.Stats.TotalBurnt = safeNonNegInt(st.TotalBurnt, 0)
        profile.Stats.RaidsSurvived = safeNonNegInt(st.RaidsSurvived, 0)
        profile.Stats.RaidsCaptured = safeNonNegInt(st.RaidsCaptured, 0)
        profile.Stats.PlayTimeSeconds = safeNonNegInt(st.PlayTimeSeconds, 0)
        profile.Stats.FirstJoinedAt = safeNonNegInt(st.FirstJoinedAt, profile.Stats.FirstJoinedAt)
        profile.Stats.LastSavedAt = safeNonNegInt(st.LastSavedAt, 0)
    end

    profile.SchemaVersion = DataConfig.CurrentSchemaVersion
    return profile, migrated
end

function DataService:SetStoreAdapter(adapter: StoreAdapter?)
    self._storeAdapter = adapter
    self._dataStoreAvailable = adapter ~= nil
end

function DataService:IsDataStoreAvailable(): boolean
    return self._dataStoreAvailable and self._storeAdapter ~= nil
end

function DataService:GetDiagnostics()
    return table.clone(self._sessionStats)
end

function DataService:RegisterDomain(name: string, applyFn: (Player, PlayerSaveProfile) -> (), collectFn: (Player, PlayerSaveProfile) -> (), cleanupFn: ((number) -> ())?)
    if not self._domains[name] then
        table.insert(self._domainOrder, name)
    end
    self._domains[name] = {
        Apply = applyFn,
        Collect = collectFn,
        Cleanup = cleanupFn,
    }

    -- Jika ada pemain yang sudah ter-load sebelum service ini terdaftar, terapkan sekarang
    for _, player in Players:GetPlayers() do
        local profile = self._profiles[player.UserId]
        if profile and self._loadedFlags[player.UserId] then
            local ok, err = pcall(applyFn, player, profile)
            if not ok then
                log:Error("Gagal menerapkan domain '%s' untuk %s: %s", name, player.Name, tostring(err))
            end
        end
    end
end

function DataService:Init()
    log:Info("Menginisialisasi DataService (Schema v%d)...", DataConfig.CurrentSchemaVersion)

    if not self._storeAdapter then
        local ok, storeOrErr = pcall(function()
            return DataStoreService:GetDataStore(DataConfig.DataStoreName)
        end)
        if ok and storeOrErr then
            self._storeAdapter = storeOrErr :: any
            self._dataStoreAvailable = true
        else
            log:Warn("DataStoreService tidak tersedia (place belum dipublish / mode lokal): %s", tostring(storeOrErr))
            self._dataStoreAvailable = false
        end
    end

    Players.PlayerAdded:Connect(function(player: Player)
        self:LoadPlayerData(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self:HandlePlayerLeaving(player)
    end)

    for _, player in Players:GetPlayers() do
        task.spawn(function()
            self:LoadPlayerData(player)
        end)
    end

    if RunService:IsRunning() then
        game:BindToClose(function()
            self:HandleServerShutdown()
        end)
    end
end

function DataService:Start()
    self._autoSaveRunning = true
    task.spawn(function()
        while self._autoSaveRunning do
            task.wait(DataConfig.AutoSaveIntervalSeconds)
            if not self._autoSaveRunning then break end
            self:RunAutoSaveCycle()
        end
    end)
    log:Info("DataService aktif (AutoSave=%ds, RetryMaks=%d, Schema=v%d).", DataConfig.AutoSaveIntervalSeconds, DataConfig.RetryMaxAttempts, DataConfig.CurrentSchemaVersion)
end

function DataService:GetProfile(player: Player): PlayerSaveProfile?
    return self._profiles[player.UserId]
end

function DataService:MarkDirty(player: Player, _reason: string?)
    if self._profiles[player.UserId] then
        self._dirtyFlags[player.UserId] = true
    end
end

function DataService:RecordCookStat(player: Player, quality: string)
    local profile = self._profiles[player.UserId]
    if not profile then return end
    profile.Stats.TotalCooked += 1
    if quality == "Crispy" then
        profile.Stats.TotalCrispy += 1
    elseif quality == "Undercooked" then
        profile.Stats.TotalUndercooked += 1
    elseif quality == "Burnt" then
        profile.Stats.TotalBurnt += 1
    end
    self._dirtyFlags[player.UserId] = true
end

function DataService:RecordRaidStat(player: Player, captured: boolean)
    local profile = self._profiles[player.UserId]
    if not profile then return end
    if captured then
        profile.Stats.RaidsCaptured += 1
    else
        profile.Stats.RaidsSurvived += 1
    end
    self._dirtyFlags[player.UserId] = true
end

function DataService:_applyDomainsToPlayer(player: Player, profile: PlayerSaveProfile)
    for _, domainName in ipairs(self._domainOrder) do
        local handler = self._domains[domainName]
        if handler then
            local ok, err = pcall(handler.Apply, player, profile)
            if not ok then
                log:Error("Error apply domain '%s' untuk %s: %s", domainName, player.Name, tostring(err))
            end
        end
    end
end

function DataService:_collectDomainsFromPlayer(player: Player, profile: PlayerSaveProfile)
    for _, domainName in ipairs(self._domainOrder) do
        local handler = self._domains[domainName]
        if handler then
            local ok, err = pcall(handler.Collect, player, profile)
            if not ok then
                log:Error("Error collect domain '%s' untuk %s: %s", domainName, player.Name, tostring(err))
            end
        end
    end
end

function DataService:LoadPlayerData(player: Player): (boolean, PlayerSaveProfile)
    local userId = player.UserId
    if self._profiles[userId] and self._loadedFlags[userId] then
        return true, self._profiles[userId]
    end
    if self._loadingLocks[userId] then
        while self._loadingLocks[userId] do
            task.wait(0.05)
        end
        if self._profiles[userId] then
            return true, self._profiles[userId]
        end
    end

    self._loadingLocks[userId] = true
    self._sessionJoinTime[userId] = os.clock()

    local profile = DataService.CreateDefaultProfile()
    local loadSuccess = false
    local migrated = false

    if self._dataStoreAvailable and self._storeAdapter then
        local key = "Player_" .. tostring(userId)
        for attempt = 1, DataConfig.RetryMaxAttempts do
            local ok, resultOrErr = pcall(function()
                return self._storeAdapter:UpdateAsync(key, function(existing: any)
                    local sanitized, wasMigrated = DataService.MigrateAndSanitize(existing)
                    migrated = wasMigrated

                    local nowUnix = os.time()
                    local existingLock = sanitized.Meta.SessionLock
                    if existingLock and existingLock.JobId ~= SERVER_SESSION_ID then
                        local age = nowUnix - existingLock.LockedAt
                        if age < DataConfig.SessionLockTimeoutSeconds then
                            error("SESSION_LOCKED_BY_" .. tostring(existingLock.JobId))
                        end
                    end

                    sanitized.Meta.SessionLock = {
                        JobId = SERVER_SESSION_ID,
                        LockedAt = nowUnix,
                    }
                    return sanitized
                end)
            end)

            if ok and typeof(resultOrErr) == "table" then
                profile = resultOrErr :: PlayerSaveProfile
                loadSuccess = true
                self._sessionStats.LoadsSucceeded += 1
                if migrated then
                    self._sessionStats.MigrationsRun += 1
                    log:Info("Migrasi skema profil %s ke v%d berhasil.", player.Name, DataConfig.CurrentSchemaVersion)
                end
                break
            else
                log:Warn("Gagal memuat profil %s (percobaan %d/%d): %s", player.Name, attempt, DataConfig.RetryMaxAttempts, tostring(resultOrErr))
                if attempt < DataConfig.RetryMaxAttempts then
                    task.wait(DataConfig.RetryBaseDelaySeconds * (2 ^ (attempt - 1)))
                end
            end
        end

        if not loadSuccess then
            self._sessionStats.LoadsFailed += 1
            log:Error("Seluruh percobaan load DataStore gagal untuk %s. Memakai profil sementara aman (read-only/fallback).", player.Name)
        end
    else
        loadSuccess = true
    end

    -- Jika pemain sudah terputus saat proses load asinkron berjalan, hentikan hidrasi
    if player.Parent ~= Players then
        self._loadingLocks[userId] = nil
        return loadSuccess, profile
    end

    self._profiles[userId] = profile
    self._loadedFlags[userId] = true
    self._dirtyFlags[userId] = migrated
    self._loadingLocks[userId] = nil

    self:_applyDomainsToPlayer(player, profile)
    log:Info("Profil %s siap (Lv.%d | Kas: Rp %d | Bank: Rp %d | LoadOk=%s).", player.Name, profile.Progression.Level, profile.Economy.CarriedCash, profile.Economy.BankedCash, tostring(loadSuccess))
    return loadSuccess, profile
end

function DataService:SavePlayerData(player: Player, releaseLock: boolean?): boolean
    local userId = player.UserId
    local profile = self._profiles[userId]
    if not profile then
        return false
    end

    -- Tunggu jika sedang menyimpan agar tidak terjadi save paralel ganda
    while self._savingLocks[userId] do
        task.wait(0.05)
    end

    if not releaseLock and not self._dirtyFlags[userId] then
        return true
    end

    local nowClock = os.clock()
    if not releaseLock then
        local lastTry = self._lastSaveAttempt[userId] or 0
        if (nowClock - lastTry) < DataConfig.MinSaveIntervalSeconds then
            return true
        end
    end

    self._savingLocks[userId] = true
    self._lastSaveAttempt[userId] = nowClock

    -- Kumpulkan snapshot terbaru dari semua layanan server
    self:_collectDomainsFromPlayer(player, profile)

    if self._sessionJoinTime[userId] then
        local elapsedPlay = math.max(0, math.floor(nowClock - self._sessionJoinTime[userId]))
        profile.Stats.PlayTimeSeconds += elapsedPlay
        self._sessionJoinTime[userId] = nowClock
    end

    profile.SchemaVersion = DataConfig.CurrentSchemaVersion
    profile.Stats.LastSavedAt = os.time()
    profile.Meta.SaveCount += 1
    if releaseLock then
        profile.Meta.SessionLock = nil
    else
        profile.Meta.SessionLock = {
            JobId = SERVER_SESSION_ID,
            LockedAt = os.time(),
        }
    end

    if not self._dataStoreAvailable or not self._storeAdapter then
        self._dirtyFlags[userId] = nil
        self._savingLocks[userId] = nil
        return false
    end

    local snapshot = deepCopy(profile) :: PlayerSaveProfile
    local key = "Player_" .. tostring(userId)
    local saved = false

    for attempt = 1, DataConfig.RetryMaxAttempts do
        local ok, err = pcall(function()
            self._storeAdapter:UpdateAsync(key, function(existing: any)
                if typeof(existing) == "table" and typeof(existing.Meta) == "table" then
                    -- Tolak penulisan jika ada sesi server lain yang masih memegang lock aktif atau SaveCount lebih tinggi
                    local lock = existing.Meta.SessionLock
                    if lock and typeof(lock.JobId) == "string" and lock.JobId ~= SERVER_SESSION_ID then
                        if typeof(lock.LockedAt) == "number" and (os.time() - lock.LockedAt) < DataConfig.SessionLockTimeoutSeconds then
                            error("STALE_SESSION_LOCK_CONFLICT")
                        end
                    end
                    if typeof(existing.Meta.SaveCount) == "number" and existing.Meta.SaveCount >= snapshot.Meta.SaveCount then
                        return nil -- Hindari menimpa data yang lebih baru
                    end
                end
                return snapshot
            end)
        end)

        if ok then
            saved = true
            self._dirtyFlags[userId] = nil
            self._sessionStats.SavesSucceeded += 1
            log:Info("Profil %s tersimpan aman ke DataStore (SaveCount #%d, ReleaseLock=%s).", player.Name, snapshot.Meta.SaveCount, tostring(releaseLock == true))
            break
        else
            log:Warn("Simpan DataStore %s gagal (percobaan %d/%d): %s", player.Name, attempt, DataConfig.RetryMaxAttempts, tostring(err))
            if attempt < DataConfig.RetryMaxAttempts then
                task.wait(DataConfig.RetryBaseDelaySeconds * (2 ^ (attempt - 1)))
            end
        end
    end

    if not saved then
        self._sessionStats.SavesFailed += 1
        log:Error("KRITIS: Gagal menyimpan data %s ke DataStore setelah %d percobaan!", player.Name, DataConfig.RetryMaxAttempts)
    end

    self._savingLocks[userId] = nil
    return saved
end

function DataService:RunAutoSaveCycle()
    for _, player in Players:GetPlayers() do
        if self._dirtyFlags[player.UserId] then
            task.spawn(function()
                self:SavePlayerData(player, false)
            end)
        end
    end
end

function DataService:HandlePlayerLeaving(player: Player): boolean
    local userId = player.UserId
    -- Tunggu jika load masih berjalan supaya data baru tidak hilang
    while self._loadingLocks[userId] do
        task.wait(0.05)
    end

    local saved = self:SavePlayerData(player, true)

    -- Setelah tersimpan aman, bersihkan cache memori di seluruh domain terdaftar
    for _, domainName in ipairs(self._domainOrder) do
        local handler = self._domains[domainName]
        if handler and handler.Cleanup then
            pcall(handler.Cleanup, userId)
        end
    end

    self._profiles[userId] = nil
    self._dirtyFlags[userId] = nil
    self._lastSaveAttempt[userId] = nil
    self._sessionJoinTime[userId] = nil
    self._loadedFlags[userId] = nil
    return saved
end

function DataService:HandleServerShutdown()
    self._autoSaveRunning = false
    log:Info("Server shutdown terdeteksi (BindToClose): menyimpan seluruh profil pemain...")

    local activePlayers = Players:GetPlayers()
    local remaining = #activePlayers
    if remaining == 0 then
        return
    end

    for _, player in activePlayers do
        task.spawn(function()
            self:SavePlayerData(player, true)
            remaining -= 1
        end)
    end

    local deadline = os.clock() + 10
    while remaining > 0 and os.clock() < deadline do
        task.wait(0.1)
    end
    log:Info("BindToClose selesai menyimpan data pemain.")
end

return DataService
