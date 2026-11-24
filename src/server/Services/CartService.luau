--!strict
--[[
    CartService.luau
    Layanan server untuk membangun, memunculkan, dan mengelola gerobak gorengan milik pemain.
    Setiap gerobak dilengkapi:
    - Wajan penggorengan dengan efek minyak mendesis & asap dinamis
    - Kotak penyimpanan bahan baku dengan interaksi ProximityPrompt
    - Etalase kaca untuk menampilkan hasil gorengan
    - Papan status kepemilikan gerobak
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service

local log = Logger.new("CartService")

-- Parameter mobilitas gerobak dengan nilai default aman
local NORMAL_WALK_SPEED = GameConfig.NormalWalkSpeed or 16
local PUSH_CART_WALK_SPEED = GameConfig.PushCartWalkSpeed or 10
local PUSH_CART_BEARING_SPEED = GameConfig.PushCartBearingSpeed or 13.5
local INTERACTION_MAX_DISTANCE = GameConfig.InteractionMaxDistance or 16

type PushState = {
    isPushing: boolean,
    lastUpdateTime: number,
    lastPosition: Vector3,
    plotId: number,
    baseSpeed: number,
}

local CartService = {
    Name = "CartService",
    _playerCarts = {} :: { [number]: Model },          -- [UserId] = CartModel
    _playerPlotIds = {} :: { [number]: number },       -- [UserId] = PlotId
    _pushingPlayers = {} :: { [number]: PushState },   -- [UserId] = PushState
    _services = {} :: { [string]: any },
}

-- Palet warna gerobak tradisional kaki lima
local CART_PALETTE = {
    WoodChassis = Color3.fromRGB(135, 95, 60),
    WoodTrim = Color3.fromRGB(90, 60, 35),
    CanopyStripeGreen = Color3.fromRGB(35, 130, 60),
    CanopyStripeYellow = Color3.fromRGB(240, 195, 40),
    Glass = Color3.fromRGB(200, 230, 245),
    MetalWajan = Color3.fromRGB(35, 35, 38),
    OilCooking = Color3.fromRGB(215, 160, 35),
    RawBatter = Color3.fromRGB(245, 235, 210),
    CrispyGold = Color3.fromRGB(230, 165, 35),
    BurntChar = Color3.fromRGB(40, 35, 35),
}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, canCollide: boolean?): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = if canCollide ~= nil then canCollide else true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

function CartService:Init()
    log:Info("Menginisialisasi CartService...")

    Players.PlayerRemoving:Connect(function(player: Player)
        self:StopPushCart(player)
        self:DespawnPlayerCart(player)
        self._playerPlotIds[player.UserId] = nil
    end)

    -- Daftarkan RemoteFunctions untuk mobilitas dorong gerobak
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestStartPushCart, function(player: Player)
        return self:StartPushCart(player)
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestStopPushCart, function(player: Player)
        return self:StopPushCart(player)
    end)

    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestUpdateCartPosition, function(player: Player, newCFrame: CFrame)
        return self:UpdateCartPosition(player, newCFrame)
    end)
end

function CartService:_getEconomyService()
    if not self._services.EconomyService then
        local Server = script.Parent
        local ecoMod = Server:FindFirstChild("EconomyService")
        if ecoMod then
            self._services.EconomyService = require(ecoMod)
        end
    end
    return self._services.EconomyService
end

function CartService:Start()
    self:_getEconomyService()
    log:Info("CartService aktif dan terhubung dengan EconomyService.")
end

function CartService:SpawnPlayerCart(player: Player, plotId: number): Model
    self:DespawnPlayerCart(player)

    local map = Workspace:FindFirstChild("Map")
    local plots = if map then map:FindFirstChild("PlayerPlots") else nil
    local plot = if plots then plots:FindFirstChild("Plot_" .. tostring(plotId)) else nil

    local spawnCFrame: CFrame
    if plot then
        local spawnPart = plot:FindFirstChild("CartSpawn")
        if spawnPart and spawnPart:IsA("BasePart") then
            spawnCFrame = spawnPart.CFrame
        else
            spawnCFrame = plot:GetPivot()
        end
    else
        spawnCFrame = CFrame.new(0, 3, 20)
    end

    local cartModel = Instance.new("Model")
    cartModel.Name = "Gerobak_" .. player.Name

    -- 1. Badan Gerobak (Kayu utama: 7 x 3.5 x 4.5 studs)
    local chassis = createPart(cartModel, "Chassis", Vector3.new(7, 3, 4.2), spawnCFrame * CFrame.new(0, 2, 0), CART_PALETTE.WoodChassis, Enum.Material.WoodPlanks, true)
    cartModel.PrimaryPart = chassis

    -- Roda gerobak (2 roda depan & penyangga belakang)
    createPart(cartModel, "WheelLeft", Vector3.new(0.6, 2.4, 2.4), spawnCFrame * CFrame.new(2.2, 1.2, 2.3), Color3.fromRGB(40, 40, 42), Enum.Material.Metal, false)
    createPart(cartModel, "WheelRight", Vector3.new(0.6, 2.4, 2.4), spawnCFrame * CFrame.new(2.2, 1.2, -2.3), Color3.fromRGB(40, 40, 42), Enum.Material.Metal, false)
    local handlePush = createPart(cartModel, "HandlePush", Vector3.new(2.0, 0.4, 4.0), spawnCFrame * CFrame.new(-3.8, 2.4, 0), CART_PALETTE.WoodTrim, Enum.Material.Wood, true)

    local pushPrompt = Instance.new("ProximityPrompt")
    pushPrompt.Name = "PushCartPrompt"
    pushPrompt.ActionText = "Dorong Gerobak"
    pushPrompt.ObjectText = "Gagang Gerobak"
    pushPrompt.HoldDuration = 0.2
    pushPrompt.MaxActivationDistance = 8
    pushPrompt.RequiresLineOfSight = false
    pushPrompt.Parent = handlePush

    pushPrompt.Triggered:Connect(function(promptPlayer: Player)
        if promptPlayer == player then
            if self:IsPushing(player) then
                self:StopPushCart(player)
            else
                self:StartPushCart(player)
            end
        end
    end)

    -- 2. Etalase Kaca Makanan (di sisi kiri gerobak)
    local glassCase = createPart(cartModel, "EtalaseKaca", Vector3.new(3.2, 2.5, 3.8), spawnCFrame * CFrame.new(-1.6, 4.5, 0), CART_PALETTE.Glass, Enum.Material.Glass, true)
    glassCase.Transparency = 0.55

    -- Rak kayu di dalam etalase
    createPart(cartModel, "GlassShelf", Vector3.new(3.0, 0.2, 3.6), spawnCFrame * CFrame.new(-1.6, 4.2, 0), CART_PALETTE.WoodTrim, Enum.Material.Wood, false)

    -- 3. Area Wajan & Kompor (di sisi kanan gerobak)
    local stove = createPart(cartModel, "Kompor", Vector3.new(3.2, 0.6, 3.8), spawnCFrame * CFrame.new(1.6, 3.6, 0), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, true)

    -- Wajan logam cekung
    local wajan = createPart(cartModel, "Wajan", Vector3.new(2.6, 0.5, 2.6), spawnCFrame * CFrame.new(1.6, 4.0, 0), CART_PALETTE.MetalWajan, Enum.Material.Metal, true)

    -- Minyak goreng mendidih
    local oil = createPart(cartModel, "MinyakGoreng", Vector3.new(2.3, 0.15, 2.3), spawnCFrame * CFrame.new(1.6, 4.1, 0), CART_PALETTE.OilCooking, Enum.Material.Neon, false)

    -- Part visual gorengan di wajan (berubah warna secara dinamis saat masak)
    local foodVisual = createPart(cartModel, "FoodVisual", Vector3.new(1.4, 0.35, 1.4), spawnCFrame * CFrame.new(1.6, 4.25, 0), CART_PALETTE.RawBatter, Enum.Material.Concrete, false)
    foodVisual.Transparency = 1 -- Sembunyikan saat wajan kosong

    -- Partikel minyak mendesis (Bubbles & Steam)
    local sizzleEmitter = Instance.new("ParticleEmitter")
    sizzleEmitter.Name = "SizzleParticles"
    sizzleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
    sizzleEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.3) })
    sizzleEmitter.Rate = 0
    sizzleEmitter.Speed = NumberRange.new(1, 2.5)
    sizzleEmitter.SpreadAngle = Vector2.new(25, 25)
    sizzleEmitter.Lifetime = NumberRange.new(0.4, 0.8)
    sizzleEmitter.Parent = foodVisual

    -- Partikel asap gosong (Smoke)
    local smokeEmitter = Instance.new("ParticleEmitter")
    smokeEmitter.Name = "SmokeParticles"
    smokeEmitter.Color = ColorSequence.new(Color3.fromRGB(40, 40, 40))
    smokeEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.2) })
    smokeEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.0) })
    smokeEmitter.Rate = 0
    smokeEmitter.Speed = NumberRange.new(2, 4)
    smokeEmitter.Lifetime = NumberRange.new(1.0, 2.0)
    smokeEmitter.Parent = foodVisual

    -- 4. Kotak Penyimpanan Bahan Baku (Kotak kayu di samping gerobak)
    local crate = createPart(cartModel, "KotakBahan", Vector3.new(1.8, 1.8, 2.4), spawnCFrame * CFrame.new(-1.8, 1.5, 2.8), Color3.fromRGB(150, 110, 70), Enum.Material.Wood, true)
    local takePrompt = Instance.new("ProximityPrompt")
    takePrompt.Name = "TakeIngredientsPrompt"
    takePrompt.ActionText = "Ambil Bahan & Adonan"
    takePrompt.ObjectText = "Kotak Persediaan"
    takePrompt.HoldDuration = 0.4
    takePrompt.MaxActivationDistance = 8
    takePrompt.RequiresLineOfSight = false
    takePrompt.Parent = crate

    -- Interaksi ProximityPrompt pada Wajan
    local cookPrompt = Instance.new("ProximityPrompt")
    cookPrompt.Name = "CookPrompt"
    cookPrompt.ActionText = "Goreng Bakwan Sayur"
    cookPrompt.ObjectText = "Wajan Penggorengan"
    cookPrompt.HoldDuration = 0.3
    cookPrompt.MaxActivationDistance = 8
    cookPrompt.RequiresLineOfSight = false
    cookPrompt.Parent = wajan

    -- 5. Atap Terpal Kanopi Gerobak
    local roofPole1 = createPart(cartModel, "RoofPole1", Vector3.new(0.3, 3.5, 0.3), spawnCFrame * CFrame.new(-3.2, 5.0, 1.9), CART_PALETTE.MetalWajan, Enum.Material.Metal, false)
    local roofPole2 = createPart(cartModel, "RoofPole2", Vector3.new(0.3, 3.5, 0.3), spawnCFrame * CFrame.new(3.2, 5.0, 1.9), CART_PALETTE.MetalWajan, Enum.Material.Metal, false)
    local roofPole3 = createPart(cartModel, "RoofPole3", Vector3.new(0.3, 3.5, 0.3), spawnCFrame * CFrame.new(-3.2, 5.0, -1.9), CART_PALETTE.MetalWajan, Enum.Material.Metal, false)
    local roofPole4 = createPart(cartModel, "RoofPole4", Vector3.new(0.3, 3.5, 0.3), spawnCFrame * CFrame.new(3.2, 5.0, -1.9), CART_PALETTE.MetalWajan, Enum.Material.Metal, false)
    local canopy = createPart(cartModel, "Canopy", Vector3.new(7.6, 0.4, 5.2), spawnCFrame * CFrame.new(0, 6.8, 0), CART_PALETTE.CanopyStripeGreen, Enum.Material.Fabric, false)

    -- 6. Papan Spanduk Gerobak
    local banner = createPart(cartModel, "CartBanner", Vector3.new(6.8, 1.2, 0.2), spawnCFrame * CFrame.new(0, 6.2, 2.5), CART_PALETTE.CanopyStripeYellow, Enum.Material.SmoothPlastic, false)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "BannerGui"
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.CanvasSize = Vector2.new(400, 100)
    surfaceGui.Adornee = banner
    surfaceGui.Parent = banner

    local bannerText = Instance.new("TextLabel")
    bannerText.Size = UDim2.fromScale(1, 1)
    bannerText.BackgroundTransparency = 1
    bannerText.TextColor3 = Color3.fromRGB(160, 30, 20)
    bannerText.TextScaled = true
    bannerText.Font = Enum.Font.FredokaOne
    bannerText.Text = "GORENGAN " .. player.Name:upper()
    bannerText.Parent = surfaceGui

    cartModel.Parent = Workspace
    self._playerCarts[player.UserId] = cartModel
    self._playerPlotIds[player.UserId] = plotId

    log:Info("Gerobak '%s' berhasil dimunculkan di plot #%d untuk pemain %s", cartModel.Name, plotId, player.Name)
    return cartModel
end

function CartService:GetPlayerCart(player: Player): Model?
    local cart = self._playerCarts[player.UserId]
    if not cart or not cart.Parent then
        local found = Workspace:FindFirstChild("Gerobak_" .. player.Name)
        if found and found:IsA("Model") then
            self._playerCarts[player.UserId] = found
            cart = found
        end
    end
    return cart
end

function CartService:DespawnPlayerCart(player: Player)
    local cart = self._playerCarts[player.UserId]
    if cart then
        cart:Destroy()
        self._playerCarts[player.UserId] = nil
        log:Info("Gerobak pemain %s telah didespawn.", player.Name)
    end
end

function CartService:UpdateCartFoodVisual(player: Player, state: string, progressPercent: number, quality: string?)
    local cart = self._playerCarts[player.UserId]
    if not cart then return end

    local foodVisual = cart:FindFirstChild("FoodVisual")
    if not foodVisual or not foodVisual:IsA("BasePart") then return end

    local sizzle = foodVisual:FindFirstChild("SizzleParticles") :: ParticleEmitter?
    local smoke = foodVisual:FindFirstChild("SmokeParticles") :: ParticleEmitter?

    if state == "Empty" then
        foodVisual.Transparency = 1
        if sizzle then sizzle.Rate = 0 end
        if smoke then smoke.Rate = 0 end
    elseif state == "Cooking" then
        foodVisual.Transparency = 0
        if sizzle then sizzle.Rate = 18 end

        if progressPercent <= 0.30 then
            -- 0–30%: Undercooked / Mentah (Warna pucat)
            foodVisual.Color = CART_PALETTE.RawBatter
            if smoke then smoke.Rate = 0 end
        elseif progressPercent <= 0.80 then
            -- 31–80%: Crispy (Kuning emas menggoda)
            foodVisual.Color = CART_PALETTE.CrispyGold
            if smoke then smoke.Rate = 0 end
        else
            -- 81–100%+: Gosong / Burnt (Hitam gosong & asap tebal)
            foodVisual.Color = CART_PALETTE.BurntChar
            if smoke then smoke.Rate = 22 end
        end
    end
end

function CartService:IsPushing(player: Player): boolean
    local state = self._pushingPlayers[player.UserId]
    return state ~= nil and state.isPushing == true
end

function CartService:StartPushCart(player: Player): { Success: boolean, Error: string?, IsPushing: boolean?, Speed: number? }
    local cart = self._playerCarts[player.UserId]
    if not cart then
        return { Success = false, Error = "Kamu belum memiliki gerobak!" }
    end

    local char = player.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if not char or not hrp or not humanoid then
        return { Success = false, Error = "Karakter pemain tidak valid!" }
    end

    -- Validasi jarak ke gerobak
    local cartPos = cart:GetPivot().Position
    local dist = (hrp.Position - cartPos).Magnitude
    if dist > INTERACTION_MAX_DISTANCE then
        return { Success = false, Error = "Terlalu jauh dari gerobak untuk mendorong!" }
    end

    -- Cek upgrade kecepatan roda bearing
    local hasBearing = false
    local ecoService = self:_getEconomyService()
    if ecoService and ecoService.HasUpgrade then
        hasBearing = ecoService:HasUpgrade(player, "roda_bearing")
    end

    local pushSpeed = if hasBearing then PUSH_CART_BEARING_SPEED else PUSH_CART_WALK_SPEED
    humanoid.WalkSpeed = pushSpeed

    self._pushingPlayers[player.UserId] = {
        isPushing = true,
        lastUpdateTime = os.clock(),
        lastPosition = cartPos,
        plotId = self._playerPlotIds[player.UserId] or 1,
        baseSpeed = pushSpeed,
    }

    log:Info("Pemain %s mulai mendorong gerobak (Speed: %.1f studs/s, Bearing Upgrade: %s)", player.Name, pushSpeed, tostring(hasBearing))
    NetworkBridge.FireClient(player, Remotes.Events.CartPushStateChanged, true, pushSpeed)

    return { Success = true, IsPushing = true, Speed = pushSpeed }
end

function CartService:StopPushCart(player: Player): { Success: boolean, IsPushing: boolean, Speed: number }
    self._pushingPlayers[player.UserId] = nil

    local char = player.Character
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if humanoid then
        humanoid.WalkSpeed = NORMAL_WALK_SPEED
    end

    log:Info("Pemain %s berhenti mendorong gerobak (Speed kembali normal: %d studs/s)", player.Name, NORMAL_WALK_SPEED)
    NetworkBridge.FireClient(player, Remotes.Events.CartPushStateChanged, false, NORMAL_WALK_SPEED)

    return { Success = true, IsPushing = false, Speed = NORMAL_WALK_SPEED }
end

function CartService:UpdateCartPosition(player: Player, newCFrame: CFrame): { Success: boolean, Error: string? }
    local pushData = self._pushingPlayers[player.UserId]
    if not pushData or not pushData.isPushing then
        return { Success = false, Error = "Pemain tidak sedang mendorong gerobak!" }
    end

    local cart = self._playerCarts[player.UserId]
    if not cart then
        return { Success = false, Error = "Gerobak tidak ditemukan!" }
    end

    local now = os.clock()
    local dt = math.max(now - pushData.lastUpdateTime, 0.05)
    local targetPos = newCFrame.Position
    local deltaDist = (targetPos - pushData.lastPosition).Magnitude

    -- Validasi anti-speedhack (maksimal wajar baseSpeed * 1.6 dengan toleransi network latency)
    local maxAllowedDist = (pushData.baseSpeed * 1.6 * dt) + 2.5
    if deltaDist > maxAllowedDist and deltaDist > 4.0 then
        log:Warn("Potensi speedhack terdeteksi dari %s: deltaDist=%.2f > max=%.2f (dt=%.2fs)", player.Name, deltaDist, maxAllowedDist, dt)
        return { Success = false, Error = "Pergerakan gerobak terlalu cepat (Speedhack detected)!" }
    end

    -- Validasi jarak karakter terhadap gerobak
    local char = player.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if hrp then
        local distToPlayer = (hrp.Position - targetPos).Magnitude
        if distToPlayer > 18 then
            return { Success = false, Error = "Posisi gerobak terpisah terlalu jauh dari pemain!" }
        end
    end

    -- Validasi batas ketinggian (mencegah teleport ke void / langit)
    if targetPos.Y < -5 or targetPos.Y > 40 then
        return { Success = false, Error = "Ketinggian gerobak tidak wajar!" }
    end

    -- Otoritatif update posisi gerobak
    cart:PivotTo(newCFrame)
    pushData.lastPosition = targetPos
    pushData.lastUpdateTime = now

    return { Success = true }
end

function CartService:ReturnCartToPlot(player: Player)
    self:StopPushCart(player)

    local cart = self._playerCarts[player.UserId]
    local plotId = self._playerPlotIds[player.UserId] or 1
    local map = Workspace:FindFirstChild("Map")
    local plots = if map then map:FindFirstChild("PlayerPlots") else nil
    local plot = if plots then plots:FindFirstChild("Plot_" .. tostring(plotId)) else nil

    local spawnCFrame = CFrame.new(0, 3, 20)
    if plot then
        local spawnPart = plot:FindFirstChild("CartSpawn")
        if spawnPart and spawnPart:IsA("BasePart") then
            spawnCFrame = spawnPart.CFrame
        else
            spawnCFrame = plot:GetPivot()
        end
    end

    if cart then
        cart:PivotTo(spawnCFrame)
    end

    local char = player.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if hrp then
        hrp.CFrame = spawnCFrame * CFrame.new(0, 3, 5)
    end

    log:Info("Gerobak dan pemain %s telah dipulangkan ke Plot #%d", player.Name, plotId)
end

function CartService:GetCartPosition(player: Player): Vector3?
    local cart = self._playerCarts[player.UserId]
    return if cart then cart:GetPivot().Position else nil
end

function CartService:GetAllActiveCarts(): { [number]: { Player: Player, Cart: Model, Position: Vector3 } }
    local activeCarts = {}
    for userId, cart in self._playerCarts do
        local player = Players:GetPlayerByUserId(userId)
        if player and cart and cart.PrimaryPart then
            activeCarts[userId] = {
                Player = player,
                Cart = cart,
                Position = cart:GetPivot().Position,
            }
        end
    end
    return activeCarts
end

return CartService
