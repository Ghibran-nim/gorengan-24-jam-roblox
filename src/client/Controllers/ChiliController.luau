--!strict
--[[
    ChiliController.luau
    Mengelola antarmuka Gacha Cabai & Halaman Koleksi Cabai Nusantara (Kios "Pedas Mampus"):
    - Tombol cepat HUD di pojok kanan atas untuk mengakses Gacha & Koleksi kapan saja
    - Terhubung langsung dengan ChiliShopPrompt di peta
    - Pengungkapan probabilitas drop transparan & penghitung pity 15x
    - Animasi roulette pengungkapan hasil gacha otoritatif dari server
    - Halaman koleksi cabai lengkap dengan status pasang/duplikat/efek khusus
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local ChiliGachaConfig = require(Shared:WaitForChild("Config"):WaitForChild("ChiliGachaConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ChiliCollectionData = GameplayTypes.ChiliCollectionData

local log = Logger.new("ChiliController")

local ChiliController = {
    Name = "ChiliController",
    _collection = {
        SchemaVersion = 1,
        TotalRolls = 0,
        PityCounter = 0,
        EquippedChiliId = nil,
        OwnedChilis = {},
    } :: ChiliCollectionData,
    _isRolling = false,
    _activeTab = "Gacha" :: "Gacha" | "Collection",
    _hudGui = nil :: ScreenGui?,
    _hudBadgeBtn = nil :: TextButton?,
    _modalGui = nil :: ScreenGui?,
    _contentFrame = nil :: Frame?,
    _tabGachaBtn = nil :: TextButton?,
    _tabColBtn = nil :: TextButton?,
}

local function playUiSound(soundId: string, volume: number, pitch: number)
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume
    s.PlaybackSpeed = pitch
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 2.5)
end

function ChiliController:Init()
    log:Info("Menginisialisasi ChiliController...")

    NetworkBridge.OnClientEvent(Remotes.Events.ChiliCollectionUpdated, function(colData: any)
        if typeof(colData) == "table" then
            self._collection = colData :: ChiliCollectionData
            self:_updateHudBadge()
            if self._modalGui and self._modalGui.Enabled and not self._isRolling then
                self:_renderActiveTab()
            end
        end
    end)

    self:_createHudBadge()
    self:_createModalGui()
end

function ChiliController:Start()
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetChiliCollection)
        if res and res.Success and typeof(res.Collection) == "table" then
            self._collection = res.Collection
            self:_updateHudBadge()
        end
    end)
    log:Info("ChiliController aktif.")
end

function ChiliController:_notify(message: string, alertType: string)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, alertType)
    end
end

function ChiliController:_createHudBadge()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ChiliHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChiliHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Tombol badge tepat di bawah ProgressionHUD (pojok kanan atas, touch-friendly)
    local badgeBtn = Instance.new("TextButton")
    badgeBtn.Name = "ChiliBadgeButton"
    badgeBtn.Size = UDim2.new(0, 244, 0, 34)
    badgeBtn.Position = UDim2.new(1, -260, 0, 94)
    badgeBtn.BackgroundColor3 = Color3.fromRGB(48, 24, 24)
    badgeBtn.BackgroundTransparency = 0.1
    badgeBtn.TextColor3 = Color3.fromRGB(255, 225, 190)
    badgeBtn.Font = Enum.Font.FredokaOne
    badgeBtn.TextSize = 13
    badgeBtn.Text = "🌶️ Cabai: Belum Ada [Gacha]"
    badgeBtn.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = badgeBtn

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BadgeStroke"
    stroke.Color = Color3.fromRGB(220, 75, 50)
    stroke.Thickness = 1.5
    stroke.Parent = badgeBtn

    badgeBtn.MouseButton1Click:Connect(function()
        self:OpenModal("Gacha")
    end)

    self._hudGui = screenGui
    self._hudBadgeBtn = badgeBtn
    screenGui.Parent = playerGui
    self:_updateHudBadge()
end

function ChiliController:_updateHudBadge()
    if not self._hudBadgeBtn then return end
    local equippedId = self._collection.EquippedChiliId
    local chili = if equippedId then ChiliGachaConfig.GetChili(equippedId) else nil
    local stroke = self._hudBadgeBtn:FindFirstChild("BadgeStroke") :: UIStroke?

    if chili then
        self._hudBadgeBtn.Text = string.format("%s %s (%.2fx) [Koleksi]", chili.Icon, chili.Name, chili.ProfitMultiplier)
        if stroke then stroke.Color = chili.Color end
    else
        self._hudBadgeBtn.Text = "🌶️ Cabai: Belum Ada [Gacha]"
        if stroke then stroke.Color = Color3.fromRGB(220, 75, 50) end
    end
end

function ChiliController:_createModalGui()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ChiliModalHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChiliModalHUD"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.DisplayOrder = 20
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = screenGui

    backdrop.MouseButton1Click:Connect(function()
        if not self._isRolling then
            self:CloseModal()
        end
    end)

    local modal = Instance.new("Frame")
    modal.Name = "ChiliModalContainer"
    modal.Size = UDim2.new(0, 540, 0, 400)
    modal.Position = UDim2.new(0.5, -270, 0.5, -200)
    modal.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    modal.BorderSizePixel = 0
    modal.Parent = screenGui

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 14)
    mCorner.Parent = modal

    local mStroke = Instance.new("UIStroke")
    mStroke.Color = Color3.fromRGB(235, 85, 45)
    mStroke.Thickness = 2
    mStroke.Parent = modal

    local title = Instance.new("TextLabel")
    title.Name = "ModalTitle"
    title.Size = UDim2.new(1, -60, 0, 34)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 195, 70)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🌶️ KIOS CABAI 'PEDAS MAMPUS'"
    title.Parent = modal

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 18
    closeBtn.Text = "X"
    closeBtn.Parent = modal

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        if not self._isRolling then
            self:CloseModal()
        end
    end)

    -- Tab Switcher: Gacha vs Koleksi
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -32, 0, 34)
    tabBar.Position = UDim2.new(0, 16, 0, 44)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = modal

    local tabGacha = Instance.new("TextButton")
    tabGacha.Name = "TabGacha"
    tabGacha.Size = UDim2.new(0.49, 0, 1, 0)
    tabGacha.Position = UDim2.new(0, 0, 0, 0)
    tabGacha.Font = Enum.Font.FredokaOne
    tabGacha.TextSize = 14
    tabGacha.Text = "🎲 GACHA CABAI"
    tabGacha.Parent = tabBar
    local tgC = Instance.new("UICorner"); tgC.CornerRadius = UDim.new(0, 8); tgC.Parent = tabGacha

    local tabCol = Instance.new("TextButton")
    tabCol.Name = "TabCollection"
    tabCol.Size = UDim2.new(0.49, 0, 1, 0)
    tabCol.Position = UDim2.new(0.51, 0, 0, 0)
    tabCol.Font = Enum.Font.FredokaOne
    tabCol.TextSize = 14
    tabCol.Text = "📖 KOLEKSI CABAI"
    tabCol.Parent = tabBar
    local tcC = Instance.new("UICorner"); tcC.CornerRadius = UDim.new(0, 8); tcC.Parent = tabCol

    tabGacha.MouseButton1Click:Connect(function()
        if not self._isRolling then
            self._activeTab = "Gacha"
            self:_renderActiveTab()
        end
    end)

    tabCol.MouseButton1Click:Connect(function()
        if not self._isRolling then
            self._activeTab = "Collection"
            self:_renderActiveTab()
        end
    end)

    local content = Instance.new("Frame")
    content.Name = "ContentFrame"
    content.Size = UDim2.new(1, -32, 1, -96)
    content.Position = UDim2.new(0, 16, 0, 84)
    content.BackgroundTransparency = 1
    content.Parent = modal

    self._modalGui = screenGui
    self._contentFrame = content
    self._tabGachaBtn = tabGacha
    self._tabColBtn = tabCol
    screenGui.Parent = playerGui
end

function ChiliController:OpenModal(initialTab: ("Gacha" | "Collection")?)
    if not self._modalGui then return end
    self._activeTab = initialTab or self._activeTab or "Gacha"
    self._modalGui.Enabled = true
    self:_renderActiveTab()
end

function ChiliController:CloseModal()
    if self._modalGui then
        self._modalGui.Enabled = false
    end
end

function ChiliController:_clearContent()
    if not self._contentFrame then return end
    for _, child in self._contentFrame:GetChildren() do
        child:Destroy()
    end
end

function ChiliController:_updateTabButtons()
    if self._tabGachaBtn and self._tabColBtn then
        if self._activeTab == "Gacha" then
            self._tabGachaBtn.BackgroundColor3 = Color3.fromRGB(210, 75, 40)
            self._tabGachaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            self._tabColBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
            self._tabColBtn.TextColor3 = Color3.fromRGB(180, 185, 195)
        else
            self._tabGachaBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
            self._tabGachaBtn.TextColor3 = Color3.fromRGB(180, 185, 195)
            self._tabColBtn.BackgroundColor3 = Color3.fromRGB(210, 75, 40)
            self._tabColBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

function ChiliController:_renderActiveTab()
    self:_updateTabButtons()
    self:_clearContent()
    if self._activeTab == "Gacha" then
        self:_renderGachaTab()
    else
        self:_renderCollectionTab()
    end
end

function ChiliController:_renderGachaTab()
    local content = self._contentFrame
    if not content then return end

    -- 1. Panel Pengungkapan Peluang Drop Transparan (Odds Disclosure)
    local oddsBox = Instance.new("Frame")
    oddsBox.Name = "OddsDisclosureBox"
    oddsBox.Size = UDim2.new(1, 0, 0, 78)
    oddsBox.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
    oddsBox.BorderSizePixel = 0
    oddsBox.Parent = content
    local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0, 8); oc.Parent = oddsBox

    local oddsParts = {}
    for _, c in ipairs(ChiliGachaConfig.GetAllChilis()) do
        table.insert(oddsParts, string.format("%s %s (%.2f%%)", c.Icon, c.Rarity, c.ProbabilityPercent))
    end

    local oddsLbl = Instance.new("TextLabel")
    oddsLbl.Size = UDim2.new(1, -16, 1, -8)
    oddsLbl.Position = UDim2.new(0, 8, 0, 4)
    oddsLbl.BackgroundTransparency = 1
    oddsLbl.TextColor3 = Color3.fromRGB(225, 230, 240)
    oddsLbl.Font = Enum.Font.SourceSansBold
    oddsLbl.TextSize = 13
    oddsLbl.TextWrapped = true
    oddsLbl.Text = string.format(
        "Peluang Resmi: %s\n🛡️ Pity Jaminan Rare+: %d / %d Roll | Duplikat memberi Cashback Rp 2rb–20rb!",
        table.concat(oddsParts, "  •  "),
        self._collection.PityCounter,
        ChiliGachaConfig.PityThreshold
    )
    oddsLbl.Parent = oddsBox

    -- 2. Stage Animasi Reveal Hasil Gacha
    local stage = Instance.new("Frame")
    stage.Name = "RevealStage"
    stage.Size = UDim2.new(1, 0, 0, 152)
    stage.Position = UDim2.new(0, 0, 0, 88)
    stage.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
    stage.BorderSizePixel = 0
    stage.Parent = content
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 12); sc.Parent = stage
    local stageStroke = Instance.new("UIStroke")
    stageStroke.Name = "StageStroke"
    stageStroke.Color = Color3.fromRGB(85, 90, 105)
    stageStroke.Thickness = 2.5
    stageStroke.Parent = stage

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Name = "RevealIcon"
    iconLbl.Size = UDim2.new(0, 90, 0, 76)
    iconLbl.Position = UDim2.new(0.5, -45, 0, 12)
    iconLbl.BackgroundTransparency = 1
    iconLbl.TextScaled = true
    iconLbl.Text = "🌶️"
    iconLbl.Parent = stage

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "RevealName"
    nameLbl.Size = UDim2.new(1, -20, 0, 28)
    nameLbl.Position = UDim2.new(0, 10, 0, 88)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = Color3.fromRGB(255, 225, 110)
    nameLbl.Font = Enum.Font.FredokaOne
    nameLbl.TextSize = 17
    nameLbl.Text = "Siap Mengundi Cabai Nusantara!"
    nameLbl.Parent = stage

    local detailLbl = Instance.new("TextLabel")
    detailLbl.Name = "RevealDetail"
    detailLbl.Size = UDim2.new(1, -20, 0, 28)
    detailLbl.Position = UDim2.new(0, 10, 0, 116)
    detailLbl.BackgroundTransparency = 1
    detailLbl.TextColor3 = Color3.fromRGB(210, 215, 225)
    detailLbl.Font = Enum.Font.SourceSansBold
    detailLbl.TextSize = 13
    detailLbl.Text = "Klik tombol di bawah untuk memutar undian cabai Pak Kumis."
    detailLbl.Parent = stage

    -- 3. Tombol Roll Gacha (Touch & Mouse Friendly)
    local rollBtn = Instance.new("TextButton")
    rollBtn.Name = "RollGachaButton"
    rollBtn.Size = UDim2.new(1, 0, 0, 48)
    rollBtn.Position = UDim2.new(0, 0, 1, -50)
    rollBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 35)
    rollBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    rollBtn.Font = Enum.Font.FredokaOne
    rollBtn.TextSize = 16
    rollBtn.Text = string.format("🎲 GACHA CABAI SEKARANG (Rp %d)", ChiliGachaConfig.RollCost)
    rollBtn.Parent = content
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 10); rc.Parent = rollBtn

    rollBtn.MouseButton1Click:Connect(function()
        self:TriggerRollGacha(rollBtn, stage, stageStroke, iconLbl, nameLbl, detailLbl)
    end)
end

function ChiliController:TriggerRollGacha(
    rollBtn: TextButton,
    stage: Frame,
    stageStroke: UIStroke,
    iconLbl: TextLabel,
    nameLbl: TextLabel,
    detailLbl: TextLabel
)
    if self._isRolling then return end
    self._isRolling = true
    rollBtn.BackgroundColor3 = Color3.fromRGB(80, 82, 88)
    rollBtn.Text = "🎲 MENGUNDI CABAI..."

    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestRollChiliGacha)
    if not res or not res.Success then
        self._isRolling = false
        rollBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 35)
        rollBtn.Text = string.format("🎲 GACHA CABAI SEKARANG (Rp %d)", ChiliGachaConfig.RollCost)
        self:_notify("⚠️ " .. tostring(res and res.Error or "Gagal melakukan gacha cabai!"), "Warning")
        return
    end

    if typeof(res.Collection) == "table" then
        self._collection = res.Collection
        self:_updateHudBadge()
    end

    local resultChili = ChiliGachaConfig.GetChili(res.ChiliId)
    local allChilis = ChiliGachaConfig.GetAllChilis()

    -- Animasi roulette pengungkapan hasil yang ditentukan oleh server
    task.spawn(function()
        local delays = { 0.05, 0.06, 0.07, 0.08, 0.10, 0.12, 0.15, 0.20 }
        for i, d in ipairs(delays) do
            if not stage.Parent then break end
            local preview = allChilis[((i - 1) % #allChilis) + 1]
            iconLbl.Text = preview.Icon
            nameLbl.Text = preview.Name
            nameLbl.TextColor3 = preview.Color
            stageStroke.Color = preview.Color
            playUiSound("rbxasset://sounds/action_jump.mp3", 0.25, 1.4 + (i * 0.05))
            task.wait(d)
        end

        if stage.Parent and resultChili then
            iconLbl.Text = resultChili.Icon
            stageStroke.Color = resultChili.Color
            nameLbl.TextColor3 = resultChili.Color
            nameLbl.Text = string.format("%s [%s] — %.2fx Profit!", resultChili.Name, resultChili.Rarity:upper(), resultChili.ProfitMultiplier)

            local statusTag = if res.IsDuplicate
                then string.format("DUPLIKAT (+Cashback Rp %d)", res.Cashback or 0)
                else "🌟 KOLEKSI BARU TERBUKA!"
            if res.PityTriggered then
                statusTag = "🛡️ PITY RARE+! " .. statusTag
            end
            detailLbl.Text = string.format("%s | %s", statusTag, resultChili.SpecialEffectText)

            -- Efek pop pada ikon hasil
            iconLbl.Size = UDim2.new(0, 120, 0, 96)
            iconLbl.Position = UDim2.new(0.5, -60, 0, 4)
            TweenService:Create(iconLbl, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 90, 0, 76),
                Position = UDim2.new(0.5, -45, 0, 12),
            }):Play()

            playUiSound("rbxasset://sounds/action_get_up.mp3", 0.55, if ChiliGachaConfig.IsRareOrHigher(resultChili.Rarity) then 1.3 else 1.0)
            self:_notify(string.format("%s Dapat %s (%s)!", resultChili.Icon, resultChili.Name, resultChili.Rarity), if ChiliGachaConfig.IsRareOrHigher(resultChili.Rarity) then "Crispy" else "Success")
        end

        task.wait(0.35)
        self._isRolling = false
        if rollBtn.Parent then
            rollBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 35)
            rollBtn.Text = string.format("🎲 GACHA LAGI (Rp %d)", ChiliGachaConfig.RollCost)
        end
    end)
end

function ChiliController:_renderCollectionTab()
    local content = self._contentFrame
    if not content then return end

    local allChilis = ChiliGachaConfig.GetAllChilis()
    local ownedCount = 0
    for _, c in ipairs(allChilis) do
        local entry = self._collection.OwnedChilis[c.Id]
        if entry and entry.Count > 0 then
            ownedCount += 1
        end
    end

    local summary = Instance.new("TextLabel")
    summary.Name = "CollectionSummary"
    summary.Size = UDim2.new(1, 0, 0, 28)
    summary.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
    summary.TextColor3 = Color3.fromRGB(245, 200, 70)
    summary.Font = Enum.Font.FredokaOne
    summary.TextSize = 14
    summary.Text = string.format("📖 Koleksi Terkumpul: %d / %d Jenis Cabai  |  Total Undian: %d", ownedCount, #allChilis, self._collection.TotalRolls)
    summary.Parent = content
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = summary

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, -36)
    scroll.Position = UDim2.new(0, 0, 0, 36)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, #allChilis * 76)
    scroll.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll

    for _, chili in ipairs(allChilis) do
        local entry = self._collection.OwnedChilis[chili.Id]
        local isOwned = entry ~= nil and entry.Count > 0
        local isEquipped = self._collection.EquippedChiliId == chili.Id

        local card = Instance.new("Frame")
        card.Name = "ChiliCard_" .. chili.Id
        card.Size = UDim2.new(1, -10, 0, 68)
        card.BackgroundColor3 = if isOwned then Color3.fromRGB(38, 40, 48) else Color3.fromRGB(28, 30, 34)
        card.BorderSizePixel = 0
        card.Parent = scroll
        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = card
        local cs = Instance.new("UIStroke")
        cs.Color = if isOwned then chili.Color else Color3.fromRGB(60, 62, 70)
        cs.Thickness = if isEquipped then 2.5 else 1.2
        cs.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 46, 1, 0)
        icon.BackgroundTransparency = 1
        icon.TextSize = 26
        icon.Text = if isOwned then chili.Icon else "❓"
        icon.Parent = card

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(0.62, 0, 1, 0)
        info.Position = UDim2.new(0, 50, 0, 0)
        info.BackgroundTransparency = 1
        info.TextColor3 = if isOwned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(140, 145, 155)
        info.Font = Enum.Font.FredokaOne
        info.TextSize = 12
        info.TextWrapped = true
        info.TextXAlignment = Enum.TextXAlignment.Left
        if isOwned and entry then
            info.Text = string.format("%s [%s] (x%d) — %.2fx Profit\n%s", chili.Name, chili.Rarity, entry.Count, chili.ProfitMultiplier, chili.SpecialEffectText)
        else
            info.Text = string.format("??? [%s — Peluang %.2f%%]\nDapatkan dari Gacha Cabai Pedas Mampus!", chili.Rarity, chili.ProbabilityPercent)
        end
        info.Parent = card

        local eqBtn = Instance.new("TextButton")
        eqBtn.Size = UDim2.new(0, 108, 0, 36)
        eqBtn.Position = UDim2.new(1, -118, 0.5, -18)
        eqBtn.Font = Enum.Font.FredokaOne
        eqBtn.TextSize = 12
        eqBtn.Parent = card
        local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0, 6); ec.Parent = eqBtn

        if isEquipped then
            eqBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 65)
            eqBtn.TextColor3 = Color3.fromRGB(220, 255, 225)
            eqBtn.Text = "✅ DIPAKAI"
        elseif isOwned then
            eqBtn.BackgroundColor3 = Color3.fromRGB(210, 120, 30)
            eqBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            eqBtn.Text = "✨ PASANG"
            eqBtn.MouseButton1Click:Connect(function()
                local eqRes = NetworkBridge.InvokeServer(Remotes.Functions.RequestEquipChili, chili.Id)
                if eqRes and eqRes.Success then
                    self._collection = eqRes.Collection or self._collection
                    self:_updateHudBadge()
                    self:_renderCollectionTab()
                elseif eqRes and eqRes.Error then
                    self:_notify("⚠️ " .. eqRes.Error, "Warning")
                end
            end)
        else
            eqBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 58)
            eqBtn.TextColor3 = Color3.fromRGB(130, 135, 145)
            eqBtn.Text = "🔒 TERKUNCI"
        end
    end
end

return ChiliController