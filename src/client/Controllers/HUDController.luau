--!strict
--[[
    HUDController.luau
    Mengelola seluruh tampilan antarmuka utama (Main HUD):
    - Money Display (Kas Pedagang & Saldo Tabungan ATM)
    - Indikator Reputasi & Waktu Siklus 24 Jam
    - Action Dock Cepat di pojok kanan bawah (Toko, ATM, Upgrade, Inventaris)
    - Sistem Notifikasi Toast Mengambang
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local log = Logger.new("HUDController")

local HUDController = {
    Name = "HUDController",
    _currentCarriedCash = 0,
    _currentBankedCash = 0,
    _currentReputation = 100,
    _gui = nil :: ScreenGui?,
    _cashLabel = nil :: TextLabel?,
    _bankLabel = nil :: TextLabel?,
    _repLabel = nil :: TextLabel?,
    _timeLabel = nil :: TextLabel?,
    _toastContainer = nil :: Frame?,
}

function HUDController:Init()
    log:Info("Menginisialisasi HUDController...")

    -- Tangkap update saldo dompet dari server
    NetworkBridge.OnClientEvent(Remotes.Events.PlayerEconomyUpdated, function(carried: number, banked: number, rep: number)
        self._currentCarriedCash = carried
        self._currentBankedCash = banked
        self._currentReputation = rep
        self:_updateEconomyDisplay()
    end)

    -- Tangkap notifikasi umum dari server
    NetworkBridge.OnClientEvent(Remotes.Events.NotificationFired, function(message: string, alertType: string?)
        self:ShowToastNotification(message, alertType)
    end)

    self:_createMainHUD()
end

function HUDController:Start()
    log:Info("HUDController aktif.")
end

function HUDController:_createMainHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("MainTopHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MainTopHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ========================================================================
    -- 1. TOP HEADER BAR: MONEY & STATUS DISPLAY
    -- ========================================================================
    local topBar = Instance.new("Frame")
    topBar.Name = "TopHeaderBar"
    topBar.Size = UDim2.new(0, 480, 0, 46)
    topBar.Position = UDim2.new(0, 16, 0, 14)
    topBar.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
    topBar.BackgroundTransparency = 0.15
    topBar.BorderSizePixel = 0
    topBar.Parent = screenGui

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 10)
    topCorner.Parent = topBar

    local topStroke = Instance.new("UIStroke")
    topStroke.Color = Color3.fromRGB(55, 60, 70)
    topStroke.Thickness = 1.5
    topStroke.Parent = topBar

    local topLayout = Instance.new("UIListLayout")
    topLayout.FillDirection = Enum.FillDirection.Horizontal
    topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    topLayout.Padding = UDim.new(0, 12)
    topLayout.Parent = topBar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = topBar

    -- Label Uang Kas
    local cash = Instance.new("TextLabel")
    cash.Name = "CashText"
    cash.Size = UDim2.new(0, 150, 1, 0)
    cash.BackgroundTransparency = 1
    cash.TextColor3 = Color3.fromRGB(80, 240, 120)
    cash.Font = Enum.Font.FredokaOne
    cash.TextSize = 15
    cash.TextXAlignment = Enum.TextXAlignment.Left
    cash.Text = "💵 Kas: Rp 0"
    cash.Parent = topBar
    self._cashLabel = cash

    -- Label Saldo Bank
    local bank = Instance.new("TextLabel")
    bank.Name = "BankText"
    bank.Size = UDim2.new(0, 150, 1, 0)
    bank.BackgroundTransparency = 1
    bank.TextColor3 = Color3.fromRGB(80, 180, 255)
    bank.Font = Enum.Font.FredokaOne
    bank.TextSize = 15
    bank.TextXAlignment = Enum.TextXAlignment.Left
    bank.Text = "🏦 Bank: Rp 0"
    bank.Parent = topBar
    self._bankLabel = bank

    -- Label Reputasi
    local rep = Instance.new("TextLabel")
    rep.Name = "RepText"
    rep.Size = UDim2.new(0, 120, 1, 0)
    rep.BackgroundTransparency = 1
    rep.TextColor3 = Color3.fromRGB(245, 195, 45)
    rep.Font = Enum.Font.FredokaOne
    rep.TextSize = 15
    rep.TextXAlignment = Enum.TextXAlignment.Left
    rep.Text = "🌟 Rep: 100"
    rep.Parent = topBar
    self._repLabel = rep

    -- ========================================================================
    -- 2. QUICK ACTION DOCK (Pojok Kanan Bawah, Touch-Friendly)
    -- ========================================================================
    local dock = Instance.new("Frame")
    dock.Name = "ActionDock"
    dock.Size = UDim2.new(0, 348, 0, 52)
    dock.Position = UDim2.new(1, -364, 1, -66)
    dock.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
    dock.BackgroundTransparency = 0.2
    dock.BorderSizePixel = 0
    dock.Parent = screenGui

    local dockCorner = Instance.new("UICorner")
    dockCorner.CornerRadius = UDim.new(0, 10)
    dockCorner.Parent = dock

    local dockStroke = Instance.new("UIStroke")
    dockStroke.Color = Color3.fromRGB(55, 60, 70)
    dockStroke.Thickness = 1.5
    dockStroke.Parent = dock

    local dockLayout = Instance.new("UIListLayout")
    dockLayout.FillDirection = Enum.FillDirection.Horizontal
    dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dockLayout.Padding = UDim.new(0, 8)
    dockLayout.Parent = dock

    local dockButtons = {
        { name = "RecipeBtn", icon = "📖", label = "Resep", action = "OpenRecipesModal", color = Color3.fromRGB(160, 65, 95) },
        { name = "ShopBtn", icon = "🛒", label = "Toko", action = "OpenIngredientShopModal", color = Color3.fromRGB(45, 130, 60) },
        { name = "ATMBtn", icon = "🏧", label = "ATM", action = "OpenATMModal", color = Color3.fromRGB(30, 100, 180) },
        { name = "UpgBtn", icon = "🔧", label = "Bengkel", action = "OpenUpgradeModal", color = Color3.fromRGB(180, 110, 25) },
        { name = "InvBtn", icon = "🎒", label = "Tas", action = "OpenInventoryModal", color = Color3.fromRGB(110, 60, 160) },
    }

    for _, btnData in ipairs(dockButtons) do
        local btn = Instance.new("TextButton")
        btn.Name = btnData.name
        btn.Size = UDim2.new(0, 58, 0, 40)
        btn.BackgroundColor3 = btnData.color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 12
        btn.Text = btnData.icon .. "\n" .. btnData.label
        btn.Parent = dock

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local ShopUIController = require(script.Parent:WaitForChild("ShopUIController"))
            if ShopUIController and (ShopUIController :: any)[btnData.action] then
                (ShopUIController :: any)[btnData.action](ShopUIController)
            end
        end)
    end

    -- ========================================================================
    -- 3. TOAST CONTAINER (Tengah Atas)
    -- ========================================================================
    local toastFrame = Instance.new("Frame")
    toastFrame.Name = "ToastContainer"
    toastFrame.Size = UDim2.new(0, 440, 0, 50)
    toastFrame.Position = UDim2.new(0.5, -220, 0, 14)
    toastFrame.BackgroundTransparency = 1
    toastFrame.Parent = screenGui
    self._toastContainer = toastFrame

    self._gui = screenGui
    screenGui.Parent = playerGui
end

function HUDController:_updateEconomyDisplay()
    if self._cashLabel then
        self._cashLabel.Text = string.format("💵 Kas: Rp %d", self._currentCarriedCash)
    end
    if self._bankLabel then
        self._bankLabel.Text = string.format("🏦 Bank: Rp %d", self._currentBankedCash)
    end
    if self._repLabel then
        self._repLabel.Text = string.format("🌟 Rep: %d", self._currentReputation)
    end
end

function HUDController:ShowToastNotification(message: string, alertType: string?)
    if not self._toastContainer then return end

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 1, 0)
    toast.Position = UDim2.new(0, 0, -1, -20)
    toast.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
    toast.BorderSizePixel = 0
    toast.Parent = self._toastContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = toast

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    if alertType == "Crispy" or alertType == "Success" then
        stroke.Color = Color3.fromRGB(245, 185, 35)
    elseif alertType == "Undercooked" or alertType == "Warning" then
        stroke.Color = Color3.fromRGB(80, 150, 230)
    elseif alertType == "Burnt" or alertType == "Error" then
        stroke.Color = Color3.fromRGB(220, 50, 50)
    else
        stroke.Color = Color3.fromRGB(160, 160, 170)
    end
    stroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 14
    label.TextScaled = true
    label.Text = message
    label.Parent = toast

    local tweenIn = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })
    tweenIn:Play()

    task.delay(3.5, function()
        local tweenOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, -1, -30),
            BackgroundTransparency = 1
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            toast:Destroy()
        end)
    end)
end

function HUDController:GetCarriedCash(): number
    return self._currentCarriedCash
end

function HUDController:GetBankedCash(): number
    return self._currentBankedCash
end

return HUDController
