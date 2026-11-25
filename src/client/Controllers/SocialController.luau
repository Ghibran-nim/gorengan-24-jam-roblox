--!strict
--[[
    SocialController.luau
    Mengelola UI Multiplayer & Sosial di sisi client:
    - Tombol & Panel Leaderboard Kompetisi Pendapatan Sesi (maksimal 8 plot pemain)
    - Banner Event Kompetisi Server-Wide ("Lomba Omzet Gerobak")
    - Modal Kunjungan & Pembelian Antargerobak (Beli Crispy Tetangga + Reaksi Sosial)
    - Efek teks melayang 3D (CartSocialFeedback) di atas gerobak pemain target
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type LeaderboardEntry = GameplayTypes.LeaderboardEntry
type CartVisitSummary = GameplayTypes.CartVisitSummary

local log = Logger.new("SocialController")

local SocialController = {
    Name = "SocialController",
    _entries = {} :: { LeaderboardEntry },
    _competitionActive = false,
    _competitionEndsAt = 0,
    _gui = nil :: ScreenGui?,
    _badgeBtn = nil :: TextButton?,
    _compBanner = nil :: Frame?,
    _compLabel = nil :: TextLabel?,
    _lbModal = nil :: Frame?,
    _lbList = nil :: ScrollingFrame?,
    _visitModal = nil :: Frame?,
    _visitTitle = nil :: TextLabel?,
    _visitSubtitle = nil :: TextLabel?,
    _visitList = nil :: ScrollingFrame?,
    _currentVisitOwnerId = nil :: number?,
}

function SocialController:Init()
    log:Info("Menginisialisasi SocialController...")

    NetworkBridge.OnClientEvent(Remotes.Events.LeaderboardUpdated, function(entries: any, compActive: boolean?)
        if typeof(entries) == "table" then
            self._entries = entries :: { LeaderboardEntry }
            if compActive ~= nil then
                self._competitionActive = compActive == true
            end
            self:_updateHudBadge()
            if self._lbModal and self._lbModal.Visible then
                self:_renderLeaderboardRows()
            end
        end
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.ServerCompetitionEvent, function(active: boolean, remaining: number, _msg: string?)
        self._competitionActive = active == true
        self._competitionEndsAt = if active then (os.clock() + (remaining or 45)) else 0
        self:_updateCompetitionBanner()
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.CartSocialFeedback, function(targetUserId: number, text: string, _senderName: string)
        self:_spawnCartFeedbackBillboard(targetUserId, text)
    end)

    self:_createSocialHUD()

    -- Perbarui hitung mundur banner kompetisi tiap 1 detik bila aktif
    task.spawn(function()
        while true do
            task.wait(1)
            if self._competitionActive then
                self:_updateCompetitionBanner()
            end
        end
    end)
end

function SocialController:Start()
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetLeaderboard)
        if res and res.Success and typeof(res.Entries) == "table" then
            self._entries = res.Entries
            self._competitionActive = res.CompetitionActive == true
            if self._competitionActive and (res.CompetitionRemaining or 0) > 0 then
                self._competitionEndsAt = os.clock() + res.CompetitionRemaining
            end
            self:_updateHudBadge()
            self:_updateCompetitionBanner()
        end
    end)
    log:Info("SocialController aktif.")
end

function SocialController:_notify(message: string, alertType: string)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, alertType)
    end
end

function SocialController:_createSocialHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("SocialLeaderboardHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SocialLeaderboardHUD"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 15
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 1. Tombol Badge Peringkat (Pojok Kanan Atas tepat di bawah ChiliBadgeButton y=94+34+6=134)
    local badgeBtn = Instance.new("TextButton")
    badgeBtn.Name = "LeaderboardBadgeButton"
    badgeBtn.Size = UDim2.new(0, 244, 0, 34)
    badgeBtn.Position = UDim2.new(1, -260, 0, 134)
    badgeBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
    badgeBtn.BackgroundTransparency = 0.1
    badgeBtn.TextColor3 = Color3.fromRGB(255, 225, 110)
    badgeBtn.Font = Enum.Font.FredokaOne
    badgeBtn.TextSize = 13
    badgeBtn.Text = "🏆 Peringkat • #1 Rp 0"
    badgeBtn.Parent = screenGui

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = badgeBtn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Color3.fromRGB(235, 180, 45)
    bStroke.Thickness = 1.5
    bStroke.Parent = badgeBtn

    badgeBtn.MouseButton1Click:Connect(function()
        self:ToggleLeaderboardModal()
    end)

    -- 2. Banner Event Kompetisi Server-Wide (Tengah Atas di bawah ToastContainer)
    local compBanner = Instance.new("Frame")
    compBanner.Name = "CompetitionBanner"
    compBanner.Size = UDim2.new(0, 340, 0, 32)
    compBanner.Position = UDim2.new(0.5, -170, 0, 70)
    compBanner.BackgroundColor3 = Color3.fromRGB(185, 105, 20)
    compBanner.BackgroundTransparency = 0.1
    compBanner.Visible = false
    compBanner.Parent = screenGui

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 8)
    cbCorner.Parent = compBanner

    local compLbl = Instance.new("TextLabel")
    compLbl.Name = "BannerText"
    compLbl.Size = UDim2.new(1, -12, 1, 0)
    compLbl.Position = UDim2.new(0, 6, 0, 0)
    compLbl.BackgroundTransparency = 1
    compLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    compLbl.Font = Enum.Font.FredokaOne
    compLbl.TextSize = 13
    compLbl.Text = "🏆 LOMBA OMZET! +20% Bonus Penjualan"
    compLbl.Parent = compBanner

    -- 3. Modal Leaderboard Kompetisi Pendapatan
    local lbModal = Instance.new("Frame")
    lbModal.Name = "LeaderboardModal"
    lbModal.AnchorPoint = Vector2.new(0.5, 0.5)
    lbModal.Size = UDim2.fromScale(0.84, 0.82)
    lbModal.Position = UDim2.fromScale(0.5, 0.5)
    lbModal.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
    lbModal.Visible = false
    lbModal.Parent = screenGui

    local lbConstraint = Instance.new("UISizeConstraint")
    lbConstraint.MinSize = Vector2.new(280, 240)
    lbConstraint.MaxSize = Vector2.new(460, 360)
    lbConstraint.Parent = lbModal

    local lbCorner = Instance.new("UICorner")
    lbCorner.CornerRadius = UDim.new(0, 14)
    lbCorner.Parent = lbModal

    local lbStroke = Instance.new("UIStroke")
    lbStroke.Color = Color3.fromRGB(235, 180, 45)
    lbStroke.Thickness = 2
    lbStroke.Parent = lbModal

    local lbTitle = Instance.new("TextLabel")
    lbTitle.Size = UDim2.new(1, -70, 0, 36)
    lbTitle.Position = UDim2.new(0, 14, 0, 8)
    lbTitle.BackgroundTransparency = 1
    lbTitle.TextColor3 = Color3.fromRGB(255, 220, 95)
    lbTitle.Font = Enum.Font.FredokaOne
    lbTitle.TextSize = 18
    lbTitle.TextXAlignment = Enum.TextXAlignment.Left
    lbTitle.Text = "🏆 KOMPETISI OMZET GEROBAK (MAX 8)"
    lbTitle.Parent = lbModal

    local lbClose = Instance.new("TextButton")
    lbClose.Name = "CloseButton"
    lbClose.Size = UDim2.new(0, 36, 0, 32)
    lbClose.Position = UDim2.new(1, -46, 0, 10)
    lbClose.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
    lbClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbClose.Font = Enum.Font.FredokaOne
    lbClose.TextSize = 16
    lbClose.Text = "X"
    lbClose.Parent = lbModal
    Instance.new("UICorner", lbClose).CornerRadius = UDim.new(0, 8)
    lbClose.MouseButton1Click:Connect(function()
        lbModal.Visible = false
    end)

    local lbScroll = Instance.new("ScrollingFrame")
    lbScroll.Name = "EntriesList"
    lbScroll.Size = UDim2.new(1, -24, 1, -60)
    lbScroll.Position = UDim2.new(0, 12, 0, 48)
    lbScroll.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
    lbScroll.BorderSizePixel = 0
    lbScroll.ScrollBarThickness = 6
    lbScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    lbScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    lbScroll.Parent = lbModal
    Instance.new("UICorner", lbScroll).CornerRadius = UDim.new(0, 10)

    local lbLayout = Instance.new("UIListLayout")
    lbLayout.Padding = UDim.new(0, 6)
    lbLayout.Parent = lbScroll

    -- 4. Modal Kunjungan & Pembelian Antargerobak
    local visitModal = Instance.new("Frame")
    visitModal.Name = "CartVisitModal"
    visitModal.AnchorPoint = Vector2.new(0.5, 0.5)
    visitModal.Size = UDim2.fromScale(0.82, 0.82)
    visitModal.Position = UDim2.fromScale(0.5, 0.5)
    visitModal.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
    visitModal.Visible = false
    visitModal.Parent = screenGui

    local vConstraint = Instance.new("UISizeConstraint")
    vConstraint.MinSize = Vector2.new(280, 240)
    vConstraint.MaxSize = Vector2.new(420, 350)
    vConstraint.Parent = visitModal

    Instance.new("UICorner", visitModal).CornerRadius = UDim.new(0, 14)
    local vStroke = Instance.new("UIStroke", visitModal)
    vStroke.Color = Color3.fromRGB(70, 185, 130)
    vStroke.Thickness = 2

    local vTitle = Instance.new("TextLabel")
    vTitle.Name = "TitleLabel"
    vTitle.Size = UDim2.new(1, -60, 0, 30)
    vTitle.Position = UDim2.new(0, 14, 0, 10)
    vTitle.BackgroundTransparency = 1
    vTitle.TextColor3 = Color3.fromRGB(115, 245, 175)
    vTitle.Font = Enum.Font.FredokaOne
    vTitle.TextSize = 18
    vTitle.TextXAlignment = Enum.TextXAlignment.Left
    vTitle.Text = "🛒 LAPAK TETANGGA"
    vTitle.Parent = visitModal

    local vSub = Instance.new("TextLabel")
    vSub.Name = "SubtitleLabel"
    vSub.Size = UDim2.new(1, -28, 0, 20)
    vSub.Position = UDim2.new(0, 14, 0, 40)
    vSub.BackgroundTransparency = 1
    vSub.TextColor3 = Color3.fromRGB(205, 210, 220)
    vSub.Font = Enum.Font.GothamMedium
    vSub.TextSize = 12
    vSub.TextXAlignment = Enum.TextXAlignment.Left
    vSub.Text = "Plot #1 • Lv.1 • Rep 100"
    vSub.Parent = visitModal

    local vClose = Instance.new("TextButton")
    vClose.Name = "CloseButton"
    vClose.Size = UDim2.new(0, 34, 0, 30)
    vClose.Position = UDim2.new(1, -44, 0, 10)
    vClose.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
    vClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    vClose.Font = Enum.Font.FredokaOne
    vClose.TextSize = 15
    vClose.Text = "X"
    vClose.Parent = visitModal
    Instance.new("UICorner", vClose).CornerRadius = UDim.new(0, 8)
    vClose.MouseButton1Click:Connect(function()
        visitModal.Visible = false
    end)

    -- Bar Reaksi Sosial Cepat (3 tombol ramah sentuh)
    local reactBar = Instance.new("Frame")
    reactBar.Name = "ReactionBar"
    reactBar.Size = UDim2.new(1, -28, 0, 38)
    reactBar.Position = UDim2.new(0, 14, 0, 66)
    reactBar.BackgroundTransparency = 1
    reactBar.Parent = visitModal

    local reactLayout = Instance.new("UIListLayout")
    reactLayout.FillDirection = Enum.FillDirection.Horizontal
    reactLayout.Padding = UDim.new(0, 8)
    reactLayout.Parent = reactBar

    local reactions = {
        { id = "jempol", text = "👍 Jempol", color = Color3.fromRGB(40, 140, 80) },
        { id = "semangat", text = "🔥 Semangat", color = Color3.fromRGB(200, 105, 25) },
        { id = "awas_satpol", text = "🚨 Awas Satpol!", color = Color3.fromRGB(185, 45, 45) },
    }
    for _, r in ipairs(reactions) do
        local btn = Instance.new("TextButton")
        btn.Name = "React_" .. r.id
        btn.Size = UDim2.new(0.32, 0, 1, 0)
        btn.BackgroundColor3 = r.color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 12
        btn.Text = r.text
        btn.Parent = reactBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(function()
            if self._currentVisitOwnerId then
                local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestSendSocialReaction, self._currentVisitOwnerId, r.id)
                if res and not res.Success and res.Error then
                    self:_notify("⚠️ " .. res.Error, "Warning")
                end
            end
        end)
    end

    local vScroll = Instance.new("ScrollingFrame")
    vScroll.Name = "MenuList"
    vScroll.Size = UDim2.new(1, -28, 1, -122)
    vScroll.Position = UDim2.new(0, 14, 0, 112)
    vScroll.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
    vScroll.BorderSizePixel = 0
    vScroll.ScrollBarThickness = 6
    vScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    vScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    vScroll.Parent = visitModal
    Instance.new("UICorner", vScroll).CornerRadius = UDim.new(0, 10)
    local vLayout = Instance.new("UIListLayout", vScroll)
    vLayout.Padding = UDim.new(0, 6)

    self._gui = screenGui
    self._badgeBtn = badgeBtn
    self._compBanner = compBanner
    self._compLabel = compLbl
    self._lbModal = lbModal
    self._lbList = lbScroll
    self._visitModal = visitModal
    self._visitTitle = vTitle
    self._visitSubtitle = vSub
    self._visitList = vScroll
    screenGui.Parent = playerGui
end

function SocialController:_updateHudBadge()
    if not self._badgeBtn then return end
    local localUserId = Players.LocalPlayer.UserId
    local myRank = 1
    local myEarnings = 0
    for _, entry in ipairs(self._entries) do
        if entry.UserId == localUserId then
            myRank = entry.Rank
            myEarnings = entry.TotalEarnings
            break
        end
    end
    self._badgeBtn.Text = string.format("🏆 Peringkat #%d • Rp %d", myRank, myEarnings)
end

function SocialController:_updateCompetitionBanner()
    if not self._compBanner or not self._compLabel then return end
    if not self._competitionActive then
        self._compBanner.Visible = false
        return
    end
    local rem = math.max(0, math.ceil(self._competitionEndsAt - os.clock()))
    self._compBanner.Visible = true
    self._compLabel.Text = string.format("🏆 LOMBA OMZET! +20%% Bonus Penjualan (%ds)", rem)
end

function SocialController:ToggleLeaderboardModal()
    if not self._lbModal then return end
    local nextState = not self._lbModal.Visible
    self._lbModal.Visible = nextState
    if nextState then
        if self._visitModal then self._visitModal.Visible = false end
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetLeaderboard)
        if res and res.Success and typeof(res.Entries) == "table" then
            self._entries = res.Entries
        end
        self:_renderLeaderboardRows()
    end
end

function SocialController:_renderLeaderboardRows()
    if not self._lbList then return end
    for _, child in self._lbList:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local localUserId = Players.LocalPlayer.UserId
    for _, entry in ipairs(self._entries) do
        local row = Instance.new("Frame")
        row.Name = "RankRow_" .. tostring(entry.UserId)
        row.Size = UDim2.new(1, -12, 0, 44)
        row.BackgroundColor3 = if entry.UserId == localUserId then Color3.fromRGB(36, 48, 64) else Color3.fromRGB(28, 30, 38)
        row.BorderSizePixel = 0
        row.Parent = self._lbList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local prefix = if entry.Rank == 1 then "👑 #1" else string.format("#%d", entry.Rank)
        local plotTxt = if entry.PlotId then ("Plot #" .. tostring(entry.PlotId)) else "Penonton"

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -90, 1, 0)
        info.Position = UDim2.new(0, 10, 0, 0)
        info.BackgroundTransparency = 1
        info.TextColor3 = if entry.Rank == 1 then Color3.fromRGB(255, 225, 95) else Color3.fromRGB(240, 242, 250)
        info.Font = Enum.Font.FredokaOne
        info.TextSize = 13
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Text = string.format("%s %s (%s • Lv.%d) — Rp %d (%dx)", prefix, entry.PlayerName, plotTxt, entry.Level, entry.TotalEarnings, entry.TotalSales)
        info.Parent = row

        if entry.UserId ~= localUserId then
            local reactBtn = Instance.new("TextButton")
            reactBtn.Name = "QuickThumbBtn"
            reactBtn.Size = UDim2.new(0, 68, 0, 30)
            reactBtn.Position = UDim2.new(1, -76, 0.5, -15)
            reactBtn.BackgroundColor3 = Color3.fromRGB(45, 135, 75)
            reactBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            reactBtn.Font = Enum.Font.FredokaOne
            reactBtn.TextSize = 12
            reactBtn.Text = "👍 Jempol"
            reactBtn.Parent = row
            Instance.new("UICorner", reactBtn).CornerRadius = UDim.new(0, 6)

            reactBtn.MouseButton1Click:Connect(function()
                local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestSendSocialReaction, entry.UserId, "jempol")
                if res and not res.Success and res.Error then
                    self:_notify("⚠️ " .. res.Error, "Warning")
                end
            end)
        end
    end
end

function SocialController:OpenCartVisitModal(targetUserId: number)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestInspectPlayerCart, targetUserId)
    if not res or not res.Success or not res.Summary then
        self:_notify("⚠️ " .. tostring(res and res.Error or "Tidak dapat memeriksa gerobak ini!"), "Warning")
        return
    end

    local summary: CartVisitSummary = res.Summary
    self._currentVisitOwnerId = targetUserId
    if self._lbModal then self._lbModal.Visible = false end
    if self._visitModal then self._visitModal.Visible = true end
    if self._visitTitle then
        self._visitTitle.Text = "🛒 GEROBAK " .. summary.OwnerName:upper()
    end
    if self._visitSubtitle then
        self._visitSubtitle.Text = string.format("Plot #%s • Lv.%d • Rep %d • 👍 %d", tostring(summary.PlotId or "-"), summary.Level, summary.Reputation, summary.ReactionsCount)
    end

    self:_renderVisitMenu(summary)
end

function SocialController:_renderVisitMenu(summary: CartVisitSummary)
    if not self._visitList then return end
    for _, child in self._visitList:GetChildren() do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if summary.TotalCrispy <= 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -16, 0, 50)
        empty.BackgroundTransparency = 1
        empty.TextColor3 = Color3.fromRGB(185, 190, 205)
        empty.Font = Enum.Font.GothamMedium
        empty.TextSize = 13
        empty.Text = "Etalase gorengan Crispy sedang kosong.\nKirim reaksi atau tunggu pemiliknya selesai menggoreng!"
        empty.Parent = self._visitList
        return
    end

    for recipeId, qty in pairs(summary.StockByRecipe) do
        local recipe = RecipesConfig.GetRecipe(recipeId)
        local rName = if recipe then (recipe.Icon .. " " .. recipe.Name) else recipeId
        local price = summary.PricesByRecipe[recipeId] or (if recipe then recipe.BasePrice else 2200)

        local itemRow = Instance.new("Frame")
        itemRow.Name = "BuyRow_" .. recipeId
        itemRow.Size = UDim2.new(1, -12, 0, 48)
        itemRow.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        itemRow.BorderSizePixel = 0
        itemRow.Parent = self._visitList
        Instance.new("UICorner", itemRow).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -118, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.Font = Enum.Font.FredokaOne
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.format("%s Crispy (Stok: %d)", rName, qty)
        lbl.Parent = itemRow

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyBtn_" .. recipeId
        buyBtn.Size = UDim2.new(0, 104, 0, 34)
        buyBtn.Position = UDim2.new(1, -112, 0.5, -17)
        buyBtn.BackgroundColor3 = Color3.fromRGB(45, 150, 85)
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.Font = Enum.Font.FredokaOne
        buyBtn.TextSize = 12
        buyBtn.Text = string.format("Beli Rp %d", price)
        buyBtn.Parent = itemRow
        Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 8)

        buyBtn.MouseButton1Click:Connect(function()
            local buyRes = NetworkBridge.InvokeServer(Remotes.Functions.RequestBuyFromPlayerCart, summary.OwnerUserId, recipeId)
            if buyRes and buyRes.Success then
                self:OpenCartVisitModal(summary.OwnerUserId)
            else
                self:_notify("⚠️ " .. tostring(buyRes and buyRes.Error or "Pembelian gagal!"), "Warning")
            end
        end)
    end
end

function SocialController:_spawnCartFeedbackBillboard(targetUserId: number, text: string)
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    local cart = if targetPlayer then Workspace:FindFirstChild("Gerobak_" .. targetPlayer.Name) else nil
    local anchor = if cart then cart:FindFirstChild("Canopy") or cart:FindFirstChild("Chassis") else nil
    if not anchor or not anchor:IsA("BasePart") then return end

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 180, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3.0, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Adornee = anchor
    bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    lbl.BackgroundTransparency = 0.15
    lbl.TextColor3 = Color3.fromRGB(255, 225, 95)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.Text = text
    lbl.Parent = bb
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)

    TweenService:Create(bb, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 5.5, 0),
    }):Play()

    task.delay(1.85, function()
        if bb.Parent then
            bb:Destroy()
        end
    end)
end

return SocialController
