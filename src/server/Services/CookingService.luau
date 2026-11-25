--!strict
--[[
    CookingService.luau
    Layanan otoritatif server untuk memproses siklus memasak gorengan.
    Menerapkan validasi bahan, perhitungan waktu elapsed berbasis os.clock(),
    dan penentuan kualitas kematangan sesuai GDD:
    - Undercooked : 0–30%
    - Crispy      : 31–80% (Optimal)
    - Burnt       : 81–100%+ (Senjata lempar)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ActiveCookingBatch = GameplayTypes.ActiveCookingBatch & { CrispyUpperBonus: number? }
type QualityResult = GameplayTypes.QualityResult

local log = Logger.new("CookingService")

local CookingService = {
    Name = "CookingService",
    _activeBatches = {} :: { [number]: ActiveCookingBatch },
    _services = {} :: { [string]: any },
}

function CookingService:_getService(serviceName: string): any
    if not self._services[serviceName] and script and script.Parent then
        local mod = script.Parent:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

function CookingService:Init()
    log:Info("Menginisialisasi CookingService...")

    -- Daftarkan handler permintaan memasak
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestStartCooking, function(player: Player, recipeId: any)
        if typeof(recipeId) ~= "string" or #recipeId == 0 or #recipeId > 40 then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:HandleStartCooking(player, recipeId)
    end)

    -- Daftarkan handler permintaan mengangkat makanan
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestCollectFood, function(player: Player)
        return self:HandleCollectFood(player)
    end)

    -- Bersihkan batch jika pemain disconnect saat memasak
    Players.PlayerRemoving:Connect(function(player: Player)
        self._activeBatches[player.UserId] = nil
    end)
end

function CookingService:Start()
    -- Ambil referensi ke service lain yang dibutuhkan
    self:_getService("InventoryService")
    self:_getService("CartService")
    self:_getService("GameService")
    self:_getService("TutorialService")
    self:_getService("EconomyService")
    self:_getService("ProgressionService")

    log:Info("CookingService aktif dan terhubung dengan InventoryService, EconomyService & ProgressionService.")
end

function CookingService:HandleStartCooking(player: Player, recipeId: string): { Success: boolean, Error: string?, StartTime: number?, Duration: number? }
    local userId = player.UserId

    -- 0. Validasi anti-ragdoll & jarak wajar dari gerobak sendiri
    local throwable = self:_getService("ThrowableService")
    if throwable and throwable.IsPlayerRagdolled and throwable:IsPlayerRagdolled(player) then
        return { Success = false, Error = "Kamu masih sempoyongan dan tidak bisa memasak!" }
    end

    local cartServiceCheck = self:_getService("CartService")
    if cartServiceCheck and cartServiceCheck.GetCartPosition and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        local cPos = cartServiceCheck:GetCartPosition(player)
        if hrp and cPos and (hrp.Position - cPos).Magnitude > 20 then
            return { Success = false, Error = "Terlalu jauh dari gerobakmu untuk memasak!" }
        end
    end

    -- 1. Periksa apakah wajan sedang aktif memasak
    if self._activeBatches[userId] and not self._activeBatches[userId].IsCompleted then
        return { Success = false, Error = "Wajan sedang digunakan! Angkat gorengan terlebih dahulu." }
    end

    -- 2. Ambil data resep & validasi unlock progression
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if not recipe then
        return { Success = false, Error = "Resep gorengan tidak terdaftar!" }
    end

    local progService = self:_getService("ProgressionService")
    if progService and progService.IsRecipeUnlocked and not progService:IsRecipeUnlocked(player, recipeId) then
        return { Success = false, Error = "Resep " .. recipe.Name .. " belum dibuka! Buka terlebih dahulu di Buku Resep." }
    end

    -- 3. Validasi kapasitas etalase & bahan baku di inventaris pemain
    local inventoryService = self:_getService("InventoryService")
    if inventoryService.HasEtalaseSpace and not inventoryService:HasEtalaseSpace(player) then
        return { Success = false, Error = "Etalase penuh! Layani pembeli atau upgrade Etalase 2 Tingkat." }
    end
    if not inventoryService:HasIngredients(player, recipe.RequiredIngredients) then
        return { Success = false, Error = "Bahan baku tidak mencukupi! Beli stok di Toko Bahan." }
    end

    -- 4. Hitung bonus upgrade Wajan & Kompor secara otoritatif
    local speedMult = 1.0
    local crispyUpperBonus = 0.0
    local ecoService = self:_getService("EconomyService")
    if ecoService and ecoService.HasUpgrade then
        if ecoService:HasUpgrade(player, "wajan_jumbo") then speedMult += 0.15 end
        if ecoService:HasUpgrade(player, "kompor_turbo") then
            speedMult += 0.15
            crispyUpperBonus += 0.12
        end
        if ecoService:HasUpgrade(player, "wajan_anti_lengket") then
            speedMult += 0.10
            crispyUpperBonus += 0.08
        end
        if ecoService:HasUpgrade(player, "kompor_mawar") then speedMult += 0.20 end
    end

    local chiliService = self:_getService("ChiliService")
    if chiliService and chiliService.GetEquippedCookSpeedBonus then
        speedMult += chiliService:GetEquippedCookSpeedBonus(player)
    end

    local effectiveDuration = math.max(3.0, recipe.TotalCookDuration / speedMult)
    local effectiveCrispyMax = math.min(recipe.CrispyMaxPercent + crispyUpperBonus, 0.94)

    -- 5. Potong bahan secara atomik
    local deducted = inventoryService:DeductIngredients(player, recipe.RequiredIngredients)
    if not deducted then
        return { Success = false, Error = "Gagal memproses pengurangan bahan!" }
    end

    -- 6. Mulai batch memasak di server
    local now = os.clock()
    local gameService = self:_getService("GameService")
    local plotId = if gameService then (gameService:GetPlayerPlot(player) or 1) else 1

    local batch: ActiveCookingBatch = {
        PlayerId = userId,
        PlotId = plotId,
        RecipeId = recipeId,
        StartTime = now,
        TotalCookDuration = effectiveDuration,
        IsCompleted = false,
        CrispyUpperBonus = crispyUpperBonus,
    }

    self._activeBatches[userId] = batch
    log:Info("Pemain %s mulai menggoreng %s (Durasi Efektif: %.1f s, SpeedMult: %.2fx)", player.Name, recipe.Name, effectiveDuration, speedMult)

    -- 7. Perbarui visual makanan dan partikel minyak pada model gerobak fisik
    local cartService = self:_getService("CartService")
    if cartService then
        cartService:UpdateCartFoodVisual(player, "Cooking", 0.0)
    end

    -- Loop pembaruan visual kematangan di gerobak selama proses masak
    task.spawn(function()
        while self._activeBatches[userId] == batch and not batch.IsCompleted do
            task.wait(0.25)
            local currentElapsed = os.clock() - batch.StartTime
            local progress = math.clamp(currentElapsed / effectiveDuration, 0, 1.2)
            if cartService then
                cartService:UpdateCartFoodVisual(player, "Cooking", progress)
            end
        end
    end)

    -- 8. Kirim sinyal event ke client untuk memicu timing gauge HUD dengan batas dinamis
    NetworkBridge.FireClient(player, Remotes.Events.CookStateChanged, "Cooking", recipeId, now, effectiveDuration, recipe.UndercookedMaxPercent, effectiveCrispyMax)

    return { Success = true, StartTime = now, Duration = effectiveDuration }
end

function CookingService:HandleCollectFood(player: Player): { Success: boolean, Error: string?, Quality: QualityResult?, RecipeId: string? }
    local userId = player.UserId
    local batch = self._activeBatches[userId]

    if not batch or batch.IsCompleted then
        return { Success = false, Error = "Tidak ada masakan yang sedang digoreng di wajan!" }
    end

    batch.IsCompleted = true
    local elapsed = os.clock() - batch.StartTime

    local recipe = RecipesConfig.GetRecipe(batch.RecipeId)
    assert(recipe, "Resep batch tidak ditemukan")

    -- Evaluasi kualitas kematangan berdasarkan durasi efektif & bonus zona crispy
    local quality, progress = RecipesConfig.EvaluateQuality(recipe, elapsed, batch.TotalCookDuration, batch.CrispyUpperBonus)

    log:Info("Pemain %s mengangkat '%s' pada %.2f s (Progress: %.1f%%) -> Kualitas: %s", player.Name, batch.RecipeId, elapsed, progress * 100, quality)

    -- Simpan hasil gorengan ke etalase inventaris pemain
    local inventoryService = self:_getService("InventoryService")
    if inventoryService then
        inventoryService:AddCookedFood(player, batch.RecipeId, quality, 1)
    end

    -- Tambah XP memasak di ProgressionService
    local progService = self:_getService("ProgressionService")
    if progService and progService.AddXP then
        local xpGain = ProgressionConfig.XPRewards.CookBurnt
        if quality == "Crispy" then
            xpGain = ProgressionConfig.XPRewards.CookCrispy
        elseif quality == "Undercooked" then
            xpGain = ProgressionConfig.XPRewards.CookUndercooked
        end
        progService:AddXP(player, xpGain, "Masak " .. recipe.Name .. " (" .. quality .. ")")
    end

    local dataService = self:_getService("DataService")
    if dataService and dataService.RecordCookStat then
        dataService:RecordCookStat(player, quality)
    end

    -- Matikan partikel dan kosongkan visual wajan di gerobak
    local cartService = self:_getService("CartService")
    if cartService then
        cartService:UpdateCartFoodVisual(player, "Empty", 0.0)
    end

    -- Beri sinyal selesai ke client
    NetworkBridge.FireClient(player, Remotes.Events.CookStateChanged, "Empty", batch.RecipeId, os.clock(), 0, 0.30, 0.80)
    NetworkBridge.FireClient(player, Remotes.Events.FoodCollected, quality, batch.RecipeId)

    local ts = self:_getService("TutorialService")
    if ts and ts.OnFoodCollected then
        ts:OnFoodCollected(player, quality)
    end

    self._activeBatches[userId] = nil
    return { Success = true, Quality = quality, RecipeId = batch.RecipeId }
end

return CookingService
