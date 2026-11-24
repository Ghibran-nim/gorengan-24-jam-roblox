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
}

function InventoryService:Init()
    log:Info("Menginisialisasi InventoryService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupPlayerInventory(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self._inventories[player.UserId] = nil
    end)

    for _, player in Players:GetPlayers() do
        self:_setupPlayerInventory(player)
    end

    -- Daftarkan handler permintaan pengambilan bahan dari kotak gerobak
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestTakeIngredients, function(player: Player, ingredientType: string?, amount: number?)
        return self:HandleTakeIngredients(player, ingredientType, amount)
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
    end
    log:Info("InventoryService aktif.")
end

function InventoryService:_setupPlayerInventory(player: Player)
    local userId = player.UserId
    if not self._inventories[userId] then
        self._inventories[userId] = {
            Ingredients = table.clone(STARTER_INGREDIENTS),
            CookedFood = {
                ["bakwan_sayur"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["pisang_goreng"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["tahu_isi"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["tempe_mendoan"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
                ["cireng_crispy"] = { Undercooked = 0, Crispy = 0, Burnt = 0 },
            },
        }
        log:Info("Inventaris awal disiapkan untuk pemain %s (10x Batter, 10x Veggies)", player.Name)
        self:SyncInventory(player)
    end
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

function InventoryService:HandleTakeIngredients(player: Player, ingredientType: string?, amount: number?): { Success: boolean, Error: string?, NewStock: number? }
    local inv = self._inventories[player.UserId]
    if not inv then
        return { Success = false, Error = "Inventaris tidak ditemukan!" }
    end

    local itemType = ingredientType or "batter"
    local qty = amount or 5

    -- Isi ulang bahan pokok (maksimal persediaan 30 per bahan)
    local current = inv.Ingredients[itemType] or 0
    if current >= 30 then
        return { Success = false, Error = "Kapasitas penyimpanan bahan di gerobak sudah penuh (Maks 30)!" }
    end

    local added = math.min(qty, 30 - current)
    inv.Ingredients[itemType] = current + added

    -- Jika mengambil batter, tambahkan juga sayuran ekstra untuk starter
    if itemType == "batter" then
        local vegCurrent = inv.Ingredients["veggies"] or 0
        inv.Ingredients["veggies"] = math.min(vegCurrent + added, 30)
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
