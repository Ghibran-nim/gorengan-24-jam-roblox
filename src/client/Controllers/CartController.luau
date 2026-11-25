--!strict
--[[
    CartController.luau
    Mengelola interaksi client dengan gerobak milik pemain.
    Menghubungkan ProximityPrompt wajan dan kotak bahan baku ke permintaan server.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("CartController")

local ACTION_PUSH_CART = "PushCartAction"

local CartController = {
    Name = "CartController",
    _isPushing = false,
    _pushSpeed = 10,
    _lastSyncTime = 0,
    _pushConn = nil :: RBXScriptConnection?,
    _myCart = nil :: Model?,
}

function CartController:Init()
    log:Info("Menginisialisasi CartController...")

    local localPlayer = Players.LocalPlayer

    -- Dengarkan event perubahan status dorong gerobak dari server
    NetworkBridge.OnClientEvent(Remotes.Events.CartPushStateChanged, function(isPushing: boolean, speed: number)
        self._isPushing = isPushing
        self._pushSpeed = speed
        if isPushing then
            self:_startPushLoop()
        else
            self:_stopPushLoop()
        end
    end)

    -- Sembunyikan prompt kepemilikan pada gerobak orang lain & prompt sosial pada gerobak sendiri
    ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
        local ownerAttr = prompt:GetAttribute("OwnerUserId")
        local cart = prompt.Parent and prompt.Parent.Parent
        local cartOwnerAttr = if cart then cart:GetAttribute("OwnerUserId") else nil
        local effectiveOwner = ownerAttr or cartOwnerAttr

        if prompt.Name == "SocialVisitPrompt" then
            if effectiveOwner == localPlayer.UserId or (cart and cart.Name == "Gerobak_" .. localPlayer.Name) then
                prompt.Enabled = false
            end
        elseif prompt.Name == "CookPrompt" or prompt.Name == "TakeIngredientsPrompt" or prompt.Name == "PushCartPrompt" or prompt.Name == "TakeBurntPrompt" then
            if cart and ((cartOwnerAttr ~= nil and cartOwnerAttr ~= localPlayer.UserId) or (cartOwnerAttr == nil and cart.Name ~= "Gerobak_" .. localPlayer.Name)) then
                prompt.Enabled = false
            end
        end
    end)

    -- Dengarkan interaksi ProximityPrompt di seluruh gerobak
    ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
        if playerWhoTriggered ~= localPlayer then return end

        local cart = prompt.Parent and prompt.Parent.Parent
        local cartOwnerId = if cart then cart:GetAttribute("OwnerUserId") else nil
        local isOwnCart = if cartOwnerId ~= nil
            then (cartOwnerId == localPlayer.UserId)
            else (cart ~= nil and cart.Name == "Gerobak_" .. localPlayer.Name)

        if prompt.Name == "CookPrompt" then
            if isOwnCart then
                self:TriggerStartCooking()
            end
        elseif prompt.Name == "TakeIngredientsPrompt" then
            if isOwnCart then
                self:TriggerTakeIngredients()
            end
        elseif prompt.Name == "PushCartPrompt" then
            if isOwnCart then
                self:TogglePushCart()
            end
        elseif prompt.Name == "TakeBurntPrompt" then
            if isOwnCart then
                local ThrowableController = require(script.Parent:WaitForChild("ThrowableController"))
                if ThrowableController and (ThrowableController :: any).ToggleEquipBurntFood then
                    (ThrowableController :: any):ToggleEquipBurntFood()
                end
            end
        elseif prompt.Name == "SocialVisitPrompt" then
            local targetOwnerId = prompt:GetAttribute("OwnerUserId") or cartOwnerId
            if typeof(targetOwnerId) == "number" and targetOwnerId ~= localPlayer.UserId then
                local SocialController = require(script.Parent:WaitForChild("SocialController"))
                if SocialController and (SocialController :: any).OpenCartVisitModal then
                    (SocialController :: any):OpenCartVisitModal(targetOwnerId)
                end
            else
                local HUDController = require(script.Parent:WaitForChild("HUDController"))
                if HUDController and (HUDController :: any).ShowToastNotification then
                    (HUDController :: any):ShowToastNotification("🛒 Ini lapakmu sendiri! Kunjungi gerobak pemain lain.", "Warning")
                end
            end
        end
    end)

    -- Daftarkan tombol input [F] dan Touch Button di Mobile via ContextActionService
    ContextActionService:BindAction(ACTION_PUSH_CART, function(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            self:TogglePushCart()
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.F)

    ContextActionService:SetTitle(ACTION_PUSH_CART, "🛒 Dorong Gerobak")
    ContextActionService:SetPosition(ACTION_PUSH_CART, UDim2.new(1, -110, 1, -220))
end

function CartController:Start()
    log:Info("CartController aktif dengan dukungan kontrol PC [F] & Mobile Touch.")
end

function CartController:TogglePushCart()
    if self._isPushing then
        log:Info("Mengirim permintaan berhenti mendorong gerobak...")
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestStopPushCart)
        if res and res.Success then
            self._isPushing = false
            self:_stopPushLoop()
        end
    else
        log:Info("Mengirim permintaan mulai mendorong gerobak...")
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestStartPushCart)
        if res and res.Success then
            self._isPushing = true
            self._pushSpeed = res.Speed or 10
            self:_startPushLoop()
        else
            local HUDController = require(script.Parent:WaitForChild("HUDController"))
            if HUDController and (HUDController :: any).ShowToastNotification then
                (HUDController :: any):ShowToastNotification("⚠️ " .. (res and res.Error or "Gagal mendorong gerobak!"), "Warning")
            end
        end
    end
end

function CartController:_findMyCart(): Model?
    if self._myCart and self._myCart.Parent then
        return self._myCart
    end
    local localPlayer = Players.LocalPlayer
    local cart = Workspace:FindFirstChild("Gerobak_" .. localPlayer.Name) :: Model?
    self._myCart = cart
    return cart
end

function CartController:_startPushLoop()
    if self._pushConn then
        self._pushConn:Disconnect()
        self._pushConn = nil
    end

    local localPlayer = Players.LocalPlayer
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification("🛒 Mendorong Gerobak! (Tekan F atau tombol untuk lepas)", "Info")
    end

    self._lastSyncTime = os.clock()

    self._pushConn = RunService.RenderStepped:Connect(function()
        if not self._isPushing then return end

        local char = localPlayer.Character
        local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        local cart = self:_findMyCart()

        if hrp and cart and cart.PrimaryPart then
            -- Letakkan gerobak di depan karakter menghadap arah yang sama
            local playerCFrame = hrp.CFrame
            local forwardPos = playerCFrame.Position + (playerCFrame.LookVector * 5.0)
            local groundCFrame = CFrame.new(forwardPos.X, 3.0, forwardPos.Z) * CFrame.Angles(0, math.atan2(-playerCFrame.LookVector.X, -playerCFrame.LookVector.Z) + math.pi, 0)

            -- Update visual lokal halus
            cart:PivotTo(groundCFrame)

            -- Sinkronisasi otoritatif ke server pada rate wajar (10 Hz = 0.1s)
            local now = os.clock()
            if (now - self._lastSyncTime) >= 0.10 then
                self._lastSyncTime = now
                task.spawn(function()
                    NetworkBridge.InvokeServer(Remotes.Functions.RequestUpdateCartPosition, groundCFrame)
                end)
            end
        end
    end)
end

function CartController:_stopPushLoop()
    if self._pushConn then
        self._pushConn:Disconnect()
        self._pushConn = nil
    end

    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification("🛑 Gerobak diparkir.", "Info")
    end
end

function CartController:TriggerStartCooking(recipeIdOverride: string?)
    local recipeId = recipeIdOverride
    if not recipeId then
        local progMod = script.Parent:FindFirstChild("ProgressionController")
        if progMod then
            local progCtrl = require(progMod)
            if progCtrl and (progCtrl :: any).GetSelectedRecipeId then
                recipeId = (progCtrl :: any):GetSelectedRecipeId()
            end
        end
    end
    recipeId = recipeId or "bakwan_sayur"
    log:Info("Meminta server memulai memasak resep '%s'...", recipeId)

    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestStartCooking, recipeId)
    if res and not res.Success then
        local HUDController = require(script.Parent:WaitForChild("HUDController"))
        if HUDController and (HUDController :: any).ShowToastNotification then
            (HUDController :: any):ShowToastNotification("⚠️ " .. (res.Error or "Gagal memasak!"), "Warning")
        end
    end
end

function CartController:TriggerTakeIngredients(ingredientType: string?)
    local item = ingredientType or "batter"
    log:Info("Meminta pengambilan persediaan bahan '%s' dari kotak gerobak...", item)

    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestTakeIngredients, item, 5)
    if res then
        local HUDController = require(script.Parent:WaitForChild("HUDController"))
        if res.Success then
            local audioMod = script.Parent:FindFirstChild("AudioVFXController")
            if audioMod then
                local audioCtrl = require(audioMod)
                if audioCtrl and (audioCtrl :: any).PlayGrabIngredientFeedback then
                    (audioCtrl :: any):PlayGrabIngredientFeedback()
                end
            end
            if HUDController and (HUDController :: any).ShowToastNotification then
                (HUDController :: any):ShowToastNotification("📦 Berhasil mengambil bahan adonan & sayur!", "Success")
            end
        else
            if HUDController and (HUDController :: any).ShowToastNotification then
                (HUDController :: any):ShowToastNotification("⚠️ " .. (res.Error or "Gagal mengambil bahan!"), "Warning")
            end
        end
    end
end

return CartController
