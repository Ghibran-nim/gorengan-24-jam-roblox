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
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ActiveCookingBatch = GameplayTypes.ActiveCookingBatch
type QualityResult = GameplayTypes.QualityResult

local log = Logger.new("CookingService")

local CookingService = {
    Name = "CookingService",
    _activeBatches = {} :: { [number]: ActiveCookingBatch },
    _services = {} :: { [string]: any },
}

function CookingService:Init()
    log:Info("Menginisialisasi CookingService...")

    -- Daftarkan handler permintaan memasak
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestStartCooking, function(player: Player, recipeId: string)
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
    local Server = script.Parent
    self._services.InventoryService = require(Server:WaitForChild("InventoryService"))
    self._services.CartService = require(Server:WaitForChild("CartService"))
    self._services.GameService = require(Server:WaitForChild("GameService"))
    local tsMod = Server:FindFirstChild("TutorialService")
    if tsMod then
        self._services.TutorialService = require(tsMod)
    end

    log:Info("CookingService aktif dan terhubung dengan InventoryService serta CartService.")
end

function CookingService:HandleStartCooking(player: Player, recipeId: string): { Success: boolean, Error: string?, StartTime: number?, Duration: number? }
    local userId = player.UserId

    -- 1. Periksa apakah wajan sedang aktif memasak
    if self._activeBatches[userId] and not self._activeBatches[userId].IsCompleted then
        return { Success = false, Error = "Wajan sedang digunakan! Angkat gorengan terlebih dahulu." }
    end

    -- 2. Ambil data resep
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if not recipe then
        return { Success = false, Error = "Resep gorengan tidak terdaftar!" }
    end

    -- 3. Validasi bahan baku di inventaris pemain
    local inventoryService = self._services.InventoryService
    if not inventoryService:HasIngredients(player, recipe.RequiredIngredients) then
        return { Success = false, Error = "Bahan baku tidak mencukupi! Ambil persediaan di kotak gerobak." }
    end

    -- 4. Potong bahan secara atomik
    local deducted = inventoryService:DeductIngredients(player, recipe.RequiredIngredients)
    if not deducted then
        return { Success = false, Error = "Gagal memproses pengurangan bahan!" }
    end

    -- 5. Mulai batch memasak di server
    local now = os.clock()
    local gameService = self._services.GameService
    local plotId = if gameService then (gameService:GetPlayerPlot(player) or 1) else 1

    local batch: ActiveCookingBatch = {
        PlayerId = userId,
        PlotId = plotId,
        RecipeId = recipeId,
        StartTime = now,
        TotalCookDuration = recipe.TotalCookDuration,
        IsCompleted = false,
    }

    self._activeBatches[userId] = batch
    log:Info("Pemain %s mulai menggoreng %s (Total Durasi: %.1f s)", player.Name, recipe.Name, recipe.TotalCookDuration)

    -- 6. Perbarui visual makanan dan partikel minyak pada model gerobak fisik
    local cartService = self._services.CartService
    if cartService then
        cartService:UpdateCartFoodVisual(player, "Cooking", 0.0)
    end

    -- Loop pembaruan visual kematangan di gerobak selama proses masak
    task.spawn(function()
        while self._activeBatches[userId] == batch and not batch.IsCompleted do
            task.wait(0.25)
            local currentElapsed = os.clock() - batch.StartTime
            local progress = math.clamp(currentElapsed / recipe.TotalCookDuration, 0, 1.2)
            if cartService then
                cartService:UpdateCartFoodVisual(player, "Cooking", progress)
            end
        end
    end)

    -- 7. Kirim sinyal event ke client untuk memicu timing gauge HUD
    NetworkBridge.FireClient(player, Remotes.Events.CookStateChanged, "Cooking", recipeId, now, recipe.TotalCookDuration)

    return { Success = true, StartTime = now, Duration = recipe.TotalCookDuration }
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

    -- Evaluasi kualitas kematangan berdasarkan rasio waktu elapsed
    local quality, progress = RecipesConfig.EvaluateQuality(recipe, elapsed)

    log:Info("Pemain %s mengangkat '%s' pada %.2f s (Progress: %.1f%%) -> Kualitas: %s", player.Name, batch.RecipeId, elapsed, progress * 100, quality)

    -- Simpan hasil gorengan ke etalase inventaris pemain
    local inventoryService = self._services.InventoryService
    if inventoryService then
        inventoryService:AddCookedFood(player, batch.RecipeId, quality, 1)
    end

    -- Matikan partikel dan kosongkan visual wajan di gerobak
    local cartService = self._services.CartService
    if cartService then
        cartService:UpdateCartFoodVisual(player, "Empty", 0.0)
    end

    -- Beri sinyal selesai ke client
    NetworkBridge.FireClient(player, Remotes.Events.CookStateChanged, "Empty", batch.RecipeId, os.clock(), 0)
    NetworkBridge.FireClient(player, Remotes.Events.FoodCollected, quality, batch.RecipeId)

    local ts = self._services and self._services.TutorialService
    if ts and ts.OnFoodCollected then
        ts:OnFoodCollected(player, quality)
    end

    self._activeBatches[userId] = nil
    return { Success = true, Quality = quality, RecipeId = batch.RecipeId }
end

return CookingService
