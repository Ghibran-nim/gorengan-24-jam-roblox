--!strict
--[[
    ChiliService.luau
    Layanan otoritatif server untuk sistem Gacha & Koleksi Cabai Nusantara:
    - RNG 100% server-side menggunakan Random.new() terhadap bobot basis-points (10.000)
    - Pity guarantee 15x untuk minimal Rare+ yang transparan
    - Validasi transaksi atomik (potong kas dulu, catat hasil, baru cashback duplikat)
    - Persistensi aman menggunakan DataStoreService:UpdateAsync + proteksi monotonic & fallback lokal
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local ChiliGachaConfig = require(Shared:WaitForChild("Config"):WaitForChild("ChiliGachaConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ChiliCollectionData = GameplayTypes.ChiliCollectionData
type ChiliItem = ChiliGachaConfig.ChiliItem

local log = Logger.new("ChiliService")

local DATASTORE_NAME = "Gorengan24Jam_ChiliCollection_v1"
local ROLL_COOLDOWN_SECONDS = 1.2

local ChiliService = {
    Name = "ChiliService",
    _rng = Random.new(),
    _playerCollections = {} :: { [number]: ChiliCollectionData },
    _rollingLocks = {} :: { [number]: boolean },
    _lastRollTimes = {} :: { [number]: number },
    _dirtyFlags = {} :: { [number]: boolean },
    _dataStore = nil :: DataStore?,
    _dataStoreAvailable = false,
    _services = {} :: { [string]: any },
}

function ChiliService:_getService(serviceName: string): any
    if not self._services[serviceName] and script and script.Parent then
        local mod = script.Parent:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

local function createDefaultCollection(): ChiliCollectionData
    return {
        SchemaVersion = ChiliGachaConfig.SchemaVersion,
        TotalRolls = 0,
        PityCounter = 0,
        EquippedChiliId = nil,
        OwnedChilis = {},
    }
end

local function sanitizeLoadedData(raw: any): ChiliCollectionData
    local clean = createDefaultCollection()
    if typeof(raw) ~= "table" then
        return clean
    end

    clean.TotalRolls = if typeof(raw.TotalRolls) == "number" and raw.TotalRolls >= 0 then math.floor(raw.TotalRolls) else 0
    clean.PityCounter = if typeof(raw.PityCounter) == "number" and raw.PityCounter >= 0 then math.clamp(math.floor(raw.PityCounter), 0, ChiliGachaConfig.PityThreshold) else 0

    if typeof(raw.OwnedChilis) == "table" then
        for chiliId, entry in pairs(raw.OwnedChilis) do
            if typeof(chiliId) == "string" and ChiliGachaConfig.GetChili(chiliId) and typeof(entry) == "table" then
                local cnt = if typeof(entry.Count) == "number" and entry.Count > 0 then math.floor(entry.Count) else 0
                if cnt > 0 then
                    clean.OwnedChilis[chiliId] = {
                        Count = cnt,
                        FirstObtainedAt = if typeof(entry.FirstObtainedAt) == "number" then entry.FirstObtainedAt else os.time(),
                    }
                end
            end
        end
    end

    if typeof(raw.EquippedChiliId) == "string" and clean.OwnedChilis[raw.EquippedChiliId] then
        clean.EquippedChiliId = raw.EquippedChiliId
    end

    return clean
end

function ChiliService:Init()
    log:Info("Menginisialisasi ChiliService...")

    Players.PlayerAdded:Connect(function(player: Player)
        if not self._playerCollections[player.UserId] then
            self._playerCollections[player.UserId] = createDefaultCollection()
            self:SyncCollection(player)
        end
    end)

    for _, player in Players:GetPlayers() do
        if not self._playerCollections[player.UserId] then
            self._playerCollections[player.UserId] = createDefaultCollection()
            self:SyncCollection(player)
        end
    end

    -- RemoteFunctions untuk Client
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetChiliCollection, function(player: Player)
        return { Success = true, Collection = self:GetCollection(player) }
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestRollChiliGacha, function(player: Player)
        return self:RollChiliGacha(player)
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestEquipChili, function(player: Player, chiliId: any)
        if typeof(chiliId) ~= "string" or #chiliId > 40 then
            return { Success = false, Error = "ID cabai tidak valid!" }
        end
        return self:EquipChili(player, chiliId)
    end)
end

function ChiliService:Start()
    self:_getService("EconomyService")
    self:_getService("CartService")
    local dataService = self:_getService("DataService")
    if dataService and dataService.RegisterDomain then
        dataService:RegisterDomain("ChiliCollection",
            function(player: Player, profile: any)
                local col = sanitizeLoadedData(profile.ChiliCollection)
                self._playerCollections[player.UserId] = col
                self:SyncCollection(player)
                if col.EquippedChiliId then
                    local cartService = self:_getService("CartService")
                    if cartService and cartService.ApplyChiliVisuals then
                        cartService:ApplyChiliVisuals(player, col.EquippedChiliId)
                    end
                end
            end,
            function(player: Player, profile: any)
                local col = self._playerCollections[player.UserId]
                if col then
                    profile.ChiliCollection = sanitizeLoadedData(col)
                end
            end,
            function(userId: number)
                self._playerCollections[userId] = nil
                self._rollingLocks[userId] = nil
                self._lastRollTimes[userId] = nil
                self._dirtyFlags[userId] = nil
            end
        )
    end
    log:Info("ChiliService aktif (Server-Authoritative RNG + Terintegrasi DataService).")
end

function ChiliService:_loadPlayerCollection(player: Player)
    local userId = player.UserId
    if self._playerCollections[userId] then return end

    local loadedData: ChiliCollectionData? = nil
    if self._dataStoreAvailable and self._dataStore then
        local key = "Player_" .. tostring(userId)
        local ok, raw = pcall(function()
            return self._dataStore:GetAsync(key)
        end)
        if ok and raw ~= nil then
            loadedData = sanitizeLoadedData(raw)
            log:Info("Koleksi cabai %s berhasil dimuat dari DataStore (%d total roll).", player.Name, loadedData.TotalRolls)
        elseif not ok then
            log:Warn("Gagal membaca DataStore koleksi untuk %s (fallback baru): %s", player.Name, tostring(raw))
        end
    end

    self._playerCollections[userId] = loadedData or createDefaultCollection()
    self:SyncCollection(player)

    local equippedId = self._playerCollections[userId].EquippedChiliId
    if equippedId then
        local cartService = self:_getService("CartService")
        if cartService and cartService.ApplyChiliVisuals then
            cartService:ApplyChiliVisuals(player, equippedId)
        end
    end
end

function ChiliService:SavePlayerCollection(player: Player): boolean
    local userId = player.UserId
    local data = self._playerCollections[userId]
    if not data or not self._dirtyFlags[userId] then
        return true
    end

    if not self._dataStoreAvailable or not self._dataStore then
        self._dirtyFlags[userId] = nil
        return false
    end

    local key = "Player_" .. tostring(userId)
    local snapshot = sanitizeLoadedData(data)

    for attempt = 1, 3 do
        local ok, err = pcall(function()
            self._dataStore:UpdateAsync(key, function(existing: any)
                -- Cegah data lama menimpa progres roll yang lebih tinggi
                if typeof(existing) == "table" and typeof(existing.TotalRolls) == "number" and existing.TotalRolls > snapshot.TotalRolls then
                    return nil -- Batalkan penulisan stale data
                end
                return snapshot
            end)
        end)
        if ok then
            self._dirtyFlags[userId] = nil
            log:Info("Koleksi cabai %s berhasil disimpan aman ke DataStore.", player.Name)
            return true
        end
        log:Warn("Percobaan simpan koleksi %s (#%d) gagal: %s", player.Name, attempt, tostring(err))
        if attempt < 3 then
            task.wait(0.5 * attempt)
        end
    end

    return false
end

function ChiliService:GetCollection(player: Player): ChiliCollectionData
    if not self._playerCollections[player.UserId] then
        self._playerCollections[player.UserId] = createDefaultCollection()
    end
    return self._playerCollections[player.UserId]
end

function ChiliService:SyncCollection(player: Player)
    local col = self._playerCollections[player.UserId]
    if col then
        NetworkBridge.FireClient(player, Remotes.Events.ChiliCollectionUpdated, col)
    end
end

-- ============================================================================
-- SERVER-AUTHORITATIVE RNG ENGINE
-- ============================================================================

function ChiliService:_rollWeightedChili(pityCounter: number): (ChiliItem, boolean)
    local allChilis = ChiliGachaConfig.GetAllChilis()

    -- Aturan Pity Transparan: jika sudah (PityThreshold - 1) roll tanpa Rare+,
    -- tarikan kali ini dijamin masuk pool Rare+ sesuai proporsi bobot aslinya.
    if pityCounter >= (ChiliGachaConfig.PityThreshold - 1) then
        local rarePool: { ChiliItem } = {}
        local rareWeight = 0
        for _, chili in ipairs(allChilis) do
            if ChiliGachaConfig.IsRareOrHigher(chili.Rarity) then
                table.insert(rarePool, chili)
                rareWeight += chili.Weight
            end
        end

        local roll = self._rng:NextInteger(1, math.max(1, rareWeight))
        local acc = 0
        for _, chili in ipairs(rarePool) do
            acc += chili.Weight
            if roll <= acc then
                return chili, true
            end
        end
        return rarePool[1], true
    end

    -- Roll standar terhadap total bobot 10.000 basis points
    local roll = self._rng:NextInteger(1, ChiliGachaConfig.TotalWeight)
    local accumulated = 0
    for _, chili in ipairs(allChilis) do
        accumulated += chili.Weight
        if roll <= accumulated then
            return chili, false
        end
    end

    return allChilis[1], false
end

function ChiliService:RollChiliGacha(player: Player): { Success: boolean, Error: string?, ChiliId: string?, IsDuplicate: boolean?, Cashback: number?, PityTriggered: boolean?, Collection: ChiliCollectionData? }
    local userId = player.UserId

    -- 1. Anti-spam & concurrency lock
    if self._rollingLocks[userId] then
        return { Success = false, Error = "Sedang memproses undian cabai, tunggu sebentar!" }
    end

    local now = os.clock()
    local lastRoll = self._lastRollTimes[userId] or 0
    if (now - lastRoll) < ROLL_COOLDOWN_SECONDS then
        return { Success = false, Error = "Jangan spam gacha! Tunggu sejenak." }
    end

    local ecoService = self:_getService("EconomyService")
    if not ecoService then
        return { Success = false, Error = "Layanan ekonomi tidak tersedia!" }
    end

    local wallet = ecoService:GetWallet(player)
    if not wallet or wallet.CarriedCash < ChiliGachaConfig.RollCost then
        local cash = if wallet then wallet.CarriedCash else 0
        return {
            Success = false,
            Error = string.format("Uang kas tidak cukup! Biaya gacha: Rp %d (Kas kamu: Rp %d)", ChiliGachaConfig.RollCost, cash),
        }
    end

    self._rollingLocks[userId] = true
    self._lastRollTimes[userId] = now

    -- 2. Potong biaya gacha secara atomik terlebih dahulu
    local deducted = ecoService:DeductCarriedCash(player, ChiliGachaConfig.RollCost, "Gacha Cabai Pedas Mampus")
    if not deducted then
        self._rollingLocks[userId] = nil
        return { Success = false, Error = "Gagal memotong biaya gacha!" }
    end

    -- 3. Lakukan RNG 100% di Server
    local collection = self:GetCollection(player)
    local rolledChili, pityTriggered = self:_rollWeightedChili(collection.PityCounter)

    -- 4. Catat hasil di server sebelum memberitahu client
    collection.TotalRolls += 1
    if ChiliGachaConfig.IsRareOrHigher(rolledChili.Rarity) then
        collection.PityCounter = 0
    else
        collection.PityCounter += 1
    end

    local existingEntry = collection.OwnedChilis[rolledChili.Id]
    local isDuplicate = existingEntry ~= nil and existingEntry.Count > 0
    local cashback = 0

    if isDuplicate and existingEntry then
        existingEntry.Count += 1
        cashback = rolledChili.DuplicateCashback
        if cashback > 0 then
            ecoService:AddCarriedCash(player, cashback, "Cashback Duplikat " .. rolledChili.Name)
        end
    else
        collection.OwnedChilis[rolledChili.Id] = {
            Count = 1,
            FirstObtainedAt = os.time(),
        }
    end

    -- Otomatis pasang jika belum memakai cabai atau dapat multiplier lebih tinggi
    local currentEquipped = if collection.EquippedChiliId then ChiliGachaConfig.GetChili(collection.EquippedChiliId) else nil
    if not currentEquipped or rolledChili.ProfitMultiplier > currentEquipped.ProfitMultiplier then
        collection.EquippedChiliId = rolledChili.Id
        local cartService = self:_getService("CartService")
        if cartService and cartService.ApplyChiliVisuals then
            cartService:ApplyChiliVisuals(player, rolledChili.Id)
        end
    end

    self._dirtyFlags[userId] = true
    local dataService = self:_getService("DataService")
    if dataService and dataService.MarkDirty then
        dataService:MarkDirty(player, "ChiliRoll")
    end

    log:Info(
        "GACHA CABAI %s -> %s (%s, %.2fx) | Duplikat=%s | PityTriggered=%s | PityNow=%d/%d",
        player.Name, rolledChili.Name, rolledChili.Rarity, rolledChili.ProfitMultiplier,
        tostring(isDuplicate), tostring(pityTriggered), collection.PityCounter, ChiliGachaConfig.PityThreshold
    )

    local payload = {
        Success = true,
        ChiliId = rolledChili.Id,
        IsDuplicate = isDuplicate,
        Cashback = cashback,
        PityTriggered = pityTriggered,
        Collection = collection,
    }

    NetworkBridge.FireClient(player, Remotes.Events.ChiliGachaRolled, payload)
    self:SyncCollection(player)

    self._rollingLocks[userId] = nil
    return payload
end

function ChiliService:EquipChili(player: Player, chiliId: string): { Success: boolean, Error: string?, EquippedChiliId: string?, Collection: ChiliCollectionData? }
    local chili = ChiliGachaConfig.GetChili(chiliId)
    if not chili then
        return { Success = false, Error = "Jenis cabai tidak dikenali!" }
    end

    local collection = self:GetCollection(player)
    local owned = collection.OwnedChilis[chiliId]
    if not owned or owned.Count < 1 then
        return { Success = false, Error = "Kamu belum memiliki " .. chili.Name .. " di koleksimu!" }
    end

    collection.EquippedChiliId = chiliId
    self._dirtyFlags[player.UserId] = true
    local dataService = self:_getService("DataService")
    if dataService and dataService.MarkDirty then
        dataService:MarkDirty(player, "EquipChili")
    end

    local cartService = self:_getService("CartService")
    if cartService and cartService.ApplyChiliVisuals then
        cartService:ApplyChiliVisuals(player, chiliId)
    end

    self:SyncCollection(player)
    log:Info("Pemain %s memasang cabai '%s' (%s, %.2fx)", player.Name, chili.Name, chili.Rarity, chili.ProfitMultiplier)

    return { Success = true, EquippedChiliId = chiliId, Collection = collection }
end

-- ============================================================================
-- HELPER EFEK GAMEPLAY UNTUK SERVICE LAIN
-- ============================================================================

function ChiliService:GetEquippedChili(player: Player): ChiliItem?
    local col = self._playerCollections[player.UserId]
    if not col or not col.EquippedChiliId then
        return nil
    end
    return ChiliGachaConfig.GetChili(col.EquippedChiliId)
end

function ChiliService:GetEquippedProfitMultiplier(player: Player): number
    local chili = self:GetEquippedChili(player)
    return if chili then chili.ProfitMultiplier else 1.0
end

function ChiliService:GetEquippedCookSpeedBonus(player: Player): number
    local chili = self:GetEquippedChili(player)
    return if chili then chili.CookSpeedBonus else 0.0
end

function ChiliService:GetEquippedXPBonusPercent(player: Player): number
    local chili = self:GetEquippedChili(player)
    return if chili then chili.XPBonusPercent else 0.0
end

return ChiliService