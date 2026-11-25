--!strict
--[[
    SocialService.luau
    Layanan otoritatif server untuk sistem Multiplayer & Sosial:
    1. Kompetisi Pendapatan Sesi & Leaderboard Real-Time (+ Roblox leaderstats)
    2. Interaksi Antargerobak (Inspeksi etalase tetangga & Beli gorengan Crispy antarpemain)
    3. Reaksi Sosial Antarpemain (Jempol, Semangat, Awas Satpol) dengan anti-spam cooldown
    4. Event Kompetisi Server-Wide ("Lomba Omzet Gerobak") & sinkronisasi late-joiner
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type LeaderboardEntry = GameplayTypes.LeaderboardEntry
type CartVisitSummary = GameplayTypes.CartVisitSummary

local log = Logger.new("SocialService")

local BUY_COOLDOWN = GameConfig.SocialBuyCooldownSeconds or 2.0
local REACTION_COOLDOWN = GameConfig.SocialReactionCooldownSeconds or 10.0
local NEIGHBOR_BONUS = GameConfig.CartNeighborBonusCash or 250
local BROADCAST_THROTTLE = GameConfig.LeaderboardBroadcastThrottleSeconds or 1.0
local COMPETITION_DURATION = GameConfig.CompetitionEventDurationSeconds or 45
local MAX_INTERACTION_DIST = (GameConfig.InteractionMaxDistance or 16) + 2

local ALLOWED_REACTIONS: { [string]: { Label: string, Icon: string, RepBonus: number } } = {
    jempol = { Label = "Mantap Banget!", Icon = "👍", RepBonus = 2 },
    semangat = { Label = "Semangat Jualan!", Icon = "🔥", RepBonus = 1 },
    awas_satpol = { Label = "Awas Ada Satpol!", Icon = "🚨", RepBonus = 0 },
}

local SocialService = {
    Name = "SocialService",
    _buyCooldowns = {} :: { [number]: number },
    _reactionCooldowns = {} :: { [string]: number },
    _reactionsCount = {} :: { [number]: number },
    _currentLeaderUserId = nil :: number?,
    _broadcastScheduled = false,
    _lastBroadcastTime = 0,
    _competitionActive = false,
    _competitionEndsAt = 0,
    _competitionToken = 0,
    _services = {} :: { [string]: any },
}

function SocialService:_getService(serviceName: string): any
    if not self._services[serviceName] and script and script.Parent then
        local mod = script.Parent:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

function SocialService:_setupLeaderstats(player: Player)
    if player:FindFirstChild("leaderstats") then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "leaderstats"
    folder.Parent = player

    local omzet = Instance.new("IntValue")
    omzet.Name = "Omzet"
    omzet.Value = 0
    omzet.Parent = folder

    local kas = Instance.new("IntValue")
    kas.Name = "Kas"
    kas.Value = 0
    kas.Parent = folder

    local level = Instance.new("IntValue")
    level.Name = "Level"
    level.Value = 1
    level.Parent = folder
end

function SocialService:Init()
    log:Info("Menginisialisasi SocialService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupLeaderstats(player)
        self._reactionsCount[player.UserId] = 0
        task.defer(function()
            self:RefreshPlayerStats(player)
            self:ScheduleLeaderboardBroadcast()
            if self._competitionActive then
                local rem = math.max(1, math.ceil(self._competitionEndsAt - os.clock()))
                NetworkBridge.FireClient(player, Remotes.Events.ServerCompetitionEvent, true, rem, "LOMBA OMZET GEROBAK (+20% Bonus Penjualan)!")
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        local userId = player.UserId
        self._buyCooldowns[userId] = nil
        self._reactionsCount[userId] = nil

        -- Bersihkan pasangan cooldown reaksi yang melibatkan pemain ini
        local prefix = tostring(userId) .. "_"
        local suffix = "_" .. tostring(userId)
        for key in pairs(self._reactionCooldowns) do
            if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then
                self._reactionCooldowns[key] = nil
            end
        end

        if self._currentLeaderUserId == userId then
            self._currentLeaderUserId = nil
        end
        task.defer(function()
            self:BroadcastLeaderboard()
        end)
    end)

    for _, player in Players:GetPlayers() do
        self:_setupLeaderstats(player)
        self._reactionsCount[player.UserId] = self._reactionsCount[player.UserId] or 0
    end

    -- 1. Remote: Ambil Leaderboard Peringkat Kompetisi
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetLeaderboard, function(_player: Player)
        return {
            Success = true,
            Entries = self:GetLeaderboard(),
            CompetitionActive = self._competitionActive,
            CompetitionRemaining = if self._competitionActive then math.max(0, math.ceil(self._competitionEndsAt - os.clock())) else 0,
        }
    end)

    -- 2. Remote: Inspeksi Etalase Gerobak Tetangga
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestInspectPlayerCart, function(player: Player, targetUserId: any)
        if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId or math.floor(targetUserId) ~= targetUserId then
            return { Success = false, Error = "Target pemilik gerobak tidak valid!" }
        end
        return self:InspectPlayerCart(player, targetUserId)
    end)

    -- 3. Remote: Beli Gorengan Crispy dari Gerobak Pemain Lain
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestBuyFromPlayerCart, function(player: Player, targetUserId: any, recipeId: any)
        if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId or math.floor(targetUserId) ~= targetUserId then
            return { Success = false, Error = "Target pemilik gerobak tidak valid!" }
        end
        if typeof(recipeId) ~= "string" or #recipeId == 0 or #recipeId > 40 then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:BuyFromPlayerCart(player, targetUserId, recipeId)
    end)

    -- 4. Remote: Kirim Reaksi Sosial ke Gerobak / Pemain Lain
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestSendSocialReaction, function(player: Player, targetUserId: any, reactionId: any)
        if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId or math.floor(targetUserId) ~= targetUserId then
            return { Success = false, Error = "Target pemain tidak valid!" }
        end
        if typeof(reactionId) ~= "string" or #reactionId > 30 then
            return { Success = false, Error = "Jenis reaksi tidak valid!" }
        end
        return self:SendSocialReaction(player, targetUserId, reactionId)
    end)

    -- 5. Remote: Pemicuan / Penghentian Event Kompetisi Server-Wide (Hanya Studio / Creator)
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestTriggerCompetitionEvent, function(player: Player, action: any)
        if not NetworkBridge.IsAuthorizedAdmin(player) then
            log:Warn("SECURITY: Pemain %s mencoba memicu RequestTriggerCompetitionEvent tanpa izin!", player.Name)
            return { Success = false, Error = "Akses ditolak: perintah khusus admin/Studio!" }
        end
        if action == "Start" then
            return self:StartCompetitionEvent()
        elseif action == "Stop" then
            self:StopCompetitionEvent()
            return { Success = true, Active = false }
        end
        return { Success = false, Error = "Aksi kompetisi tidak dikenali!" }
    end)
end

function SocialService:Start()
    self:_getService("GameService")
    self:_getService("EconomyService")
    self:_getService("InventoryService")
    self:_getService("CartService")
    self:_getService("ProgressionService")
    self:_getService("ThrowableService")

    for _, player in Players:GetPlayers() do
        self:RefreshPlayerStats(player)
    end
    self:BroadcastLeaderboard()
    log:Info("SocialService aktif (Leaderboard, Interaksi Antargerobak & Kompetisi Server-Wide).")
end

function SocialService:IsCompetitionActive(): boolean
    return self._competitionActive
end

function SocialService:StartCompetitionEvent(durationSeconds: number?): { Success: boolean, Duration: number }
    local duration = durationSeconds or COMPETITION_DURATION
    self._competitionToken += 1
    local token = self._competitionToken
    self._competitionActive = true
    self._competitionEndsAt = os.clock() + duration

    log:Info("EVENT SERVER-WIDE DIMULAI: Lomba Omzet Gerobak (%ds, +20%% Bonus Omzet)!", duration)
    NetworkBridge.FireAllClients(Remotes.Events.ServerCompetitionEvent, true, duration, "🏆 LOMBA OMZET GEROBAK! (+20% Bonus Penjualan untuk Semua Pemain!)")
    NetworkBridge.FireAllClients(Remotes.Events.NotificationFired, string.format("🏆 EVENT SERVER: Lomba Omzet Gerobak dimulai (%ds)! Raih omzet tertinggi!", duration), "Success")

    task.delay(duration, function()
        if self._competitionActive and self._competitionToken == token then
            self:StopCompetitionEvent()
        end
    end)

    return { Success = true, Duration = duration }
end

function SocialService:StopCompetitionEvent()
    if not self._competitionActive then
        return
    end
    self._competitionActive = false
    self._competitionEndsAt = 0

    local entries = self:GetLeaderboard()
    local winner = entries[1]
    local winnerMsg = if winner and winner.TotalEarnings > 0
        then string.format("🏆 Lomba Omzet Selesai! Juara sementara: %s (Rp %d)!", winner.PlayerName, winner.TotalEarnings)
        else "🏆 Lomba Omzet Gerobak telah berakhir!"

    NetworkBridge.FireAllClients(Remotes.Events.ServerCompetitionEvent, false, 0, winnerMsg)
    NetworkBridge.FireAllClients(Remotes.Events.NotificationFired, winnerMsg, "Success")
    log:Info("EVENT SERVER-WIDE SELESAI: %s", winnerMsg)
end

function SocialService:RefreshPlayerStats(player: Player)
    if player.Parent ~= Players then return end
    self:_setupLeaderstats(player)

    local ls = player:FindFirstChild("leaderstats")
    if not ls then return end

    local ecoService = self:_getService("EconomyService")
    local progService = self:_getService("ProgressionService")

    local wallet = if ecoService and ecoService.GetWallet then ecoService:GetWallet(player) else nil
    local prog = if progService and progService.GetProgression then progService:GetProgression(player) else nil

    local omzetVal = ls:FindFirstChild("Omzet") :: IntValue?
    local kasVal = ls:FindFirstChild("Kas") :: IntValue?
    local lvlVal = ls:FindFirstChild("Level") :: IntValue?

    if omzetVal and prog then
        omzetVal.Value = math.floor(prog.TotalEarnings or 0)
    end
    if kasVal and wallet then
        kasVal.Value = math.floor(wallet.CarriedCash or 0)
    end
    if lvlVal and prog then
        lvlVal.Value = math.floor(prog.Level or 1)
    end
end

function SocialService:GetLeaderboard(): { LeaderboardEntry }
    local gameService = self:_getService("GameService")
    local ecoService = self:_getService("EconomyService")
    local progService = self:_getService("ProgressionService")

    local list: { LeaderboardEntry } = {}
    for _, player in Players:GetPlayers() do
        local wallet = if ecoService and ecoService.GetWallet then ecoService:GetWallet(player) else nil
        local prog = if progService and progService.GetProgression then progService:GetProgression(player) else nil
        local plotId = if gameService and gameService.GetPlayerPlot then gameService:GetPlayerPlot(player) else nil

        local carried = if wallet then wallet.CarriedCash else 0
        local banked = if wallet then wallet.BankedCash else 0

        table.insert(list, {
            UserId = player.UserId,
            PlayerName = player.Name,
            Rank = 1,
            PlotId = plotId,
            Level = if prog then prog.Level else 1,
            Title = if prog then prog.Title else "Pedagang Pemula",
            TotalEarnings = if prog then prog.TotalEarnings else 0,
            TotalSales = if prog then prog.TotalSales else 0,
            NetWorth = carried + banked,
            Reputation = if wallet then wallet.Reputation else 100,
            IsLeader = false,
        })
    end

    table.sort(list, function(a, b)
        if a.TotalEarnings ~= b.TotalEarnings then
            return a.TotalEarnings > b.TotalEarnings
        end
        if a.TotalSales ~= b.TotalSales then
            return a.TotalSales > b.TotalSales
        end
        if a.NetWorth ~= b.NetWorth then
            return a.NetWorth > b.NetWorth
        end
        return a.UserId < b.UserId
    end)

    for idx, entry in ipairs(list) do
        entry.Rank = idx
        entry.IsLeader = (idx == 1 and entry.TotalEarnings > 0)
    end

    return list
end

function SocialService:ScheduleLeaderboardBroadcast()
    if self._broadcastScheduled then return end
    self._broadcastScheduled = true

    local waitNeeded = math.max(0.05, BROADCAST_THROTTLE - (os.clock() - self._lastBroadcastTime))
    task.delay(waitNeeded, function()
        self._broadcastScheduled = false
        self:BroadcastLeaderboard()
    end)
end

function SocialService:BroadcastLeaderboard()
    self._lastBroadcastTime = os.clock()
    local entries = self:GetLeaderboard()

    local top = entries[1]
    if top and top.TotalEarnings > 0 and #entries >= 2 then
        if self._currentLeaderUserId ~= top.UserId then
            self._currentLeaderUserId = top.UserId
            NetworkBridge.FireAllClients(
                Remotes.Events.NotificationFired,
                string.format("👑 %s memimpin kompetisi omzet #1 (Rp %d)!", top.PlayerName, top.TotalEarnings),
                "Success"
            )
        end
    end

    NetworkBridge.FireAllClients(Remotes.Events.LeaderboardUpdated, entries, self._competitionActive)
end

function SocialService:_validatePlayerPairAndDistance(player: Player, targetUserId: number, maxDist: number): (boolean, Player?, string?)
    if targetUserId == player.UserId then
        return false, nil, "Ini gerobak milikmu sendiri!"
    end

    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if not targetPlayer or targetPlayer.Parent ~= Players then
        return false, nil, "Pemilik gerobak sudah keluar dari permainan!"
    end

    local throwable = self:_getService("ThrowableService")
    if throwable and throwable.IsPlayerRagdolled and throwable:IsPlayerRagdolled(player) then
        return false, nil, "Kamu sedang sempoyongan terkena gorengan gosong!"
    end

    local cartService = self:_getService("CartService")
    local targetCart = if cartService then cartService:GetPlayerCart(targetPlayer) else nil
    if not targetCart then
        return false, nil, "Gerobak pemain target tidak tersedia!"
    end

    local char = player.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if not hrp then
        return false, nil, "Karaktermu belum siap!"
    end

    local cartPos = targetCart:GetPivot().Position
    if (hrp.Position - cartPos).Magnitude > maxDist then
        return false, nil, "Dekati gerobak pemain tersebut terlebih dahulu!"
    end

    return true, targetPlayer, nil
end

function SocialService:InspectPlayerCart(player: Player, targetUserId: number): { Success: boolean, Summary: CartVisitSummary?, Error: string? }
    local ok, targetPlayer, err = self:_validatePlayerPairAndDistance(player, targetUserId, MAX_INTERACTION_DIST)
    if not ok or not targetPlayer then
        return { Success = false, Error = err }
    end

    local invService = self:_getService("InventoryService")
    local ecoService = self:_getService("EconomyService")
    local progService = self:_getService("ProgressionService")
    local gameService = self:_getService("GameService")

    local inv = if invService then invService:GetInventory(targetPlayer) else nil
    local wallet = if ecoService then ecoService:GetWallet(targetPlayer) else nil
    local prog = if progService then progService:GetProgression(targetPlayer) else nil

    local stockByRecipe: { [string]: number } = {}
    local pricesByRecipe: { [string]: number } = {}
    local totalCrispy = 0

    if inv and inv.CookedFood then
        for recipeId, counts in pairs(inv.CookedFood) do
            local crispy = counts.Crispy or 0
            if crispy > 0 then
                stockByRecipe[recipeId] = crispy
                totalCrispy += crispy
                local recipe = RecipesConfig.GetRecipe(recipeId)
                pricesByRecipe[recipeId] = if recipe then recipe.BasePrice else 2200
            end
        end
    end

    local summary: CartVisitSummary = {
        OwnerUserId = targetUserId,
        OwnerName = targetPlayer.Name,
        PlotId = if gameService then gameService:GetPlayerPlot(targetPlayer) else nil,
        Level = if prog then prog.Level else 1,
        Reputation = if wallet then wallet.Reputation else 100,
        StockByRecipe = stockByRecipe,
        TotalCrispy = totalCrispy,
        PricesByRecipe = pricesByRecipe,
        ReactionsCount = self._reactionsCount[targetUserId] or 0,
    }

    return { Success = true, Summary = summary }
end

function SocialService:BuyFromPlayerCart(player: Player, targetUserId: number, recipeId: string): { Success: boolean, Error: string?, PricePaid: number?, RecipeName: string? }
    -- 1. Cek cooldown transaksi antarpemain
    local now = os.clock()
    local buyerId = player.UserId
    local lastBuy = self._buyCooldowns[buyerId] or 0
    if (now - lastBuy) < BUY_COOLDOWN then
        return { Success = false, Error = string.format("Tunggu %.1f detik sebelum membeli dari tetangga lagi!", BUY_COOLDOWN - (now - lastBuy)) }
    end

    -- 2. Validasi target online, jarak, dan status karakter
    local ok, targetPlayer, err = self:_validatePlayerPairAndDistance(player, targetUserId, MAX_INTERACTION_DIST)
    if not ok or not targetPlayer then
        return { Success = false, Error = err }
    end

    -- 3. Validasi resep dan stok Crispy etalase target di server
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if not recipe then
        return { Success = false, Error = "Resep gorengan tidak ditemukan!" }
    end

    local invService = self:_getService("InventoryService")
    local ecoService = self:_getService("EconomyService")
    local progService = self:_getService("ProgressionService")
    if not invService or not ecoService then
        return { Success = false, Error = "Layanan transaksi sedang tidak siap!" }
    end

    local targetInv = invService:GetInventory(targetPlayer)
    local targetStock = if targetInv and targetInv.CookedFood[recipeId] then (targetInv.CookedFood[recipeId].Crispy or 0) else 0
    if targetStock < 1 then
        return { Success = false, Error = string.format("Stok %s Crispy di gerobak %s sedang habis!", recipe.Name, targetPlayer.Name) }
    end

    -- 4. Hitung harga otoritatif server & cek saldo kas pembeli
    local serverPrice = recipe.BasePrice
    local buyerWallet = ecoService:GetWallet(player)
    if not buyerWallet or buyerWallet.CarriedCash < serverPrice then
        return { Success = false, Error = string.format("Uang kas tidak cukup! Harga %s: Rp %d", recipe.Name, serverPrice) }
    end

    -- 5. Kunci cooldown & verifikasi ulang koneksi sebelum commit atomik (cegah race disconnect)
    self._buyCooldowns[buyerId] = now
    if player.Parent ~= Players or targetPlayer.Parent ~= Players then
        return { Success = false, Error = "Transaksi dibatalkan karena salah satu pemain keluar." }
    end

    local deducted = ecoService:DeductCarriedCash(player, serverPrice, "Beli dari Gerobak " .. targetPlayer.Name)
    if not deducted then
        return { Success = false, Error = "Gagal memotong kas pembeli!" }
    end

    local removed = invService:RemoveCookedFood(targetPlayer, recipeId, "Crispy", 1)
    if not removed then
        -- Rollback atomik jika stok tiba-tiba hilang
        ecoService:AddCarriedCash(player, serverPrice, "Refund Transaksi Tetangga Gagal")
        return { Success = false, Error = "Stok gerobak tetangga sudah habis saat diproses!" }
    end

    local sellerPayout = serverPrice + NEIGHBOR_BONUS
    if self._competitionActive then
        sellerPayout = math.floor(sellerPayout * 1.20)
    end
    ecoService:AddCarriedCash(targetPlayer, sellerPayout, "Dibeli Tetangga " .. player.Name)

    if progService then
        progService:RecordSale(targetPlayer, sellerPayout)
        progService:AddXP(targetPlayer, 8, "Jualan ke " .. player.Name)
        progService:AddXP(player, 5, "Icip " .. recipe.Name .. " Tetangga")
    end

    self:RefreshPlayerStats(player)
    self:RefreshPlayerStats(targetPlayer)
    self:ScheduleLeaderboardBroadcast()

    local msg = string.format("🤝 %s membeli %s Crispy dari gerobak %s (+Rp %d)!", player.Name, recipe.Name, targetPlayer.Name, sellerPayout)
    NetworkBridge.FireClient(player, Remotes.Events.NotificationFired, string.format("😋 Kamu mencicipi %s milik %s (-Rp %d, +5 XP)!", recipe.Name, targetPlayer.Name, serverPrice), "Success")
    NetworkBridge.FireClient(targetPlayer, Remotes.Events.NotificationFired, string.format("🤝 %s jajan %s di gerobakmu! +Rp %d & +8 XP!", player.Name, recipe.Name, sellerPayout), "Success")
    NetworkBridge.FireAllClients(Remotes.Events.CartSocialFeedback, targetUserId, "😋 +1 Terjual!", player.Name)
    log:Info(msg)

    return { Success = true, PricePaid = serverPrice, RecipeName = recipe.Name }
end

function SocialService:SendSocialReaction(player: Player, targetUserId: number, reactionId: string): { Success: boolean, Error: string? }
    local reaction = ALLOWED_REACTIONS[reactionId]
    if not reaction then
        return { Success = false, Error = "Jenis reaksi tidak valid!" }
    end
    if targetUserId == player.UserId then
        return { Success = false, Error = "Tidak dapat mengirim reaksi ke diri sendiri!" }
    end

    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if not targetPlayer or targetPlayer.Parent ~= Players then
        return { Success = false, Error = "Pemain target sedang tidak online!" }
    end

    local pairKey = tostring(player.UserId) .. "_" .. tostring(targetUserId)
    local now = os.clock()
    local nextAllowed = self._reactionCooldowns[pairKey] or 0
    if now < nextAllowed then
        return { Success = false, Error = string.format("Tunggu %.0f detik sebelum memberi reaksi lagi ke %s!", nextAllowed - now, targetPlayer.Name) }
    end

    self._reactionCooldowns[pairKey] = now + REACTION_COOLDOWN
    self._reactionsCount[targetUserId] = (self._reactionsCount[targetUserId] or 0) + 1

    if reaction.RepBonus > 0 then
        local ecoService = self:_getService("EconomyService")
        local wallet = if ecoService then ecoService:GetWallet(targetPlayer) else nil
        if wallet then
            wallet.Reputation += reaction.RepBonus
            ecoService:SyncWalletToClient(targetPlayer)
        end
    end

    self:ScheduleLeaderboardBroadcast()
    NetworkBridge.FireClient(targetPlayer, Remotes.Events.NotificationFired, string.format("%s %s mengirim reaksi: %s (+%d Rep)", reaction.Icon, player.Name, reaction.Label, reaction.RepBonus), "Success")
    NetworkBridge.FireClient(player, Remotes.Events.NotificationFired, string.format("%s Reaksi terkirim ke %s!", reaction.Icon, targetPlayer.Name), "Success")
    NetworkBridge.FireAllClients(Remotes.Events.CartSocialFeedback, targetUserId, reaction.Icon .. " " .. reaction.Label, player.Name)

    return { Success = true }
end

return SocialService
