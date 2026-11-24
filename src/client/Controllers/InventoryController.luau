--!strict
--[[
    InventoryController.luau
    Mengelola status lokal inventaris bahan baku dan makanan siap saji di sisi client.
    Menyinkronkan data dengan server dan menampilkan ringkasan persediaan pada HUD.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("InventoryController")

local InventoryController = {
    Name = "InventoryController",
    _ingredients = {} :: { [string]: number },
    _cookedFood = {} :: { [string]: { Undercooked: number, Crispy: number, Burnt: number } },
    _gui = nil :: ScreenGui?,
    _stockLabel = nil :: TextLabel?,
}

function InventoryController:Init()
    log:Info("Menginisialisasi InventoryController...")

    -- Dengarkan pembaruan inventaris dari server
    NetworkBridge.OnClientEvent(Remotes.Events.InventoryUpdated, function(ingredients: any, cookedFood: any)
        self._ingredients = ingredients or {}
        self._cookedFood = cookedFood or {}
        self:_updateInventoryDisplay()
    end)

    -- Buat UI mini bar inventaris di sudut layar
    self:_createInventoryUI()
end

function InventoryController:Start()
    log:Info("InventoryController aktif. Meminta data inventaris awal...")
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetInventory)
        if res and res.Success then
            self._ingredients = res.Ingredients or {}
            self._cookedFood = res.CookedFood or {}
            self:_updateInventoryDisplay()
        end
    end)
end

function InventoryController:_createInventoryUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("InventoryHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InventoryHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Panel bar bahan baku (Kiri Atas)
    local frame = Instance.new("Frame")
    frame.Name = "StockBar"
    frame.Size = UDim2.new(0, 260, 0, 75)
    frame.Position = UDim2.new(0, 16, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(30, 32, 36)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 20)
    title.Position = UDim2.new(0, 6, 0, 4)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(240, 200, 80)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 14
    title.Text = "📦 BAHAN DI GEROBAK"
    title.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "Content"
    label.Size = UDim2.new(1, -12, 0, 45)
    label.Position = UDim2.new(0, 6, 0, 24)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 13
    label.Text = "Memuat stok bahan..."
    label.Parent = frame

    self._stockLabel = label
    self._gui = screenGui
    screenGui.Parent = playerGui
end

function InventoryController:_updateInventoryDisplay()
    if not self._stockLabel then return end

    local batter = self._ingredients["batter"] or 0
    local veggies = self._ingredients["veggies"] or 0
    local banana = self._ingredients["banana"] or 0
    local tofu = self._ingredients["tofu"] or 0

    -- Hitung total gorengan siap saji
    local totalCrispy = 0
    local totalBurnt = 0
    for _, counts in pairs(self._cookedFood) do
        totalCrispy += (counts.Crispy or 0)
        totalBurnt += (counts.Burnt or 0)
    end

    self._stockLabel.Text = string.format(
        "Adonan: %d | Sayur: %d | Pisang: %d | Tahu: %d\nEtalase: ✨ %d Crispy | 🔥 %d Gosong",
        batter, veggies, banana, tofu, totalCrispy, totalBurnt
    )
end

function InventoryController:GetIngredients(): { [string]: number }
    return self._ingredients
end

function InventoryController:GetCookedFood(): any
    return self._cookedFood
end

return InventoryController
