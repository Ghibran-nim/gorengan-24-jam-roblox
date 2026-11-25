--!strict
--[[
    ProgressionController.luau
    Mengelola antarmuka level, XP bar, pemilihan resep aktif, serta feedback
    perayaan saat pemain naik level atau membuka resep gorengan baru.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ProgressionData = GameplayTypes.ProgressionData

local log = Logger.new("ProgressionController")

local ProgressionController = {
    Name = "ProgressionController",
    _progression = {
        Level = 1,
        XP = 0,
        TotalXP = 0,
        NextLevelXP = 150,
        Title = "Pedagang Pemula",
        UnlockedRecipes = { ["bakwan_sayur"] = true },
        SelectedRecipeId = "bakwan_sayur",
        TotalSales = 0,
        TotalEarnings = 0,
    } :: ProgressionData,
    _gui = nil :: ScreenGui?,
    _levelLabel = nil :: TextLabel?,
    _xpFill = nil :: Frame?,
    _xpText = nil :: TextLabel?,
    _menuBtn = nil :: TextButton?,
}

function ProgressionController:Init()
    log:Info("Menginisialisasi ProgressionController...")

    NetworkBridge.OnClientEvent(Remotes.Events.ProgressionUpdated, function(progData: any)
        if typeof(progData) == "table" then
            self._progression = progData :: ProgressionData
            self:_updateUI()
        end
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.LevelUpAchieved, function(newLevel: number, title: string)
        self:_notify(string.format("🎉 NAIK LEVEL %d! Gelar baru: %s! Cek menu & bengkel!", newLevel, tostring(title)), "Crispy")
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.RecipeUnlocked, function(_recipeId: string, recipeName: string)
        self:_notify(string.format("📖 RESEP BARU TERBUKA: %s! Siap digoreng!", tostring(recipeName)), "Success")
    end)

    self:_createProgressionHUD()
end

function ProgressionController:Start()
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetProgression)
        if res and res.Success and typeof(res.Progression) == "table" then
            self._progression = res.Progression
            self:_updateUI()
        end
    end)
    log:Info("ProgressionController aktif.")
end

function ProgressionController:_notify(message: string, alertType: string)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, alertType)
    end
end

function ProgressionController:_createProgressionHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ProgressionHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ProgressionHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Panel Progression di pojok kanan atas (aman dari TopHeaderBar & TutorialHUD)
    local panel = Instance.new("Frame")
    panel.Name = "ProgressionPanel"
    panel.Size = UDim2.new(0, 244, 0, 74)
    panel.Position = UDim2.new(1, -260, 0, 14)
    panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel = 0
    panel.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(235, 180, 45)
    stroke.Thickness = 1.5
    stroke.Parent = panel

    local lvlLabel = Instance.new("TextLabel")
    lvlLabel.Name = "LevelLabel"
    lvlLabel.Size = UDim2.new(1, -16, 0, 20)
    lvlLabel.Position = UDim2.new(0, 8, 0, 5)
    lvlLabel.BackgroundTransparency = 1
    lvlLabel.TextColor3 = Color3.fromRGB(245, 200, 60)
    lvlLabel.Font = Enum.Font.FredokaOne
    lvlLabel.TextSize = 14
    lvlLabel.TextXAlignment = Enum.TextXAlignment.Left
    lvlLabel.Text = "⭐ Lv.1 — Pedagang Pemula"
    lvlLabel.Parent = panel

    -- XP Bar
    local xpTrack = Instance.new("Frame")
    xpTrack.Name = "XPTrack"
    xpTrack.Size = UDim2.new(1, -16, 0, 14)
    xpTrack.Position = UDim2.new(0, 8, 0, 26)
    xpTrack.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
    xpTrack.BorderSizePixel = 0
    xpTrack.ClipsDescendants = true
    xpTrack.Parent = panel

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 5)
    trackCorner.Parent = xpTrack

    local xpFill = Instance.new("Frame")
    xpFill.Name = "XPFill"
    xpFill.Size = UDim2.fromScale(0, 1)
    xpFill.BackgroundColor3 = Color3.fromRGB(65, 200, 110)
    xpFill.BorderSizePixel = 0
    xpFill.Parent = xpTrack

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 5)
    fillCorner.Parent = xpFill

    local xpText = Instance.new("TextLabel")
    xpText.Name = "XPText"
    xpText.Size = UDim2.fromScale(1, 1)
    xpText.BackgroundTransparency = 1
    xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
    xpText.Font = Enum.Font.SourceSansBold
    xpText.TextSize = 11
    xpText.Text = "0 / 150 XP"
    xpText.ZIndex = 2
    xpText.Parent = xpTrack

    -- Tombol Pilih Menu Gorengan (Touch & Click)
    local menuBtn = Instance.new("TextButton")
    menuBtn.Name = "ActiveRecipeButton"
    menuBtn.Size = UDim2.new(1, -16, 0, 24)
    menuBtn.Position = UDim2.new(0, 8, 0, 44)
    menuBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 72)
    menuBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    menuBtn.Font = Enum.Font.FredokaOne
    menuBtn.TextSize = 12
    menuBtn.Text = "🍳 Menu: Bakwan Sayur [Ganti]"
    menuBtn.Parent = panel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = menuBtn

    menuBtn.MouseButton1Click:Connect(function()
        local ShopUIController = require(script.Parent:WaitForChild("ShopUIController"))
        if ShopUIController and (ShopUIController :: any).OpenRecipesModal then
            (ShopUIController :: any):OpenRecipesModal()
        end
    end)

    self._gui = screenGui
    self._levelLabel = lvlLabel
    self._xpFill = xpFill
    self._xpText = xpText
    self._menuBtn = menuBtn
    screenGui.Parent = playerGui
    self:_updateUI()
end

function ProgressionController:_updateUI()
    local prog = self._progression
    if self._levelLabel then
        self._levelLabel.Text = string.format("⭐ Lv.%d — %s", prog.Level, prog.Title)
    end
    if self._xpFill and self._xpText then
        if prog.NextLevelXP > 0 then
            local ratio = math.clamp(prog.XP / prog.NextLevelXP, 0, 1)
            self._xpFill.Size = UDim2.fromScale(ratio, 1)
            self._xpText.Text = string.format("%d / %d XP", prog.XP, prog.NextLevelXP)
        else
            self._xpFill.Size = UDim2.fromScale(1, 1)
            self._xpText.Text = "LEVEL MAKSIMAL!"
        end
    end
    if self._menuBtn then
        local recipe = RecipesConfig.GetRecipe(prog.SelectedRecipeId)
        local rName = if recipe then (recipe.Icon .. " " .. recipe.Name) else prog.SelectedRecipeId
        self._menuBtn.Text = string.format("🍳 %s [Ganti]", rName)
    end
end

function ProgressionController:GetProgression(): ProgressionData
    return self._progression
end

function ProgressionController:GetLevel(): number
    return self._progression.Level
end

function ProgressionController:GetSelectedRecipeId(): string
    return self._progression.SelectedRecipeId or "bakwan_sayur"
end

function ProgressionController:IsRecipeUnlocked(recipeId: string): boolean
    return self._progression.UnlockedRecipes[recipeId] == true
end

function ProgressionController:UnlockRecipe(recipeId: string)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestUnlockRecipe, recipeId)
    if res and res.Success then
        if res.Progression then
            self._progression = res.Progression
            self:_updateUI()
        end
        return true
    elseif res and res.Error then
        self:_notify("⚠️ " .. res.Error, "Warning")
    end
    return false
end

function ProgressionController:SelectRecipe(recipeId: string)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestSetSelectedRecipe, recipeId)
    if res and res.Success then
        self._progression.SelectedRecipeId = recipeId
        self:_updateUI()
        local recipe = RecipesConfig.GetRecipe(recipeId)
        self:_notify("🍳 Menu aktif diganti ke: " .. (if recipe then recipe.Name else recipeId), "Success")
        return true
    elseif res and res.Error then
        self:_notify("⚠️ " .. res.Error, "Warning")
    end
    return false
end

return ProgressionController