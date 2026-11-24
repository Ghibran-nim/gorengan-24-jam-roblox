--!strict
--[[
    RaidController.luau
    Mengelola antarmuka peringatan razia Satpol PP di client:
    - Banner peringatan 15 detik dengan hitung mundur visual & efek sirene
    - Banner status razia aktif
    - Banner razia selesai
    - Efek komedi layar pusing (dazed vignette) saat tertangkap razia
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("RaidController")

local RaidController = {
    Name = "RaidController",
    _gui = nil :: ScreenGui?,
    _bannerFrame = nil :: Frame?,
    _titleLabel = nil :: TextLabel?,
    _subLabel = nil :: TextLabel?,
    _countdownBar = nil :: Frame?,
    _dazedOverlay = nil :: Frame?,
    _activeCountdownThread = nil :: thread?,
}

function RaidController:Init()
    log:Info("Menginisialisasi RaidController...")

    -- Tangani peringatan razia dari server
    NetworkBridge.OnClientEvent(Remotes.Events.RaidAlert, function(state: string, duration: number, message: string)
        self:HandleRaidAlert(state, duration, message)
    end)

    -- Tangani event penangkapan oleh Satpol PP
    NetworkBridge.OnClientEvent(Remotes.Events.PlayerCapturedBySatpol, function(penaltyAmount: number)
        self:ShowCapturedVignette(penaltyAmount)
    end)

    self:_createRaidUI()
end

function RaidController:Start()
    log:Info("RaidController aktif dan terhubung dengan jaringan peringatan razia.")
end

function RaidController:_createRaidUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("RaidAlertGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RaidAlertGui"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 100
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 1. Banner Peringatan Atas (Top Raid Banner)
    local banner = Instance.new("Frame")
    banner.Name = "RaidBanner"
    banner.Size = UDim2.new(0, 520, 0, 72)
    banner.Position = UDim2.new(0.5, -260, 0, -100) -- Mulai di luar layar atas
    banner.BackgroundColor3 = Color3.fromRGB(180, 25, 25)
    banner.BackgroundTransparency = 0.1
    banner.BorderSizePixel = 0
    banner.Visible = false
    banner.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = banner

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BannerStroke"
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 2.5
    stroke.Parent = banner

    local title = Instance.new("TextLabel")
    title.Name = "TitleLabel"
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 240, 240)
    title.Font = Enum.Font.FredokaOne
    title.TextScaled = true
    title.Text = "🚨 AWAS SATPOL PP! RAZIA DALAM 15 DETIK! 🚨"
    title.Parent = banner

    local sub = Instance.new("TextLabel")
    sub.Name = "SubLabel"
    sub.Size = UDim2.new(1, -20, 0, 20)
    sub.Position = UDim2.new(0, 10, 0, 38)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromRGB(255, 235, 120)
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.Text = "Segera dorong gerobak masuk ke GANG AMAN (Safe Zone)!"
    sub.Parent = banner

    -- Bar hitung mundur di bagian bawah banner
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, -24, 0, 5)
    barBg.Position = UDim2.new(0, 12, 1, -9)
    barBg.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
    barBg.BorderSizePixel = 0
    barBg.Parent = banner

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 3)
    barCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.fromScale(1, 1)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 220, 30)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = barFill

    -- 2. Dazed Vignette Overlay (Layar merah pusing saat tertangkap)
    local dazed = Instance.new("Frame")
    dazed.Name = "DazedOverlay"
    dazed.Size = UDim2.fromScale(1, 1)
    dazed.BackgroundColor3 = Color3.fromRGB(120, 15, 15)
    dazed.BackgroundTransparency = 1
    dazed.Visible = false
    dazed.Parent = screenGui

    local dazedCenter = Instance.new("Frame")
    dazedCenter.Name = "CenterBox"
    dazedCenter.Size = UDim2.new(0, 440, 0, 180)
    dazedCenter.Position = UDim2.new(0.5, -220, 0.5, -90)
    dazedCenter.BackgroundColor3 = Color3.fromRGB(25, 20, 22)
    dazedCenter.BackgroundTransparency = 0.05
    dazedCenter.Parent = dazed

    local dazedCorner = Instance.new("UICorner")
    dazedCorner.CornerRadius = UDim.new(0, 14)
    dazedCorner.Parent = dazedCenter

    local dazedStroke = Instance.new("UIStroke")
    dazedStroke.Color = Color3.fromRGB(220, 50, 50)
    dazedStroke.Thickness = 3
    dazedStroke.Parent = dazedCenter

    local dazedTitle = Instance.new("TextLabel")
    dazedTitle.Name = "Title"
    dazedTitle.Size = UDim2.new(1, -20, 0, 44)
    dazedTitle.Position = UDim2.new(0, 10, 0, 12)
    dazedTitle.BackgroundTransparency = 1
    dazedTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
    dazedTitle.Font = Enum.Font.FredokaOne
    dazedTitle.TextScaled = true
    dazedTitle.Text = "😵 WADUH KENA RAZIA SATPOL PP! 😵"
    dazedTitle.Parent = dazedCenter

    local dazedDesc = Instance.new("TextLabel")
    dazedDesc.Name = "Desc"
    dazedDesc.Size = UDim2.new(1, -20, 0, 60)
    dazedDesc.Position = UDim2.new(0, 10, 0, 58)
    dazedDesc.BackgroundTransparency = 1
    dazedDesc.TextColor3 = Color3.fromRGB(255, 255, 255)
    dazedDesc.Font = Enum.Font.GothamMedium
    dazedDesc.TextScaled = true
    dazedDesc.Text = "Uang Kas disita 25% & gorengan ludes disita petugas!\nGerobak dipulangkan ke pangkalan."
    dazedDesc.Parent = dazedCenter

    local dazedSafeNote = Instance.new("TextLabel")
    dazedSafeNote.Name = "SafeNote"
    dazedSafeNote.Size = UDim2.new(1, -20, 0, 24)
    dazedSafeNote.Position = UDim2.new(0, 10, 0, 130)
    dazedSafeNote.BackgroundTransparency = 1
    dazedSafeNote.TextColor3 = Color3.fromRGB(100, 255, 140)
    dazedSafeNote.Font = Enum.Font.GothamBold
    dazedSafeNote.TextScaled = true
    dazedSafeNote.Text = "🛡️ Uang tabunganmu di ATM tetap 100% AMAN!"
    dazedSafeNote.Parent = dazedCenter

    screenGui.Parent = playerGui

    self._gui = screenGui
    self._bannerFrame = banner
    self._titleLabel = title
    self._subLabel = sub
    self._countdownBar = barFill
    self._dazedOverlay = dazed
end

function RaidController:_ensureUI()
    if not self._bannerFrame or not self._bannerFrame.Parent then
        self:_createRaidUI()
    end
end

function RaidController:HandleRaidAlert(state: string, duration: number, message: string)
    self:_ensureUI()

    if not self._bannerFrame or not self._titleLabel or not self._subLabel or not self._countdownBar then
        return
    end

    if self._activeCountdownThread then
        task.cancel(self._activeCountdownThread)
        self._activeCountdownThread = nil
    end

    local banner = self._bannerFrame
    local title = self._titleLabel
    local sub = self._subLabel
    local bar = self._countdownBar

    if state == "Warning" then
        banner.Visible = true
        banner.BackgroundColor3 = Color3.fromRGB(190, 30, 30)
        title.Text = string.format("🚨 AWAS SATPOL PP! RAZIA DALAM %d DETIK! 🚨", duration)
        sub.Text = "Segera dorong gerobak masuk ke GANG AMAN (Safe Zone)!"

        -- Animasi muncul banner turun dari atas
        banner.Position = UDim2.new(0.5, -260, 0, -100)
        TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -260, 0, 68),
        }):Play()

        -- Hitung mundur bar visual & pembaruan teks
        self._activeCountdownThread = task.spawn(function()
            local total = duration
            local remaining = total
            bar.Size = UDim2.fromScale(1, 1)

            TweenService:Create(bar, TweenInfo.new(total, Enum.EasingStyle.Linear), {
                Size = UDim2.fromScale(0, 1),
            }):Play()

            while remaining > 0 do
                title.Text = string.format("🚨 AWAS SATPOL PP! RAZIA DALAM %d DETIK! 🚨", math.ceil(remaining))
                task.wait(1.0)
                remaining -= 1
            end
        end)

    elseif state == "Active" then
        banner.Visible = true
        banner.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
        title.Text = "⚠️ RAZIA SATPOL SEDANG BERLANGSUNG! ⚠️"
        sub.Text = "Pasukan Satpol PP berpatroli! Bertahanlah di Gang Aman!"
        bar.Size = UDim2.fromScale(1, 1)

        TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -260, 0, 68),
        }):Play()

    elseif state == "Ended" then
        banner.BackgroundColor3 = Color3.fromRGB(30, 130, 50)
        title.Text = "✅ RAZIA TELAH USAI! JALAN KEMBALI AMAN! ✅"
        sub.Text = "Silakan kembali berjualan gorengan dengan tenang."
        bar.Size = UDim2.fromScale(1, 1)

        task.delay(4.0, function()
            TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -260, 0, -100),
            }):Play()
            task.wait(0.4)
            banner.Visible = false
        end)
    end
end

function RaidController:ShowCapturedVignette(penaltyAmount: number)
    self:_ensureUI()
    local dazed = self._dazedOverlay
    if not dazed then return end

    local centerBox = dazed:FindFirstChild("CenterBox") :: Frame?
    local desc = centerBox and centerBox:FindFirstChild("Desc") :: TextLabel?

    if desc then
        desc.Text = string.format("Uang Kas disita 25%% (-Rp %s) & gorengan habis disita petugas!\nGerobak dipulangkan ke pangkalan.", tostring(penaltyAmount))
    end

    dazed.Visible = true
    dazed.BackgroundTransparency = 1

    -- Efek flash pusing merah
    TweenService:Create(dazed, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.45,
    }):Play()

    -- Efek getar ringan (comedic screen shake)
    if centerBox then
        local originalPos = UDim2.new(0.5, -220, 0.5, -90)
        task.spawn(function()
            for _ = 1, 8 do
                local ox = math.random(-8, 8)
                local oy = math.random(-6, 6)
                centerBox.Position = originalPos + UDim2.new(0, ox, 0, oy)
                task.wait(0.04)
            end
            centerBox.Position = originalPos
        end)
    end

    -- Otomatis pudar kembali setelah 4 detik
    task.delay(3.5, function()
        local tw = TweenService:Create(dazed, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
        })
        tw:Play()
        tw.Completed:Connect(function()
            dazed.Visible = false
        end)
    end)
end

return RaidController