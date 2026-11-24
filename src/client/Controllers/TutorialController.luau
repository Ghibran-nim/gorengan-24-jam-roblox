--!strict
--[[
    TutorialController.luau
    Mengelola antarmuka visual alur tutorial pemula (Onboarding HUD) di sisi client:
    - Menampilkan kartu panduan interaktif di tengah atas layar
    - Memberikan instruksi konkret langkah demi langkah
    - Menyediakan tombol "Lewati" jika pemain sudah berpengalaman
    - Memainkan animasi transisi halus antar-langkah
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("TutorialController")

local TutorialController = {
    Name = "TutorialController",
    _gui = nil :: ScreenGui?,
    _cardFrame = nil :: Frame?,
    _titleLabel = nil :: TextLabel?,
    _descLabel = nil :: TextLabel?,
    _stepBadge = nil :: TextLabel?,
    _isCompleted = false,
}

function TutorialController:Init()
    log:Info("Menginisialisasi TutorialController...")

    -- Dengarkan update langkah dari server
    NetworkBridge.OnClientEvent(
        Remotes.Events.TutorialStepUpdated,
        function(currentStep: number, totalSteps: number, title: string, description: string, isFinished: boolean)
            self:UpdateTutorialCard(currentStep, totalSteps, title, description, isFinished)
        end
    )
end

function TutorialController:Start()
    log:Info("TutorialController aktif. Meminta status tutorial...")

    self:_createTutorialGui()

    -- Minta status terkini dari server
    task.spawn(function()
        task.wait(1.0)
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetTutorialState)
        if res and res.Success then
            self:UpdateTutorialCard(
                res.CurrentStep,
                res.TotalSteps,
                res.StepTitle,
                res.StepDescription,
                res.IsCompleted or res.IsSkipped
            )
        end
    end)
end

function TutorialController:_createTutorialGui()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("TutorialHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TutorialHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Kontainer kartu panduan (Tengah atas di bawah Header bar)
    local card = Instance.new("Frame")
    card.Name = "TutorialCard"
    card.Size = UDim2.new(0, 480, 0, 76)
    card.Position = UDim2.new(0.5, -240, 0, 68)
    card.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Visible = false
    card.Parent = screenGui
    self._cardFrame = card

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(245, 185, 35)
    stroke.Thickness = 2
    stroke.Parent = card

    -- Badge nomor langkah
    local badge = Instance.new("TextLabel")
    badge.Name = "StepBadge"
    badge.Size = UDim2.new(0, 80, 0, 24)
    badge.Position = UDim2.new(0, 12, 0, 8)
    badge.BackgroundColor3 = Color3.fromRGB(230, 155, 25)
    badge.TextColor3 = Color3.fromRGB(255, 255, 255)
    badge.Font = Enum.Font.FredokaOne
    badge.TextSize = 12
    badge.Text = "LANGKAH 1/5"
    badge.Parent = card
    self._stepBadge = badge

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = badge

    -- Judul Langkah
    local title = Instance.new("TextLabel")
    title.Name = "TitleLabel"
    title.Size = UDim2.new(1, -190, 0, 24)
    title.Position = UDim2.new(0, 98, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 230, 150)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Temukan Gerobakmu!"
    title.Parent = card
    self._titleLabel = title

    -- Deskripsi / Panduan Langkah
    local desc = Instance.new("TextLabel")
    desc.Name = "DescLabel"
    desc.Size = UDim2.new(1, -24, 0, 36)
    desc.Position = UDim2.new(0, 12, 0, 34)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = Color3.fromRGB(220, 225, 235)
    desc.Font = Enum.Font.GothamMedium
    desc.TextSize = 12
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Text = "Gerobakmu telah disiapkan di Plot #1. Dekati gerobakmu untuk memulai usaha!"
    desc.Parent = card
    self._descLabel = desc

    -- Tombol Lewati Tutorial
    local skipBtn = Instance.new("TextButton")
    skipBtn.Name = "SkipButton"
    skipBtn.Size = UDim2.new(0, 70, 0, 22)
    skipBtn.Position = UDim2.new(1, -80, 0, 9)
    skipBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
    skipBtn.TextColor3 = Color3.fromRGB(200, 205, 215)
    skipBtn.Font = Enum.Font.FredokaOne
    skipBtn.TextSize = 11
    skipBtn.Text = "Lewati ⏩"
    skipBtn.Parent = card

    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 5)
    skipCorner.Parent = skipBtn

    skipBtn.MouseButton1Click:Connect(function()
        NetworkBridge.InvokeServer(Remotes.Functions.RequestSkipTutorial)
        card.Visible = false
    end)

    self._gui = screenGui
    screenGui.Parent = playerGui
end

function TutorialController:UpdateTutorialCard(currentStep: number, totalSteps: number, title: string, description: string, isFinished: boolean)
    if not self._cardFrame then return end

    if isFinished then
        self._isCompleted = true
        local tween = TweenService:Create(self._cardFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -240, 0, -100),
            BackgroundTransparency = 1,
        })
        tween:Play()
        tween.Completed:Connect(function()
            self._cardFrame.Visible = false
        end)
        return
    end

    self._cardFrame.Visible = true

    if self._stepBadge then
        self._stepBadge.Text = string.format("LANGKAH %d/%d", currentStep, totalSteps)
    end
    if self._titleLabel then
        self._titleLabel.Text = title
    end
    if self._descLabel then
        self._descLabel.Text = description
    end

    -- Animasi transisi pergantian langkah
    self._cardFrame.Position = UDim2.new(0.5, -240, 0, 55)
    TweenService:Create(self._cardFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -240, 0, 68),
    }):Play()
end

return TutorialController
