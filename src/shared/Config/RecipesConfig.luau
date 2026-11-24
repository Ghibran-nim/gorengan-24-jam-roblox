--!strict
--[[
    RecipesConfig.luau
    Daftar resep gorengan dengan parameter waktu masak dan ambang batas kematangan sesuai GDD:
    - Undercooked : 0–30%
    - Crispy      : 31–80% (Profit optimal)
    - Burnt       : 81–100%+ (Senjata lempar / throwable item)
]]

local GameplayTypes = require(script.Parent.Parent:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Recipe = GameplayTypes.Recipe

local Recipes: { [string]: Recipe } = {
    ["bakwan_sayur"] = {
        Id = "bakwan_sayur",
        Name = "Bakwan Sayur",
        BasePrice = 2000,
        TotalCookDuration = 10.0,    -- 10 detik total siklus
        UndercookedMaxPercent = 0.30, -- 0 - 3.0 detik
        CrispyMaxPercent = 0.80,      -- 3.1 - 8.0 detik (Window Crispy Emas)
        BurntMaxPercent = 1.00,       -- 8.1 - 10.0+ detik (Gosong)
        RequiredIngredients = { ["batter"] = 1, ["veggies"] = 1 },
        Description = "Gorengan renyah sejuta umat dengan irisan wortel dan kol segar.",
    },
    ["pisang_goreng"] = {
        Id = "pisang_goreng",
        Name = "Pisang Goreng",
        BasePrice = 2500,
        TotalCookDuration = 12.0,
        UndercookedMaxPercent = 0.30,
        CrispyMaxPercent = 0.80,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["banana"] = 1, ["batter"] = 1 },
        Description = "Pisang kepok manis berbalut tepung renyah keemasan.",
    },
    ["tahu_isi"] = {
        Id = "tahu_isi",
        Name = "Tahu Isi (Jeletot)",
        BasePrice = 3000,
        TotalCookDuration = 14.0,
        UndercookedMaxPercent = 0.30,
        CrispyMaxPercent = 0.80,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["tofu"] = 1, ["veggies"] = 1 },
        Description = "Tahu pong gurih berisi sayuran pedas berlimpah.",
    },
    ["tempe_mendoan"] = {
        Id = "tempe_mendoan",
        Name = "Tempe Mendoan",
        BasePrice = 2500,
        TotalCookDuration = 8.0,
        UndercookedMaxPercent = 0.30,
        CrispyMaxPercent = 0.80,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["tempeh"] = 1, ["batter"] = 1 },
        Description = "Tempe goreng tepung lembut setengah matang khas Banyumas.",
    },
    ["cireng_crispy"] = {
        Id = "cireng_crispy",
        Name = "Cireng Crispy",
        BasePrice = 3000,
        TotalCookDuration = 11.0,
        UndercookedMaxPercent = 0.30,
        CrispyMaxPercent = 0.80,
        BurntMaxPercent = 1.00,
        RequiredIngredients = { ["acitapioca"] = 1 },
        Description = "Aci digoreng kenyal gurih dengan cocolan bumbu rujak pedas.",
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

    -- Evaluasi kualitas kematangan berdasarkan waktu elapsed
    EvaluateQuality = function(recipe: Recipe, elapsedSeconds: number): (GameplayTypes.QualityResult, number)
        local progress = math.clamp(elapsedSeconds / recipe.TotalCookDuration, 0, 1.2)
        local quality: GameplayTypes.QualityResult

        if progress <= recipe.UndercookedMaxPercent then
            quality = "Undercooked"
        elseif progress <= recipe.CrispyMaxPercent then
            quality = "Crispy"
        else
            quality = "Burnt"
        end

        return quality, progress
    end,
}

return table.freeze(RecipesConfig)
