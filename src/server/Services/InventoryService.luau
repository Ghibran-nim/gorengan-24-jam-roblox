--!strict
--[[
    InventoryService.luau
    Layanan otoritatif server untuk mengelola inventaris bahan baku mentah
    dan makanan gorengan siap saji di dalam etalase gerobak pemain.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type PlayerInventory = GameplayTypes.PlayerInventory
type QualityResult = GameplayTypes.QualityResult

local log = Logger.new("InventoryService")

local InventoryService = {
    Name = "InventoryService",
    _inventories = {} :: { [number]: PlayerInventory },
    _services = {} :: { [string]: any },
}

-- Paket bahan baku awal untuk pemain baru
local STARTER_INGREDIENTS = {
    batter = 10,     -- 10 porsi adonan tepung
    veggies = 10,    -- 10 porsi sayuran
    banana = 5,      -- 5 sisir pisang
    tofu = 5,        -- 5 potong tahu
    tempeh = 5,      -- 5 papan tempe
    acitapioca = 5,  -- 5 bungkus tepung tapioka
    egg = 0,         -- Dibeli di toko saat resep tingkat lanjut terbuka
    risol_skin = 0,  -- Dibeli di toko saat Risol Mayo terbuka
}

function InventoryService:Init()
    log:Info("Menginisialisasi InventoryService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupPlayerInventory(player)
    end)

    for _, player in Players:GetPlayers() do
        self:_setupPlayerInventory(player)
    end

    -- Daftarkan handler permintaan pengambilan bahan pokok dari kotak gerobak (HANYA batter/veggies)
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestTakeIngredients, function(player: Player, ingredientType: any, amount: any)
        if ingredientType ~= nil and (typeof(ingredientType) ~= "string" or #ingredientType > 32) then
            return { Success = false, Error = "Jenis bahan tidak valid!" }
        end
        local safeType = ingredientType or "batter"
        if safeType ~= "batter" and safeType ~= "veggies" then
            log:Warn("SECURITY: Pemain %s mencoba mengambil bahan berbayar '%s' lewat kotak gerobak!", player.Name, tostring(safeType))
            return { Success = false, Error = "Bahan spesial ini hanya dapat dibeli di Toko Bahan Baku!" }
        end
        if amount ~= nil and (typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > 10 or math.floor(amount) ~= amount) then
            return { Success = false, Error = "Jumlah bahan tidak valid!" }
        end

        local parent = script and script.Parent
        local throwMod = if parent then parent:FindFirstChild("ThrowableService") else nil
        if throwMod then
            local ts = require(throwMod)
            if ts and ts.IsPlayerRagdolled and ts:IsPlayerRagdolled(player) then
                return { Success = false, Error = "Tidak dapat mengambil bahan saat sempoyongan!" }
            end
        end

        local cartMod = if parent then parent:FindFirstChild("CartService") else nil
        if cartMod and player.Character then
            local cartService = require(cartMod)
            local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local cPos = if cartService and cartService.GetCartPosition then cartService:GetCartPosition(player) else nil
            if hrp and cPos and (hrp.Position - cPos).Magnitude > 20 then
                return { Success = false, Error = "Dekati kotak bahan di gerobakmu terlebih dahulu!" }
            end
        end

        return self:HandleTakeIngredients(player, safeType, amount)
    end)

    -- Daftarkan handler permintaan inventaris
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetInventory, function(player: Player)
        local inv = self._inventories[player.UserId]
        if inv then
            return { Success = true, Ingredients = inv.Ingredients, CookedFood = inv.CookedFood }
        end
        return { Success = false, Error = "Inventaris tidak ditemukan" }
    end)
end

function InventoryService:Start()
    local parent = script and script.Parent
    if parent then
        local tsMod = parent:FindFirstChild("TutorialService")
        if tsMod then
            self._services.TutorialService = require(tsMod)
        end
        local ecoMod = parent:FindFirstChild("EconomyService")
        if ecoMod then
            self._services.EconomyService = require(ecoMod)
        end
        local dataMod = parent:FindFirstChild("DataService")
        if dataMod then
            local dataService = require(dataMod)
            self._services.DataService = dataService
            dataService:RegisterDomain("Inventory",
                function(player: Player, profile: any)
                    local userId = player.UserId
                    self:_setupPlayerInventory(player)
                    local inv = self._inventories[userId]
                    if inv and profile.Inventory then
                        for ingId, qty in pairs(profile.Inventory.Ingredients or {}) do
                            inv.Ingredients[ingId] = qty
                        end
                        for recId, q in pairs(profile.Inventory.CookedFood or {}) do
                            inv.CookedFood[recId] = {
                                Undercooked = q.Undercooked or 0,
                                Crispy = q.Crispy or 0,
                                Burnt = q.Burnt or 0,
                            }
                        end
                        self:SyncInventory(player)
                    end
                end,
                function(player: Player, profile: any)
                    local inv = self._inventories[player.UserId]
                    if inv then
                        profile.Inventory.Ingredients = table.clone(inv.Ingredients)
                        local cookedCopy = {}
                        for recId, q in pairs(inv.CookedFood) do
                            cookedCopy[recId] = table.clone(q)
                        end
                        profile.Inventory.CookedFood = cookedCopy
                    end
                end,
                function(userId: number)
                    self._inventories[userId] = nil
                end
            )
        end
    end
    log:Info("InventoryService aktif.")
end

function InventoryService:_getEconomyService(): any
    if not self._services.EconomyService and script and script.Parent then
        local ecoMod = script.Parent:FindFirstChild("EconomyService")
        if ecoMod then
            self._services.EconomyService = require(ecoMod)
        end
    end
    return self._services.EconomyService
end

function InventoryService:_setupPlayerInventory(player: Player)
    local userId = player.UserId
    if not self._inventories[userId] then
        self._inventories[userId] = {
            Ingredients = table.clone(STARTER_INGREDIENTS),
            CookedFood = {
                ["bakwan_sayur"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["tempe_mendoan"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["pisang_goreng"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["cireng_crispy"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["tahu_isi"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["martabak_mini"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["risol_mayo"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
            },
        }
        log:Info("Inventaris awal disiapkan untuk pemain %s (10x Batter, 10x Veggies)", player.Name)
        self:SyncInventory(player)
    end
end

function InventoryService:GetMaxIngredientCapacity(player: Player): number
    local eco = self:_getEconomyService()
    if eco and eco.HasUpgrade and eco:HasUpgrade(player, "kotak_bahan_xl") then
        return EconomyConfig.UpgradedIngredientCapacity or 60
    end
    return EconomyConfig.BaseIngredientCapacity or 30
end

function InventoryService:GetMaxEtalaseCapacity(player: Player): number
    local eco = self:_getEconomyService()
    if eco and eco.HasUpgrade and eco:HasUpgrade(player, "etalase_2tingkat") then
        return EconomyConfig.UpgradedEtalaseCapacity or 28
    end
    return EconomyConfig.BaseEtalaseCapacity or 12
end

function InventoryService:GetTotalCookedCount(player: Player): number
    local inv = self:GetInventory(player)
    if not inv then return 0 end

    local total = 0
    for _, q in pairs(inv.CookedFood) do
        total += (q.Crispy or 0) + (q.Undercooked or 0) + (q.Burnt or 0)
    end
    return total
end

function InventoryService:HasEtalaseSpace(player: Player): boolean
    return self:GetTotalCookedCount(player) < self:GetMaxEtalaseCapacity(player)
end

function InventoryService:GetInventory(player: Player): PlayerInventory?
    if not self._inventories[player.UserId] then
        self:_setupPlayerInventory(player)
    end
    return self._inventories[player.UserId]
end

function InventoryService:SyncInventory(player: Player)
    local inv = self._inventories[player.UserId]
    if inv then
        if self._services and self._services.DataService and self._services.DataService.MarkDirty then
            self._services.DataService:MarkDirty(player, "InventoryChanged")
        end
        NetworkBridge.FireClient(player, Remotes.Events.InventoryUpdated, inv.Ingredients, inv.CookedFood)
    end
end

function InventoryService:HasIngredients(player: Player, required: { [string]: number }): boolean
    local inv = self._inventories[player.UserId]
    if not inv then return false end

    for item, qty in pairs(required) do
        local current = inv.Ingredients[item] or 0
        if current < qty then
            return false
        end
    end
    return true
end

function InventoryService:DeductIngredients(player: Player, required: { [string]: number }): boolean
    if not self:HasIngredients(player, required) then
        return false
    end

    local inv = self._inventories[player.UserId]
    if not inv then return false end

    for item, qty in pairs(required) do
        inv.Ingredients[item] = (inv.Ingredients[item] or 0) - qty
    end

    self:SyncInventory(player)
    log:Debug("Bahan terpotong untuk %s", player.Name)
    return true
end

function InventoryService:AddCookedFood(player: Player, recipeId: string, quality: QualityResult, count: number)
    local inv = self._inventories[player.UserId]
    if not inv then return end

    if not inv.CookedFood[recipeId] then
        inv.CookedFood[recipeId] = { Undercooked = 0, Crispy = 0, Burnt = 0 }
    end

    local current = inv.CookedFood[recipeId][quality] or 0
    inv.CookedFood[recipeId][quality] = current + count

    log:Info("Pemain %s menyimpan %dx %s (%s) ke etalase gerobak", player.Name, count, recipeId, quality)
    self:SyncInventory(player)
end

function InventoryService:RemoveCookedFood(player: Player, recipeId: string, quality: QualityResult, count: number): boolean
    local inv = self._inventories[player.UserId]
    if not inv or not inv.CookedFood[recipeId] then return false end

    local current = inv.CookedFood[recipeId][quality] or 0
    if current < count then
        return false
    end

    inv.CookedFood[recipeId][quality] = current - count
    self:SyncInventory(player)
    return true
end

function InventoryService:GetTotalBurntCount(player: Player): number
    local inv = self:GetInventory(player)
    if not inv then return 0 end

    local total = 0
    for _, qualities in pairs(inv.CookedFood) do
        total += (qualities.Burnt or 0)
    end
    return total
end

function InventoryService:ConsumeAnyBurntFood(player: Player, preferredRecipeId: string?): (boolean, string?)
    local inv = self:GetInventory(player)
    if not inv then return false, nil end

    -- Prioritaskan resep yang dipilih jika stok gosong tersedia
    if preferredRecipeId and inv.CookedFood[preferredRecipeId] then
        local count = inv.CookedFood[preferredRecipeId].Burnt or 0
        if count >= 1 then
            inv.CookedFood[preferredRecipeId].Burnt = count - 1
            self:SyncInventory(player)
            return true, preferredRecipeId
        end
    end

    -- Jika tidak ada pilihan atau stoknya kosong, cari resep apa pun yang gosong (urutan deterministik)
    local recipeIds = {}
    for recipeId, _ in pairs(inv.CookedFood) do
        table.insert(recipeIds, recipeId)
    end
    table.sort(recipeIds)

    for _, recipeId in ipairs(recipeIds) do
        local qualities = inv.CookedFood[recipeId]
        local count = if qualities then (qualities.Burnt or 0) else 0
        if count >= 1 then
            qualities.Burnt = count - 1
            self:SyncInventory(player)
            return true, recipeId
        end
    end

    return false, nil
end

function InventoryService:ClearCookedFood(player: Player): number
    local inv = self._inventories[player.UserId]
    if not inv then return 0 end

    local totalSeized = 0
    for recipeId, qualities in pairs(inv.CookedFood) do
        totalSeized += (qualities.Crispy or 0) + (qualities.Undercooked or 0) + (qualities.Burnt or 0)
        inv.CookedFood[recipeId] = { Undercooked = 0, Crispy = 0, Burnt = 0 }
    end

    log:Warn("PENYITAAN SATPOL: Seluruh stok gorengan di etalase %s disita (%d porsi)!", player.Name, totalSeized)
    self:SyncInventory(player)
    return totalSeized
end

function InventoryService:GrantPurchasedIngredients(player: Player, ingredientType: string, amount: number): { Success: boolean, Error: string?, NewStock: number? }
    return self:HandleTakeIngredients(player, ingredientType, amount)
end

function InventoryService:HandleTakeIngredients(player: Player, ingredientType: string?, amount: number?): { Success: boolean, Error: string?, NewStock: number? }
    local inv = self._inventories[player.UserId]
    if not inv then
        return { Success = false, Error = "Inventaris tidak ditemukan!" }
    end

    local itemType = ingredientType or "batter"
    local qty = amount or 5
    local maxCap = self:GetMaxIngredientCapacity(player)

    -- Isi ulang bahan pokok sesuai kapasitas upgrade
    local current = inv.Ingredients[itemType] or 0
    if current >= maxCap then
        return { Success = false, Error = string.format("Kapasitas penyimpanan bahan sudah penuh (Maks %d)!", maxCap) }
    end

    local added = math.min(qty, maxCap - current)
    inv.Ingredients[itemType] = current + added

    -- Jika mengambil batter, tambahkan juga sayuran ekstra untuk starter
    if itemType == "batter" then
        local vegCurrent = inv.Ingredients["veggies"] or 0
        inv.Ingredients["veggies"] = math.min(vegCurrent + added, maxCap)
    end

    log:Info("Pemain %s mengambil persediaan bahan dari kotak gerobak: +%d %s", player.Name, added, itemType)
    self:SyncInventory(player)

    local ts = self._services and self._services.TutorialService
    if ts and ts.OnIngredientsTaken then
        ts:OnIngredientsTaken(player)
    end

    return { Success = true, NewStock = inv.Ingredients[itemType] }
end

return InventoryService
