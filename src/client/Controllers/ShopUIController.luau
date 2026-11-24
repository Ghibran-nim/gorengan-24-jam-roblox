--!strict
--[[
    ShopUIController.luau
    Mengelola antarmuka modal untuk:
    - Toko Bahan Baku (Beli Adonan, Sayur, Pisang, Tahu, Tempe, Tapioka)
    - ATM Center (Setor & Tarik Uang Tabungan Aman)
    - Bengkel Upgrade Gerobak (Peningkatan Wajan, Kompor, Roda, Etalase)
    - Modal Inventaris Detail
    Terhubung langsung dengan ProximityPrompt di dunia map dan tombol Action Dock HUD.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local UpgradesConfig = require(Shared:WaitForChild("Config"):WaitForChild("UpgradesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("ShopUIController")

local ShopUIController = {
    Name = "ShopUIController",
    _gui = nil :: ScreenGui?,
    _modalContainer = nil :: Frame?,
    _activeModal = nil :: Frame?,
    _ownedUpgrades = {} :: { [string]: boolean },
}

function ShopUIController:Init()
    log:Info("Menginisialisasi ShopUIController...")

    -- Tangkap update kepemilikan upgrade dari server
    NetworkBridge.OnClientEvent(Remotes.Events.UpgradesUpdated, function(upgrades: any)
        self._ownedUpgrades = upgrades or {}
    end)

    -- Hubungkan ProximityPrompt dari dunia map
    ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
        if playerWhoTriggered ~= Players.LocalPlayer then return end

        if prompt.ObjectText == "Setor / Tarik Tabungan" or prompt.Name == "ATMPrompt" then
            self:OpenATMModal()
        elseif prompt.Name == "IngredientShopPrompt" then
            self:OpenIngredientShopModal()
        elseif prompt.Name == "UpgradeShopPrompt" then
            self:OpenUpgradeModal()
        elseif prompt.Name == "ChiliShopPrompt" then
            local HUDController = require(script.Parent:WaitForChild("HUDController"))
            if HUDController and (HUDController :: any).ShowToastNotification then
                (HUDController :: any):ShowToastNotification("🌶️ Kios Cabai Gacha: Beli bibit & cabai rawit pedas!", "Success")
            end
        end
    end)

    self:_createModalContainer()
end

function ShopUIController:Start()
    log:Info("ShopUIController aktif. Meminta data upgrade awal...")
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetUpgrades)
        if res and res.Success then
            self._ownedUpgrades = res.Upgrades or {}
        end
    end)
end

function ShopUIController:_createModalContainer()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ModalsHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ModalsHUD"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Backdrop gelap semi-transparan
    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.55
    backdrop.Text = ""
    backdrop.Parent = screenGui

    backdrop.MouseButton1Click:Connect(function()
        self:CloseAllModals()
    end)

    -- Container Modal Tengah (Ukuran responsif 480 x 360 pixel)
    local container = Instance.new("Frame")
    container.Name = "ModalWindow"
    container.Size = UDim2.new(0, 480, 0, 360)
    container.Position = UDim2.new(0.5, -240, 0.5, -180)
    container.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
    container.BorderSizePixel = 0
    container.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BorderStroke"
    stroke.Color = Color3.fromRGB(60, 65, 75)
    stroke.Thickness = 2
    stroke.Parent = container

    -- Tombol Tutup [X] di pojok kanan atas modal
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 34, 0, 34)
    closeBtn.Position = UDim2.new(1, -42, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 18
    closeBtn.Text = "X"
    closeBtn.Parent = container

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        self:CloseAllModals()
    end)

    self._gui = screenGui
    self._modalContainer = container
    screenGui.Parent = playerGui
end

function ShopUIController:CloseAllModals()
    if self._modalContainer then
        for _, child in self._modalContainer:GetChildren() do
            if child.Name ~= "CloseButton" and child.Name ~= "BorderStroke" and not child:IsA("UICorner") then
                child:Destroy()
            end
        end
    end
    if self._gui then
        self._gui.Enabled = false
    end
    self._activeModal = nil
end

-- ============================================================================
-- MODAL 1: TOKO BAHAN BAKU
-- ============================================================================

function ShopUIController:OpenIngredientShopModal()
    self:CloseAllModals()
    if not self._gui or not self._modalContainer then return end

    local container = self._modalContainer
    self._gui.Enabled = true

    -- Judul Modal
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(245, 195, 45)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🏪 TOKO BAHAN BAKU 'SUMBER REJEKI'"
    title.Parent = container

    -- Scrolling Frame untuk daftar paket bahan
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -24, 1, -54)
    scroll.Position = UDim2.new(0, 12, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 420)
    scroll.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    local currentCash = if HUDController then (HUDController :: any):GetCarriedCash() else 0

    local packs = EconomyConfig.GetAllPacks()
    for i, pack in ipairs(packs) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 56)
        itemFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 44)
        itemFrame.BorderSizePixel = 0
        itemFrame.LayoutOrder = i
        itemFrame.Parent = scroll

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemFrame

        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(0, 44, 1, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.TextSize = 24
        iconLabel.Text = pack.Icon
        iconLabel.Parent = itemFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.6, -10, 1, 0)
        descLabel.Position = UDim2.new(0, 48, 0, 0)
        descLabel.BackgroundTransparency = 1
        descLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        descLabel.Font = Enum.Font.FredokaOne
        descLabel.TextSize = 14
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Text = string.format("%s\nRp %d (%s)", pack.Name, pack.Price, pack.Description)
        descLabel.Parent = itemFrame

        -- Tombol Beli
        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 100, 0, 36)
        buyBtn.Position = UDim2.new(1, -110, 0.5, -18)
        buyBtn.Font = Enum.Font.FredokaOne
        buyBtn.TextSize = 14
        buyBtn.Parent = itemFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = buyBtn

        local canAfford = (currentCash >= pack.Price)
        if canAfford then
            buyBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 65)
            buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            buyBtn.Text = "BELI"
            buyBtn.MouseButton1Click:Connect(function()
                self:RequestBuyPack(pack.Id)
            end)
        else
            buyBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 80)
            buyBtn.TextColor3 = Color3.fromRGB(160, 165, 170)
            buyBtn.Text = "KAS KURANG"
        end
    end
end

function ShopUIController:RequestBuyPack(packId: string)
    log:Info("Client meminta membeli paket bahan: %s", packId)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestBuyIngredient, packId)

    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if res and res.Success then
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("🛒 Pembelian Berhasil: " .. (res.PackName or packId), "Success")
        end
        self:OpenIngredientShopModal() -- Refresh UI setelah beli
    else
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("⚠️ " .. (res and res.Error or "Gagal membeli bahan!"), "Warning")
        end
    end
end

-- ============================================================================
-- MODAL 2: ATM CENTER 24 JAM
-- ============================================================================

function ShopUIController:OpenATMModal()
    self:CloseAllModals()
    if not self._gui or not self._modalContainer then return end

    local container = self._modalContainer
    self._gui.Enabled = true

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(80, 180, 255)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🏧 ATM BANK KAS 24 JAM"
    title.Parent = container

    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    local carried = if HUDController then (HUDController :: any):GetCarriedCash() else 0
    local banked = if HUDController then (HUDController :: any):GetBankedCash() else 0

    -- Info Saldo
    local balanceInfo = Instance.new("TextLabel")
    balanceInfo.Size = UDim2.new(1, -32, 0, 50)
    balanceInfo.Position = UDim2.new(0, 16, 0, 48)
    balanceInfo.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
    balanceInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    balanceInfo.Font = Enum.Font.FredokaOne
    balanceInfo.TextSize = 15
    balanceInfo.Text = string.format("💵 Uang Tunai Kas: Rp %d\n🏦 Saldo Tabungan ATM: Rp %d (Aman dari Razia)", carried, banked)
    balanceInfo.Parent = container

    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 8)
    infoCorner.Parent = balanceInfo

    -- Subtitle Setor
    local depositTitle = Instance.new("TextLabel")
    depositTitle.Size = UDim2.new(1, -32, 0, 24)
    depositTitle.Position = UDim2.new(0, 16, 0, 110)
    depositTitle.BackgroundTransparency = 1
    depositTitle.TextColor3 = Color3.fromRGB(100, 220, 130)
    depositTitle.Font = Enum.Font.FredokaOne
    depositTitle.TextSize = 14
    depositTitle.TextXAlignment = Enum.TextXAlignment.Left
    depositTitle.Text = "SETOR KE TABUNGAN AMAN (Lindungi dari Satpol PP):"
    depositTitle.Parent = container

    -- Tombol-tombol Setor
    local depFrame = Instance.new("Frame")
    depFrame.Size = UDim2.new(1, -32, 0, 42)
    depFrame.Position = UDim2.new(0, 16, 0, 136)
    depFrame.BackgroundTransparency = 1
    depFrame.Parent = container

    local depLayout = Instance.new("UIListLayout")
    depLayout.FillDirection = Enum.FillDirection.Horizontal
    depLayout.Padding = UDim.new(0, 10)
    depLayout.Parent = depFrame

    local depositAmounts = { 10000, 50000, -1 }
    local depositLabels = { "Setor Rp 10rb", "Setor Rp 50rb", "Setor Semua Kas" }

    for idx, amt in ipairs(depositAmounts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.31, 0, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 13
        btn.Text = depositLabels[idx]
        btn.Parent = depFrame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local depositValue = if amt == -1 then carried else amt
            if depositValue > 0 then
                self:RequestDeposit(depositValue)
            end
        end)
    end

    -- Subtitle Tarik
    local withdrawTitle = Instance.new("TextLabel")
    withdrawTitle.Size = UDim2.new(1, -32, 0, 24)
    withdrawTitle.Position = UDim2.new(0, 16, 0, 196)
    withdrawTitle.BackgroundTransparency = 1
    withdrawTitle.TextColor3 = Color3.fromRGB(240, 160, 60)
    withdrawTitle.Font = Enum.Font.FredokaOne
    withdrawTitle.TextSize = 14
    withdrawTitle.TextXAlignment = Enum.TextXAlignment.Left
    withdrawTitle.Text = "TARIK TABUNGAN KE KAS GEROBAK:"
    withdrawTitle.Parent = container

    local withFrame = Instance.new("Frame")
    withFrame.Size = UDim2.new(1, -32, 0, 42)
    withFrame.Position = UDim2.new(0, 16, 0, 222)
    withFrame.BackgroundTransparency = 1
    withFrame.Parent = container

    local withLayout = Instance.new("UIListLayout")
    withLayout.FillDirection = Enum.FillDirection.Horizontal
    withLayout.Padding = UDim.new(0, 10)
    withLayout.Parent = withFrame

    local withAmounts = { 10000, 50000, -1 }
    local withLabels = { "Tarik Rp 10rb", "Tarik Rp 50rb", "Tarik Semua" }

    for idx, amt in ipairs(withAmounts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.31, 0, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(180, 95, 30)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 13
        btn.Text = withLabels[idx]
        btn.Parent = withFrame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local withdrawValue = if amt == -1 then banked else amt
            if withdrawValue > 0 then
                self:RequestWithdraw(withdrawValue)
            end
        end)
    end
end

function ShopUIController:RequestDeposit(amount: number)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestDepositATM, amount)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if res and res.Success then
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification(string.format("🏦 Berhasil setor Rp %d ke tabungan aman!", amount), "Success")
        end
        self:OpenATMModal()
    else
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("⚠️ " .. (res and res.Error or "Gagal setor ATM!"), "Warning")
        end
    end
end

function ShopUIController:RequestWithdraw(amount: number)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestWithdrawATM, amount)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if res and res.Success then
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification(string.format("💵 Berhasil menarik Rp %d ke uang kas!", amount), "Success")
        end
        self:OpenATMModal()
    else
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("⚠️ " .. (res and res.Error or "Gagal tarik ATM!"), "Warning")
        end
    end
end

-- ============================================================================
-- MODAL 3: BENGKEL UPGRADE GEROBAK
-- ============================================================================

function ShopUIController:OpenUpgradeModal()
    self:CloseAllModals()
    if not self._gui or not self._modalContainer then return end

    local container = self._modalContainer
    self._gui.Enabled = true

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(240, 190, 40)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🔧 BENGKEL UPGRADE GEROBAK 'MAJU LANCAR'"
    title.Parent = container

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -24, 1, -54)
    scroll.Position = UDim2.new(0, 12, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 360)
    scroll.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll

    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    local currentCash = if HUDController then (HUDController :: any):GetCarriedCash() else 0

    local upgrades = UpgradesConfig.GetAllUpgrades()
    for _, upg in ipairs(upgrades) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 60)
        itemFrame.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scroll

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemFrame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.68, 0, 1, 0)
        descLabel.Position = UDim2.new(0, 12, 0, 0)
        descLabel.BackgroundTransparency = 1
        descLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        descLabel.Font = Enum.Font.FredokaOne
        descLabel.TextSize = 13
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Text = string.format("⚡ %s (Rp %d)\n%s", upg.Name, upg.Cost, upg.Description)
        descLabel.Parent = itemFrame

        local actionBtn = Instance.new("TextButton")
        actionBtn.Size = UDim2.new(0, 110, 0, 36)
        actionBtn.Position = UDim2.new(1, -120, 0.5, -18)
        actionBtn.Font = Enum.Font.FredokaOne
        actionBtn.TextSize = 13
        actionBtn.Parent = itemFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = actionBtn

        local isOwned = (self._ownedUpgrades[upg.Id] == true)
        if isOwned then
            actionBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 50)
            actionBtn.TextColor3 = Color3.fromRGB(180, 240, 190)
            actionBtn.Text = "TERPASANG"
        elseif currentCash >= upg.Cost then
            actionBtn.BackgroundColor3 = Color3.fromRGB(210, 140, 30)
            actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionBtn.Text = "PASANG"
            actionBtn.MouseButton1Click:Connect(function()
                self:RequestBuyUpgrade(upg.Id)
            end)
        else
            actionBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 70)
            actionBtn.TextColor3 = Color3.fromRGB(150, 155, 160)
            actionBtn.Text = "KAS KURANG"
        end
    end
end

function ShopUIController:RequestBuyUpgrade(upgradeId: string)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestBuyUpgrade, upgradeId)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if res and res.Success then
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("🔧 Upgrade Terpasang: " .. (res.UpgradeName or upgradeId), "Success")
        end
        self:OpenUpgradeModal()
    else
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("⚠️ " .. (res and res.Error or "Gagal membeli upgrade!"), "Warning")
        end
    end
end

-- ============================================================================
-- MODAL 4: INVENTARIS DETAIL GEROBAK
-- ============================================================================

function ShopUIController:OpenInventoryModal()
    self:CloseAllModals()
    if not self._gui or not self._modalContainer then return end

    local container = self._modalContainer
    self._gui.Enabled = true

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(240, 200, 70)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🎒 INVENTARIS LENGKAP GEROBAK"
    title.Parent = container

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -24, 1, -54)
    scroll.Position = UDim2.new(0, 12, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 360)
    scroll.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll

    local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
    local ingredients = if InventoryController then InventoryController:GetIngredients() else {}
    local cooked = if InventoryController then InventoryController:GetCookedFood() else {}

    -- Bagian Bahan Baku
    local bLabel = Instance.new("TextLabel")
    bLabel.Size = UDim2.new(1, 0, 0, 22)
    bLabel.BackgroundTransparency = 1
    bLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
    bLabel.Font = Enum.Font.FredokaOne
    bLabel.TextSize = 14
    bLabel.TextXAlignment = Enum.TextXAlignment.Left
    bLabel.Text = "📦 PERSEDIAAN BAHAN MENTAH:"
    bLabel.Parent = scroll

    local itemsList = {
        { name = "Adonan Tepung", icon = "🥟", id = "batter" },
        { name = "Sayuran Segar", icon = "🥬", id = "veggies" },
        { name = "Pisang Kepok", icon = "🍌", id = "banana" },
        { name = "Tahu Pong", icon = "🧈", id = "tofu" },
        { name = "Tempe Mendoan", icon = "🥢", id = "tempeh" },
        { name = "Tepung Tapioka", icon = "🥣", id = "acitapioca" },
    }

    for _, itm in ipairs(itemsList) do
        local count = ingredients[itm.id] or 0
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -10, 0, 28)
        f.BackgroundColor3 = Color3.fromRGB(35, 38, 44)
        f.BorderSizePixel = 0
        f.Parent = scroll
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.format("%s %s : %d Porsi", itm.icon, itm.name, count)
        lbl.Parent = f
    end

    -- Bagian Gorengan di Etalase
    local eLabel = Instance.new("TextLabel")
    eLabel.Size = UDim2.new(1, 0, 0, 22)
    eLabel.BackgroundTransparency = 1
    eLabel.TextColor3 = Color3.fromRGB(245, 185, 35)
    eLabel.Font = Enum.Font.FredokaOne
    eLabel.TextSize = 14
    eLabel.TextXAlignment = Enum.TextXAlignment.Left
    eLabel.Text = "✨ GORENGAN DI ETALASE SIAP SAJI:"
    eLabel.Parent = scroll

    for recipeId, counts in pairs(cooked) do
        local total = (counts.Crispy or 0) + (counts.Undercooked or 0) + (counts.Burnt or 0)
        if total > 0 then
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, -10, 0, 32)
            f.BackgroundColor3 = Color3.fromRGB(42, 45, 52)
            f.BorderSizePixel = 0
            f.Parent = scroll
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 6)
            c.Parent = f

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -16, 1, 0)
            lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.Font = Enum.Font.SourceSansBold
            lbl.TextSize = 13
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = string.format("🍽️ %s : 🌟 %d Crispy | ⚠️ %d Mentah | 🔥 %d Gosong", recipeId:upper(), counts.Crispy or 0, counts.Undercooked or 0, counts.Burnt or 0)
            lbl.Parent = f
        end
    end
end

return ShopUIController
