--!strict
--[[
    RecipesConfig.luau
    Sistem resep gorengan modular dengan parameter ekonomi, kesulitan,
    karakteristik kematangan dinamis, serta level & biaya unlock.
]]

local GameplayTypes = require(script.Parent.Parent:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Recipe = GameplayTypes.Recipe

local Recipes: { [string]: Recipe } = {
    ["bakwan_sayur"] = {
        Id = "bakwan_sayur",
        Name = "Bakwan Sayur",
        Icon = "🥟",
        Difficulty = "Mudah",
        UnlockLevel = 1,
        UnlockCost = 0,
        BasePrice = 2200,
        TotalCookDuration = 9.0,
        UndercookedMaxPercent = 0.28,
        CrispyMaxPercent = 0.84,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["batter"] = 1, ["veggies"] = 1 },
        Description = "Gorengan pemula sejuta umat! Zona crispy sangat lebar dan ramah pemula.",
    },
    ["tempe_mendoan"] = {
        Id = "tempe_mendoan",
        Name = "Tempe Mendoan",
        Icon = "🥢",
        Difficulty = "Mudah",
        UnlockLevel = 1,
        UnlockCost = 8000,
        BasePrice = 2600,
        TotalCookDuration = 8.0,
        UndercookedMaxPercent = 0.30,
        CrispyMaxPercent = 0.80,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["tempeh"] = 1, ["batter"] = 1 },
        Description = "Tempe tepung khas Banyumas yang cepat matang. Cocok untuk kejar setoran awal!",
    },
    ["pisang_goreng"] = {
        Id = "pisang_goreng",
        Name = "Pisang Goreng",
        Icon = "🍌",
        Difficulty = "Sedang",
        UnlockLevel = 2,
        UnlockCost = 18000,
        BasePrice = 3200,
        TotalCookDuration = 10.0,
        UndercookedMaxPercent = 0.34,
        CrispyMaxPercent = 0.78,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["banana"] = 1, ["batter"] = 1 },
        Description = "Pisang kepok manis legit berbalut tepung kremes keemasan.",
    },
    ["cireng_crispy"] = {
        Id = "cireng_crispy",
        Name = "Cireng Bumbu Rujak",
        Icon = "🥣",
        Difficulty = "Sedang",
        UnlockLevel = 3,
        UnlockCost = 32000,
        BasePrice = 4000,
        TotalCookDuration = 11.0,
        UndercookedMaxPercent = 0.36,
        CrispyMaxPercent = 0.76,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["acitapioca"] = 1, ["veggies"] = 1 },
        Description = "Aci digoreng renyah di luar, kenyal di dalam, favorit anak kos & ojol.",
    },
    ["tahu_isi"] = {
        Id = "tahu_isi",
        Name = "Tahu Isi Jeletot",
        Icon = "🧈",
        Difficulty = "Menengah",
        UnlockLevel = 4,
        UnlockCost = 55000,
        BasePrice = 5200,
        TotalCookDuration = 12.5,
        UndercookedMaxPercent = 0.38,
        CrispyMaxPercent = 0.74,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["tofu"] = 1, ["veggies"] = 1, ["batter"] = 1 },
        Description = "Tahu pong montok isi sayur pedas berlimpah dengan margin keuntungan tebal.",
    },
    ["martabak_mini"] = {
        Id = "martabak_mini",
        Name = "Martabak Telor Mini",
        Icon = "🥚",
        Difficulty = "Sulit",
        UnlockLevel = 5,
        UnlockCost = 90000,
        BasePrice = 6800,
        TotalCookDuration = 13.5,
        UndercookedMaxPercent = 0.42,
        CrispyMaxPercent = 0.72,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["egg"] = 1, ["veggies"] = 1, ["batter"] = 1 },
        Description = "Menu premium kaya telur! Zona crispy lebih sempit, butuh fokus tinggi.",
    },
    ["risol_mayo"] = {
        Id = "risol_mayo",
        Name = "Risol Mayo Spesial",
        Icon = "🌯",
        Difficulty = "Ahli",
        UnlockLevel = 6,
        UnlockCost = 135000,
        BasePrice = 9000,
        TotalCookDuration = 14.0,
        UndercookedMaxPercent = 0.46,
        CrispyMaxPercent = 0.71,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["risol_skin"] = 1, ["egg"] = 1, ["batter"] = 1 },
        Description = "Gorengan kasta tertinggi incaran Sultan! Profit raksasa bagi koki presisi.",
    },
}

local RecipesConfig = {
    Recipes = Recipes,

    GetRecipe = function(id: string): Recipe?
        return Recipes[id]
    end,

    GetDefaultRecipeId = function(): string
        return "bakwan_sayur"
    end,

    GetAllRecipes = function(): { Recipe }
        local list = {}
        for _, recipe in pairs(Recipes) do
            table.insert(list, recipe)
        end
        table.sort(list, function(a, b)
            if a.UnlockLevel == b.UnlockLevel then
                return a.UnlockCost < b.UnlockCost
            end
            return a.UnlockLevel < b.UnlockLevel
        end)
        return list
    end,

    -- Evaluasi kualitas kematangan berdasarkan waktu elapsed & bonus upgrade
    EvaluateQuality = function(
        recipe: Recipe,
        elapsedSeconds: number,
        effectiveDurationOverride: number?,
        crispyUpperBonus: number?
    ): (GameplayTypes.QualityResult, number)
        local cookDur = effectiveDurationOverride or recipe.TotalCookDuration
        local progress = math.clamp(elapsedSeconds / cookDur, 0, 1.2)
        local crispyMax = math.min(recipe.CrispyMaxPercent + (crispyUpperBonus or 0), 0.94)
        local quality: GameplayTypes.QualityResult

        if progress <= recipe.UndercookedMaxPercent then
            quality = "Undercooked"
        elseif progress <= crispyMax then
            quality = "Crispy"
        else
            quality = "Burnt"
        end

        return quality, progress
    end,
}

return table.freeze(RecipesConfig)