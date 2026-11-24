--!strict
--[[
    CookingController.luau
    Mengelola antarmuka grafis meteran memasak (Cooking HUD),
    indikator kematangan real-time (Undercooked 0–30%, Crispy 31–80%, Burnt 81–100%),
    serta feedback visual & audio saat gorengan diangkat dari wajan.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("CookingController")

local CookingController = {
    Name = "CookingController",
    _isCooking = false,
    _activeRecipeId = "",
    _startTime = 0,
    _totalDuration = 10.0,
    _gui = nil :: ScreenGui?,
    _containerFrame = nil :: Frame?,
    _needle = nil :: Frame?,
    _statusLabel = nil :: TextLabel?,
    _liftButton = nil :: TextButton?,
    _renderConn = nil :: RBXScriptConnection?,
}

-- Palet warna visual meter kematangan
local METER_COLORS = {
    Undercooked = Color3.fromRGB(80, 140, 200),
    Crispy = Color3.fromRGB(245, 185, 35),
    Burnt = Color3.fromRGB(210, 45, 45),
}

function CookingController:Init()
    log:Info("Menginisialisasi CookingController...")

    -- Dengarkan event perubahan status masak dari server
    NetworkBridge.OnClientEvent(Remotes.Events.CookStateChanged, function(state: string, recipeId: string, startTime: number, totalDuration: number)
        if state == "Cooking" then
            self:OpenCookingMeter(recipeId, startTime, totalDuration)
        else
            self:CloseCookingMeter()
        end
    end)

    -- Dengarkan event hasil makanan yang diangkat
    NetworkBridge.OnClientEvent(Remotes.Events.FoodCollected, function(quality: string, recipeId: string)
        self:_showOutcomeFeedback(quality, recipeId)
    end)

    self:_createCookingGUI()
end

function CookingController:Start()
    log:Info("CookingController aktif.")
end

function CookingController:_createCookingGUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("CookingScreenHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CookingScreenHUD"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Panel Utama Meteran Memasak (Bawah Tengah)
    local container = Instance.new("Frame")
    container.Name = "MeterContainer"
    container.Size = UDim2.new(0, 380, 0, 140)
    container.Position = UDim2.new(0.5, -190, 1, -170)
    container.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 65, 75)
    stroke.Thickness = 2
    stroke.Parent = container

    -- Judul resep yang sedang digoreng
    local recipeLabel = Instance.new("TextLabel")
    recipeLabel.Name = "RecipeTitle"
    recipeLabel.Size = UDim2.new(1, -20, 0, 24)
    recipeLabel.Position = UDim2.new(0, 10, 0, 6)
    recipeLabel.BackgroundTransparency = 1
    recipeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    recipeLabel.Font = Enum.Font.FredokaOne
    recipeLabel.TextSize = 16
    recipeLabel.Text = "SEDANG MENGGORENG BAKWAN SAYUR"
    recipeLabel.Parent = container

    -- Track Bar Meteran (Panjang 340 pixel)
    local barTrack = Instance.new("Frame")
    barTrack.Name = "BarTrack"
    barTrack.Size = UDim2.new(0, 340, 0, 26)
    barTrack.Position = UDim2.new(0.5, -170, 0, 34)
    barTrack.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
    barTrack.BorderSizePixel = 0
    barTrack.ClipsDescendants = true
    barTrack.Parent = container

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 6)
    barCorner.Parent = barTrack

    -- Zona 1: Undercooked (0 - 30%)
    local zoneUndercooked = Instance.new("Frame")
    zoneUndercooked.Name = "Zone_Undercooked"
    zoneUndercooked.Size = UDim2.new(0.30, 0, 1, 0)
    zoneUndercooked.Position = UDim2.new(0, 0, 0, 0)
    zoneUndercooked.BackgroundColor3 = METER_COLORS.Undercooked
    zoneUndercooked.BorderSizePixel = 0
    zoneUndercooked.Parent = barTrack

    -- Zona 2: Crispy (31 - 80%)
    local zoneCrispy = Instance.new("Frame")
    zoneCrispy.Name = "Zone_Crispy"
    zoneCrispy.Size = UDim2.new(0.50, 0, 1, 0)
    zoneCrispy.Position = UDim2.new(0.30, 0, 0, 0)
    zoneCrispy.BackgroundColor3 = METER_COLORS.Crispy
    zoneCrispy.BorderSizePixel = 0
    zoneCrispy.Parent = barTrack

    -- Zona 3: Burnt (81 - 100%)
    local zoneBurnt = Instance.new("Frame")
    zoneBurnt.Name = "Zone_Burnt"
    zoneBurnt.Size = UDim2.new(0.20, 0, 1, 0)
    zoneBurnt.Position = UDim2.new(0.80, 0, 0, 0)
    zoneBurnt.BackgroundColor3 = METER_COLORS.Burnt
    zoneBurnt.BorderSizePixel = 0
    zoneBurnt.Parent = barTrack

    -- Jarum / Needle Penunjuk Waktu Memasak
    local needle = Instance.new("Frame")
    needle.Name = "Needle"
    needle.Size = UDim2.new(0, 4, 1, 6)
    needle.Position = UDim2.new(0, -2, 0, -3)
    needle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    needle.BorderSizePixel = 0
    needle.ZIndex = 5
    needle.Parent = barTrack

    -- Label status teks kematangan real-time
    local status = Instance.new("TextLabel")
    status.Name = "StatusLabel"
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 64)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(240, 200, 80)
    status.Font = Enum.Font.SourceSansBold
    status.TextSize = 14
    status.Text = "⏳ Masih mentah..."
    status.Parent = container

    -- Tombol Angkat Gorengan (Touch & Mouse Friendly)
    local liftBtn = Instance.new("TextButton")
    liftBtn.Name = "LiftButton"
    liftBtn.Size = UDim2.new(0, 200, 0, 36)
    liftBtn.Position = UDim2.new(0.5, -100, 0, 92)
    liftBtn.BackgroundColor3 = Color3.fromRGB(230, 150, 30)
    liftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    liftBtn.Font = Enum.Font.FredokaOne
    liftBtn.TextSize = 16
    liftBtn.Text = "ANGKAT GORENGAN [E]"
    liftBtn.Parent = container

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = liftBtn

    liftBtn.MouseButton1Click:Connect(function()
        self:RequestLiftFood()
    end)

    -- Shortcut tombol keyboard Spacebar / E
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self._isCooking then return end
        if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
            self:RequestLiftFood()
        end
    end)

    self._gui = screenGui
    self._containerFrame = container
    self._needle = needle
    self._statusLabel = status
    self._liftButton = liftBtn
    screenGui.Parent = playerGui
end

function CookingController:OpenCookingMeter(recipeId: string, startTime: number, totalDuration: number)
    self._isCooking = true
    self._activeRecipeId = recipeId
    self._startTime = startTime
    self._totalDuration = totalDuration or 10.0

    if self._gui then
        self._gui.Enabled = true
    end

    local title = self._containerFrame and self._containerFrame:FindFirstChild("RecipeTitle") :: TextLabel?
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if title and recipe then
        title.Text = "MENGGORENG " .. recipe.Name:upper()
    end

    -- Loop render update jarum meteran per frame
    if self._renderConn then self._renderConn:Disconnect() end
    self._renderConn = RunService.RenderStepped:Connect(function()
        if not self._isCooking then return end

        local elapsed = os.clock() - self._startTime
        local progress = math.clamp(elapsed / self._totalDuration, 0, 1.0)

        -- Geser posisi jarum
        if self._needle then
            self._needle.Position = UDim2.new(progress, -2, 0, -3)
        end

        -- Update teks status berdasarkan persentase
        if self._statusLabel then
            if progress <= 0.30 then
                self._statusLabel.Text = string.format("⏳ Masih Mentah (%.1f s) — Tunggu keemasan!", elapsed)
                self._statusLabel.TextColor3 = METER_COLORS.Undercooked
                if self._liftButton then
                    self._liftButton.BackgroundColor3 = Color3.fromRGB(100, 120, 140)
                end
            elseif progress <= 0.80 then
                self._statusLabel.Text = string.format("🌟 CRISPY EMAS! (%.1f s) — ANGKAT SEKARANG! 🌟", elapsed)
                self._statusLabel.TextColor3 = METER_COLORS.Crispy
                if self._liftButton then
                    self._liftButton.BackgroundColor3 = Color3.fromRGB(230, 160, 30)
                end
            else
                self._statusLabel.Text = string.format("🔥 GOSONG! (%.1f s) — Angkat cepat!", elapsed)
                self._statusLabel.TextColor3 = METER_COLORS.Burnt
                if self._liftButton then
                    self._liftButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                end
            end
        end
    end)

    log:Info("Cooking HUD dibuka untuk resep '%s' (Durasi: %.1f s)", recipeId, totalDuration)
end

function CookingController:CloseCookingMeter()
    self._isCooking = false
    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end

    if self._gui then
        self._gui.Enabled = false
    end
end

function CookingController:RequestLiftFood()
    if not self._isCooking then return end
    log:Info("Client meminta mengangkat gorengan dari wajan...")
    self:CloseCookingMeter()

    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestCollectFood)
    if not res or not res.Success then
        log:Warn("Gagal mengangkat makanan: %s", tostring(res and res.Error or "Unknown error"))
    end
end

function CookingController:_showOutcomeFeedback(quality: string, recipeId: string)
    local recipe = RecipesConfig.GetRecipe(recipeId)
    local recipeName = if recipe then recipe.Name else recipeId

    local message: string
    if quality == "Crispy" then
        message = string.format("🌟 CRISPY SEMPURNA! %s matang keemasan (+20%% Tips)!", recipeName)
    elseif quality == "Undercooked" then
        message = string.format("⚠️ MASIH MENTAH! %s belum renyah (Harga -50%%).", recipeName)
    else
        message = string.format("🔥 GOSONG! %s hangus terbakar (Menjadi senjata lempar)!", recipeName)
    end

    log:Info("Hasil Memasak: %s", message)

    -- Tampilkan alert sederhana melalui HUDController
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, quality)
    end
end

return CookingController
