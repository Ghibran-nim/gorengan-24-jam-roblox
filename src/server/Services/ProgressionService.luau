--!strict
--[[
    ProgressionService.luau
    Layanan otoritatif server untuk sistem Level, XP, Unlock Resep, dan Gelar Pedagang.
    Memberikan tujuan jangka pendek (buka resep awal & upgrade cepat) hingga
    jangka panjang (Risol Mayo, Kasir NPC, dan gelar Raja Gorengan 24 Jam).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type ProgressionData = GameplayTypes.ProgressionData

local log = Logger.new("ProgressionService")

local ProgressionService = {
    Name = "ProgressionService",
    _playerProgress = {} :: { [number]: ProgressionData },
    _services = {} :: { [string]: any },
}

function ProgressionService:_getService(serviceName: string): any
    if not self._services[serviceName] then
        local servicesFolder = script and script.Parent
        local mod = if servicesFolder then servicesFolder:FindFirstChild(serviceName) else nil
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

function ProgressionService:Init()
    log:Info("Menginisialisasi ProgressionService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupPlayerProgress(player)
    end)

    for _, player in Players:GetPlayers() do
        self:_setupPlayerProgress(player)
    end

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetProgression, function(player: Player)
        local prog = self:GetProgression(player)
        return { Success = true, Progression = prog }
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestUnlockRecipe, function(player: Player, recipeId: any)
        if typeof(recipeId) ~= "string" or #recipeId > 40 then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:UnlockRecipe(player, recipeId)
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestSetSelectedRecipe, function(player: Player, recipeId: any)
        if typeof(recipeId) ~= "string" or #recipeId > 40 then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:SetSelectedRecipe(player, recipeId)
    end)
end

function ProgressionService:Start()
    self:_getService("EconomyService")
    self:_getService("CartService")
    local dataService = self:_getService("DataService")
    if dataService and dataService.RegisterDomain then
        dataService:RegisterDomain("Progression",
            function(player: Player, profile: any)
                local userId = player.UserId
                local src = profile.Progression
                self._playerProgress[userId] = {
                    Level = src.Level,
                    XP = src.XP,
                    TotalXP = src.TotalXP,
                    NextLevelXP = src.NextLevelXP,
                    Title = src.Title,
                    UnlockedRecipes = table.clone(src.UnlockedRecipes),
                    SelectedRecipeId = src.SelectedRecipeId,
                    TotalSales = src.TotalSales,
                    TotalEarnings = src.TotalEarnings,
                }
                local recipe = RecipesConfig.GetRecipe(src.SelectedRecipeId)
                local cartService = self:_getService("CartService")
                if recipe and cartService and cartService.UpdateCartCookPrompt then
                    cartService:UpdateCartCookPrompt(player, recipe.Name)
                end
                self:SyncProgression(player)
                local socialService = self:_getService("SocialService")
                if socialService and socialService.RefreshPlayerStats then
                    socialService:RefreshPlayerStats(player)
                    socialService:ScheduleLeaderboardBroadcast()
                end
            end,
            function(player: Player, profile: any)
                local prog = self._playerProgress[player.UserId]
                if prog then
                    profile.Progression.Level = prog.Level
                    profile.Progression.XP = prog.XP
                    profile.Progression.TotalXP = prog.TotalXP
                    profile.Progression.NextLevelXP = prog.NextLevelXP
                    profile.Progression.Title = prog.Title
                    profile.Progression.UnlockedRecipes = table.clone(prog.UnlockedRecipes)
                    profile.Progression.SelectedRecipeId = prog.SelectedRecipeId
                    profile.Progression.TotalSales = prog.TotalSales
                    profile.Progression.TotalEarnings = prog.TotalEarnings
                end
            end,
            function(userId: number)
                self._playerProgress[userId] = nil
            end
        )
    end
    log:Info("ProgressionService aktif.")
end

function ProgressionService:_setupPlayerProgress(player: Player)
    local userId = player.UserId
    if not self._playerProgress[userId] then
        local lvl1Next = ProgressionConfig.GetXPThreshold(2)
        self._playerProgress[userId] = {
            Level = 1,
            XP = 0,
            TotalXP = 0,
            NextLevelXP = lvl1Next,
            Title = ProgressionConfig.GetTitleForLevel(1),
            UnlockedRecipes = {
                ["bakwan_sayur"] = true,
            },
            SelectedRecipeId = "bakwan_sayur",
            TotalSales = 0,
            TotalEarnings = 0,
        }
        self:SyncProgression(player)
    end
end

function ProgressionService:GetProgression(player: Player): ProgressionData
    if not self._playerProgress[player.UserId] then
        self:_setupPlayerProgress(player)
    end
    return self._playerProgress[player.UserId]
end

function ProgressionService:SyncProgression(player: Player)
    local prog = self._playerProgress[player.UserId]
    if prog then
        local dataService = self:_getService("DataService")
        if dataService and dataService.MarkDirty then
            dataService:MarkDirty(player, "ProgressionChanged")
        end
        NetworkBridge.FireClient(player, Remotes.Events.ProgressionUpdated, prog)
    end
end

function ProgressionService:IsRecipeUnlocked(player: Player, recipeId: string): boolean
    local prog = self:GetProgression(player)
    return prog.UnlockedRecipes[recipeId] == true
end

function ProgressionService:GetUnlockedRecipeIds(player: Player): { string }
    local prog = self:GetProgression(player)
    local list = {}
    for recipeId, unlocked in pairs(prog.UnlockedRecipes) do
        if unlocked then
            table.insert(list, recipeId)
        end
    end
    if #list == 0 then
        table.insert(list, "bakwan_sayur")
    end
    table.sort(list)
    return list
end

function ProgressionService:GetSelectedRecipe(player: Player): string
    local prog = self:GetProgression(player)
    if prog.UnlockedRecipes[prog.SelectedRecipeId] then
        return prog.SelectedRecipeId
    end
    return "bakwan_sayur"
end

function ProgressionService:AddXP(player: Player, amount: number, reason: string?): boolean
    if typeof(amount) ~= "number" or amount <= 0 then
        return false
    end

    local prog = self:GetProgression(player)
    local oldLevel = prog.Level
    prog.TotalXP += math.floor(amount)

    local newLevel = ProgressionConfig.GetLevelForTotalXP(prog.TotalXP)
    local currentFloor = ProgressionConfig.GetXPThreshold(newLevel)
    local nextThreshold = ProgressionConfig.GetXPThreshold(math.min(newLevel + 1, ProgressionConfig.MaxLevel))

    prog.Level = newLevel
    prog.Title = ProgressionConfig.GetTitleForLevel(newLevel)
    prog.XP = prog.TotalXP - currentFloor
    prog.NextLevelXP = if newLevel >= ProgressionConfig.MaxLevel then 0 else (nextThreshold - currentFloor)

    log:Debug("XP %s: +%d (%s) -> Lv.%d (%d/%d XP)", player.Name, amount, tostring(reason or ""), prog.Level, prog.XP, prog.NextLevelXP)

    if newLevel > oldLevel then
        log:Info("LEVEL UP! %s naik ke Level %d (%s)", player.Name, newLevel, prog.Title)
        NetworkBridge.FireClient(player, Remotes.Events.LevelUpAchieved, newLevel, prog.Title)
        local socialService = self:_getService("SocialService")
        if socialService and socialService.RefreshPlayerStats then
            socialService:RefreshPlayerStats(player)
            socialService:ScheduleLeaderboardBroadcast()
        end
    end

    self:SyncProgression(player)
    return true
end

function ProgressionService:RecordSale(player: Player, payout: number)
    local prog = self:GetProgression(player)
    prog.TotalSales += 1
    prog.TotalEarnings += math.max(0, payout)
    self:SyncProgression(player)
    local socialService = self:_getService("SocialService")
    if socialService and socialService.RefreshPlayerStats then
        socialService:RefreshPlayerStats(player)
        socialService:ScheduleLeaderboardBroadcast()
    end
end

function ProgressionService:UnlockRecipe(player: Player, recipeId: string): { Success: boolean, Error: string?, RecipeName: string?, Progression: ProgressionData? }
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if not recipe then
        return { Success = false, Error = "Resep gorengan tidak ditemukan!" }
    end

    local prog = self:GetProgression(player)
    if prog.UnlockedRecipes[recipeId] then
        return { Success = false, Error = "Resep ini sudah kamu kuasai!" }
    end

    if prog.Level < recipe.UnlockLevel then
        return {
            Success = false,
            Error = string.format("Membutuhkan Level %d untuk membuka %s (Level kamu: %d)!", recipe.UnlockLevel, recipe.Name, prog.Level),
        }
    end

    local ecoService = self:_getService("EconomyService")
    if not ecoService then
        return { Success = false, Error = "Layanan ekonomi tidak tersedia!" }
    end

    if recipe.UnlockCost > 0 then
        local deducted = ecoService:DeductCarriedCash(player, recipe.UnlockCost, "Buka Resep " .. recipe.Name)
        if not deducted then
            local wallet = ecoService:GetWallet(player)
            local cash = if wallet then wallet.CarriedCash else 0
            return {
                Success = false,
                Error = string.format("Uang kas tidak cukup! Biaya buka resep: Rp %d (Kas: Rp %d)", recipe.UnlockCost, cash),
            }
        end
    end

    prog.UnlockedRecipes[recipeId] = true
    prog.SelectedRecipeId = recipeId

    local cartService = self:_getService("CartService")
    if cartService and cartService.UpdateCartCookPrompt then
        cartService:UpdateCartCookPrompt(player, recipe.Name)
    end

    log:Info("UNLOCK RESEP: %s membuka resep '%s' (Biaya: Rp %d)", player.Name, recipe.Name, recipe.UnlockCost)
    NetworkBridge.FireClient(player, Remotes.Events.RecipeUnlocked, recipeId, recipe.Name)
    self:SyncProgression(player)

    return { Success = true, RecipeName = recipe.Name, Progression = prog }
end

function ProgressionService:SetSelectedRecipe(player: Player, recipeId: string): { Success: boolean, Error: string?, SelectedRecipeId: string? }
    local recipe = RecipesConfig.GetRecipe(recipeId)
    if not recipe then
        return { Success = false, Error = "Resep tidak ditemukan!" }
    end

    local prog = self:GetProgression(player)
    if not prog.UnlockedRecipes[recipeId] then
        return { Success = false, Error = "Kamu belum membuka resep " .. recipe.Name .. "!" }
    end

    prog.SelectedRecipeId = recipeId

    local cartService = self:_getService("CartService")
    if cartService and cartService.UpdateCartCookPrompt then
        cartService:UpdateCartCookPrompt(player, recipe.Name)
    end

    self:SyncProgression(player)
    return { Success = true, SelectedRecipeId = recipeId }
end

return ProgressionService