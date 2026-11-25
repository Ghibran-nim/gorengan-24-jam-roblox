--!strict
--[[
    CustomerService.luau
    Layanan server untuk mengelola siklus hidup pelanggan (Customer AI),
    antrean antarpembeli di depan gerobak, batas kesabaran, balon pesanan 3D,
    serta eksekusi transaksi penjualan yang otoritatif di server.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local CustomerConfig = require(Shared:WaitForChild("Config"):WaitForChild("CustomerConfig"))
local RecipesConfig = require(Shared:WaitForChild("Config"):WaitForChild("RecipesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service
type CustomerOrder = GameplayTypes.CustomerOrder
type CustomerArchetype = CustomerConfig.CustomerArchetype

local log = Logger.new("CustomerService")

local MAX_CUSTOMERS_PER_QUEUE = 3
local GLOBAL_NPC_CAP = 16

local CustomerService = {
    Name = "CustomerService",
    _activeOrders = {} :: { [string]: CustomerOrder }, -- [CustomerId] = Order
    _plotQueues = {} :: { [number]: { string } },      -- [PlotId] = { CustomerId1, CustomerId2, ... }
    _customerModels = {} :: { [string]: Model },       -- [CustomerId] = Model
    _kasirModels = {} :: { [number]: Model },          -- [UserId] = KasirModel
    _services = {} :: { [string]: any },
    _orderCounter = 0,
    _spawningActive = false,
}

function CustomerService:_getService(serviceName: string): any
    if not self._services[serviceName] and script and script.Parent then
        local mod = script.Parent:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

function CustomerService:Init()
    log:Info("Menginisialisasi CustomerService...")

    for plotId = 1, 8 do
        self._plotQueues[plotId] = {}
    end

    Players.PlayerRemoving:Connect(function(player: Player)
        local kasir = self._kasirModels[player.UserId]
        if kasir then
            kasir:Destroy()
            self._kasirModels[player.UserId] = nil
        end
    end)

    -- Daftarkan handler permintaan melayani pelanggan
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestServeCustomer, function(player: Player, customerId: string)
        return self:HandleServeCustomer(player, customerId)
    end)
end

function CustomerService:Start()
    self:_getService("InventoryService")
    self:_getService("EconomyService")
    self:_getService("GameService")
    self:_getService("MapService")
    self:_getService("TutorialService")
    self:_getService("ProgressionService")

    log:Info("CustomerService aktif. Memulai spawner pelanggan...")
    self._spawningActive = true
    task.spawn(function()
        self:_runCustomerSpawnerLoop()
    end)
end

-- ============================================================================
-- SPAWNING & RIG CREATION
-- ============================================================================

local function createCustomerRig(customerId: string, archetype: CustomerArchetype, spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "Customer_" .. customerId

    -- HumanoidRootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.CFrame = CFrame.new(spawnPos)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = model
    model.PrimaryPart = hrp

    -- Torso (Badan dengan warna baju)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = CFrame.new(spawnPos)
    torso.Color = archetype.Colors.Shirt
    torso.Material = Enum.Material.SmoothPlastic
    torso.CanCollide = false
    torso.Anchored = false
    torso.Parent = model

    local weldTorso = Instance.new("WeldConstraint")
    weldTorso.Part0 = hrp
    weldTorso.Part1 = torso
    weldTorso.Parent = hrp

    -- Head (Kepala dengan warna kulit)
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.5, 0))
    head.Color = archetype.Colors.Skin
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.Anchored = false
    head.Parent = model

    local weldHead = Instance.new("WeldConstraint")
    weldHead.Part0 = torso
    weldHead.Part1 = head
    weldHead.Parent = torso

    -- Mata ekspresif sederhana
    for _, eyeX in { -0.25, 0.25 } do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Size = Vector3.new(0.16, 0.2, 0.1)
        eye.CFrame = CFrame.new(spawnPos + Vector3.new(eyeX, 1.58, -0.6))
        eye.Color = Color3.fromRGB(20, 20, 24)
        eye.Material = Enum.Material.SmoothPlastic
        eye.CanCollide = false
        eye.Anchored = false
        eye.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = head
        w.Part1 = eye
        w.Parent = head
    end

    -- Aksesori khas arketipe jalanan Indonesia
    if archetype.Id == "ojol" then
        local helmet = Instance.new("Part")
        helmet.Name = "OjolHelmet"
        helmet.Size = Vector3.new(1.38, 0.72, 1.38)
        helmet.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.95, 0))
        helmet.Color = Color3.fromRGB(35, 165, 65)
        helmet.Material = Enum.Material.SmoothPlastic
        helmet.CanCollide = false
        helmet.Anchored = false
        helmet.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = head
        w.Part1 = helmet
        w.Parent = head
    elseif archetype.Id == "misterius" then
        local shades = Instance.new("Part")
        shades.Name = "SultanShades"
        shades.Size = Vector3.new(1.1, 0.28, 0.2)
        shades.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.58, -0.64))
        shades.Color = Color3.fromRGB(15, 15, 18)
        shades.Material = Enum.Material.Glass
        shades.CanCollide = false
        shades.Anchored = false
        shades.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = head
        w.Part1 = shades
        w.Parent = head
    elseif archetype.Id == "mahasiswa" then
        local bag = Instance.new("Part")
        bag.Name = "Backpack"
        bag.Size = Vector3.new(1.5, 1.4, 0.7)
        bag.CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.05, 0.75))
        bag.Color = Color3.fromRGB(45, 75, 125)
        bag.Material = Enum.Material.Fabric
        bag.CanCollide = false
        bag.Anchored = false
        bag.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = torso
        w.Part1 = bag
        w.Parent = torso
    elseif archetype.Id == "food_vlogger" then
        local cam = Instance.new("Part")
        cam.Name = "VloggerCamera"
        cam.Size = Vector3.new(0.45, 0.45, 0.65)
        cam.CFrame = CFrame.new(spawnPos + Vector3.new(1.45, 0.1, -0.75))
        cam.Color = Color3.fromRGB(30, 30, 36)
        cam.Material = Enum.Material.Metal
        cam.CanCollide = false
        cam.Anchored = false
        cam.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = torso
        w.Part1 = cam
        w.Parent = torso
    end

    -- Lengan & Kaki dengan Motor6D agar dapat dianimasikan mulus di Client
    local armSpecs = {
        { Name = "LeftArm", OffsetX = -1.45 },
        { Name = "RightArm", OffsetX = 1.45 },
    }
    for _, spec in ipairs(armSpecs) do
        local arm = Instance.new("Part")
        arm.Name = spec.Name
        arm.Size = Vector3.new(0.8, 1.8, 0.8)
        arm.CFrame = CFrame.new(spawnPos + Vector3.new(spec.OffsetX, 0, 0))
        arm.Color = archetype.Colors.Shirt
        arm.Material = Enum.Material.SmoothPlastic
        arm.CanCollide = false
        arm.Anchored = false
        arm.Parent = model

        local m6 = Instance.new("Motor6D")
        m6.Name = spec.Name .. "Joint"
        m6.Part0 = torso
        m6.Part1 = arm
        m6.C0 = CFrame.new(spec.OffsetX, 0.6, 0)
        m6.C1 = CFrame.new(0, 0.6, 0)
        m6.Parent = torso
    end

    -- Legs (Celana) dengan Motor6D
    local legSpecs = {
        { Name = "LeftLeg", OffsetX = -0.5 },
        { Name = "RightLeg", OffsetX = 0.5 },
    }
    for _, spec in ipairs(legSpecs) do
        local leg = Instance.new("Part")
        leg.Name = spec.Name
        leg.Size = Vector3.new(0.9, 2, 0.9)
        leg.CFrame = CFrame.new(spawnPos + Vector3.new(spec.OffsetX, -1.8, 0))
        leg.Color = archetype.Colors.Pants
        leg.Material = Enum.Material.SmoothPlastic
        leg.CanCollide = false
        leg.Anchored = false
        leg.Parent = model

        local m6 = Instance.new("Motor6D")
        m6.Name = spec.Name .. "Joint"
        m6.Part0 = torso
        m6.Part1 = leg
        m6.C0 = CFrame.new(spec.OffsetX, -1.0, 0)
        m6.C1 = CFrame.new(0, 0.9, 0)
        m6.Parent = torso
    end

    -- Humanoid untuk navigasi gerak
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.WalkSpeed = 12
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent = model

    -- Tampilan Balon Pesanan 3D di atas kepala (BillboardGui)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "OrderBubble"
    billboard.Size = UDim2.new(0, 200, 0, 90)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 45
    billboard.Adornee = head
    billboard.Parent = head

    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BubbleFrame"
    bgFrame.Size = UDim2.fromScale(1, 1)
    bgFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
    bgFrame.BackgroundTransparency = 0.15
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = bgFrame

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Color = Color3.fromRGB(70, 75, 85)
    stroke.Thickness = 2
    stroke.Parent = bgFrame

    -- Nama Pelanggan
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "CustomerName"
    nameLabel.Size = UDim2.new(1, -12, 0, 18)
    nameLabel.Position = UDim2.new(0, 6, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(240, 200, 80)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 13
    nameLabel.Text = archetype.Name .. " (" .. archetype.Title .. ")"
    nameLabel.Parent = bgFrame

    -- Teks Pesanan
    local orderLabel = Instance.new("TextLabel")
    orderLabel.Name = "OrderText"
    orderLabel.Size = UDim2.new(1, -12, 0, 24)
    orderLabel.Position = UDim2.new(0, 6, 0, 22)
    orderLabel.BackgroundTransparency = 1
    orderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    orderLabel.Font = Enum.Font.FredokaOne
    orderLabel.TextSize = 15
    orderLabel.Text = "Menuju antrean..."
    orderLabel.Parent = bgFrame

    -- Bar Meteran Kesabaran (Patience Bar)
    local barBg = Instance.new("Frame")
    barBg.Name = "PatienceBarBg"
    barBg.Size = UDim2.new(1, -16, 0, 8)
    barBg.Position = UDim2.new(0, 8, 0, 50)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
    barBg.BorderSizePixel = 0
    barBg.Parent = bgFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.Size = UDim2.fromScale(1, 1)
    barFill.BackgroundColor3 = Color3.fromRGB(50, 220, 90)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = barFill

    -- Label Dialog Balon Kata
    local dialogueLabel = Instance.new("TextLabel")
    dialogueLabel.Name = "DialogueText"
    dialogueLabel.Size = UDim2.new(1, -12, 0, 20)
    dialogueLabel.Position = UDim2.new(0, 6, 0, 62)
    dialogueLabel.BackgroundTransparency = 1
    dialogueLabel.TextColor3 = Color3.fromRGB(220, 225, 230)
    dialogueLabel.Font = Enum.Font.SourceSansItalic
    dialogueLabel.TextSize = 12
    dialogueLabel.Text = "..."
    dialogueLabel.Parent = bgFrame

    model.Parent = Workspace
    return model
end

-- ============================================================================
-- AI CONTROLLER & QUEUE MANAGEMENT
-- ============================================================================

function CustomerService:_getPlotOwner(plotId: number): Player?
    local gameService = self:_getService("GameService")
    if not gameService then return nil end
    for _, p in Players:GetPlayers() do
        if gameService:GetPlayerPlot(p) == plotId then
            return p
        end
    end
    return nil
end

function CustomerService:_runCustomerSpawnerLoop()
    while self._spawningActive do
        local hasAnyNeon = false
        local ecoService = self:_getService("EconomyService")
        if ecoService and ecoService.HasUpgrade then
            for _, p in Players:GetPlayers() do
                if ecoService:HasUpgrade(p, "spanduk_neon") then
                    hasAnyNeon = true
                    break
                end
            end
        end

        local waitSecs = if hasAnyNeon then math.random(4, 7) else math.random(6, 10)
        task.wait(waitSecs)

        -- Cek batas global NPC
        local totalActive = 0
        for _, queue in pairs(self._plotQueues) do
            totalActive += #queue
        end

        if totalActive < GLOBAL_NPC_CAP then
            -- Cari plot aktif yang memiliki pemain
            local gameService = self:_getService("GameService")
            for _, player in Players:GetPlayers() do
                local plotId = if gameService then gameService:GetPlayerPlot(player) else nil
                if plotId then
                    local queue = self._plotQueues[plotId]
                    if queue and #queue < MAX_CUSTOMERS_PER_QUEUE then
                        self:SpawnCustomerForPlot(plotId)
                        break
                    end
                end
            end
        end
    end
end

function CustomerService:SpawnSpecialCustomer(archetypeId: string, plotId: number): string?
    local queue = self._plotQueues[plotId]
    if not queue then return nil end

    -- Jika antrean penuh, ijinkan 1 slot khusus VIP/Event tambahan (maks 4)
    if #queue >= MAX_CUSTOMERS_PER_QUEUE + 1 then
        return nil
    end

    local archetype = CustomerConfig.GetArchetype(archetypeId)
    if not archetype then return nil end

    self._orderCounter += 1
    local customerId = "CUST_" .. tostring(self._orderCounter)

    local owner = self:_getPlotOwner(plotId)
    local progService = self:_getService("ProgressionService")
    local unlockedList = if owner and progService and progService.GetUnlockedRecipeIds then progService:GetUnlockedRecipeIds(owner) else { "bakwan_sayur" }

    local eligible = {}
    for _, rId in ipairs(archetype.AllowedRecipes) do
        if table.find(unlockedList, rId) then
            table.insert(eligible, rId)
        end
    end
    if #eligible == 0 then
        eligible = unlockedList
    end

    local recipeId = eligible[math.random(1, #eligible)] or "bakwan_sayur"
    local spawnX = if math.random() > 0.5 then 160 else -160
    local isNorth = (plotId <= 4)
    local spawnZ = if isNorth then 22 else -22
    local spawnPos = Vector3.new(spawnX, 3.5, spawnZ)

    local model = createCustomerRig(customerId, archetype, spawnPos)
    self._customerModels[customerId] = model

    local nextSlot = #queue + 1
    local order: CustomerOrder = {
        CustomerId = customerId,
        ArchetypeId = archetype.Id,
        PlotId = plotId,
        RecipeId = recipeId,
        Quantity = 1,
        CreatedAt = os.clock(),
        PatienceDuration = archetype.BasePatience,
        State = "Approaching",
        QueueSlot = nextSlot,
    }

    self._activeOrders[customerId] = order
    table.insert(queue, customerId)

    log:Info("NPC Spesial Event '%s' (%s) muncul untuk Plot #%d, memesan %s", customerId, archetype.Name, plotId, recipeId)
    task.spawn(function()
        self:_runCustomerAI(customerId)
    end)

    return customerId
end

function CustomerService:SpawnCustomerForPlot(plotId: number): string?
    local queue = self._plotQueues[plotId]
    if not queue or #queue >= MAX_CUSTOMERS_PER_QUEUE then
        return nil
    end

    self._orderCounter += 1
    local customerId = "CUST_" .. tostring(self._orderCounter)
    local archetype = CustomerConfig.GetRandomArchetype()

    -- Filter pesanan agar hanya memilih resep yang sudah dibuka oleh pemilik plot!
    local owner = self:_getPlotOwner(plotId)
    local progService = self:_getService("ProgressionService")
    local unlockedList = if owner and progService and progService.GetUnlockedRecipeIds then progService:GetUnlockedRecipeIds(owner) else { "bakwan_sayur" }

    local eligible = {}
    for _, rId in ipairs(archetype.AllowedRecipes) do
        if table.find(unlockedList, rId) then
            table.insert(eligible, rId)
        end
    end
    if #eligible == 0 then
        eligible = unlockedList
    end

    local recipeId = eligible[math.random(1, #eligible)] or "bakwan_sayur"

    -- Tentukan posisi spawn di ujung trotoar timur/barat
    local spawnX = if math.random() > 0.5 then 160 else -160
    local isNorth = (plotId <= 4)
    local spawnZ = if isNorth then 22 else -22
    local spawnPos = Vector3.new(spawnX, 3.5, spawnZ)

    local model = createCustomerRig(customerId, archetype, spawnPos)
    self._customerModels[customerId] = model

    local nextSlot = #queue + 1
    local order: CustomerOrder = {
        CustomerId = customerId,
        ArchetypeId = archetype.Id,
        PlotId = plotId,
        RecipeId = recipeId,
        Quantity = 1,
        CreatedAt = os.clock(),
        PatienceDuration = archetype.BasePatience,
        State = "Approaching",
        QueueSlot = nextSlot,
    }

    self._activeOrders[customerId] = order
    table.insert(queue, customerId)

    log:Info("NPC Pelanggan '%s' (%s) muncul untuk Plot #%d, memesan %s", customerId, archetype.Name, plotId, recipeId)

    -- Jalankan thread navigasi NPC
    task.spawn(function()
        self:_runCustomerAI(customerId)
    end)

    return customerId
end

function CustomerService:_getQueueSlotPosition(plotId: number, slotIndex: number): Vector3?
    local mapService = self._services.MapService
    local plotModel = if mapService then mapService:GetPlot(plotId) else nil
    if not plotModel then return nil end

    local queueFolder = plotModel:FindFirstChild("CustomerQueue")
    if queueFolder then
        local slotPart = queueFolder:FindFirstChild("QueueSlot_" .. tostring(slotIndex))
        if slotPart and slotPart:IsA("BasePart") then
            return slotPart.Position + Vector3.new(0, 1.5, 0)
        end
    end
    return plotModel:GetPivot().Position
end

function CustomerService:_runCustomerAI(customerId: string)
    local order = self._activeOrders[customerId]
    local model = self._customerModels[customerId]
    if not order or not model then return end

    local humanoid = model:FindFirstChild("Humanoid") :: Humanoid?
    local hrp = model.PrimaryPart
    if not humanoid or not hrp then return end

    local archetype = CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()
    local recipe = RecipesConfig.GetRecipe(order.RecipeId)

    -- 1. Navigasi menuju slot antrean
    local targetPos = self:_getQueueSlotPosition(order.PlotId, order.QueueSlot)
    if targetPos then
        humanoid:MoveTo(targetPos)
        local RunService = game:GetService("RunService")
        if RunService:IsRunning() then
            local arrived = false
            local conn: RBXScriptConnection?
            conn = humanoid.MoveToFinished:Connect(function()
                arrived = true
                if conn then conn:Disconnect() end
            end)
            local startWait = os.clock()
            while not arrived and (os.clock() - startWait) < 5 do
                task.wait(0.2)
            end
            if conn then conn:Disconnect() end
        end
    end

    -- Masuk ke status antrean
    order.State = if order.QueueSlot == 1 then "WaitingForFood" else "InQueue"

    -- Jika berada di urutan terdepan (Slot 1), tampilkan pesanan & ProximityPrompt
    if order.QueueSlot == 1 then
        task.spawn(function()
            self:_setupActiveCustomerOrder(customerId, order, model, archetype, recipe)
        end)
    else
        -- Tunggu giliran maju
        self:_updateBubbleText(model, "Antre #" .. tostring(order.QueueSlot), archetype.Dialogues.Ordering[1])
    end
end

function CustomerService:_setupActiveCustomerOrder(customerId: string, order: CustomerOrder, model: Model, archetype: CustomerArchetype?, recipe: any)
    order.State = "WaitingForFood"
    local recipeName = if recipe then recipe.Name else order.RecipeId

    local arch = archetype or CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()
    local randomDialogue = "Beli gorengan dong!"
    if arch and arch.Dialogues and arch.Dialogues.Ordering and #arch.Dialogues.Ordering > 0 then
        randomDialogue = arch.Dialogues.Ordering[math.random(1, #arch.Dialogues.Ordering)]
    end
    self:_updateBubbleText(model, "Pesan: 1x " .. recipeName, randomDialogue)

    -- Tambahkan ProximityPrompt pada pelanggan untuk interaksi penyajian
    local hrp = model.PrimaryPart
    if hrp then
        local prompt = hrp:FindFirstChild("ServePrompt") :: ProximityPrompt?
        if not prompt then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "ServePrompt"
            prompt.ActionText = "Sajikan Pesanan"
            prompt.ObjectText = recipeName .. " (" .. archetype.Name .. ")"
            prompt.HoldDuration = 0.3
            prompt.MaxActivationDistance = 9
            prompt.RequiresLineOfSight = false
            prompt.Parent = hrp

            prompt.Triggered:Connect(function(player)
                self:HandleServeCustomer(player, customerId)
            end)
        end
    end

    -- Jalankan timer kesabaran (Patience Loop)
    local startTime = os.clock()
    local patienceDuration = order.PatienceDuration

    while order.State == "WaitingForFood" and (os.clock() - startTime) < patienceDuration do
        task.wait(0.25)
        local elapsed = os.clock() - startTime
        local progress = 1.0 - (elapsed / patienceDuration)

        -- Update visual bar kesabaran di atas kepala
        self:_updatePatienceBar(model, progress)

        -- Dialogue ketika kesabaran menipis (< 25%)
        if progress < 0.25 and #archetype.Dialogues.Impatient > 0 then
            local impDialogue = archetype.Dialogues.Impatient[1]
            local dLabel = model:FindFirstChild("OrderBubble", true)
            if dLabel then
                local txt = dLabel:FindFirstChild("DialogueText", true) :: TextLabel?
                if txt then txt.Text = impDialogue end
            end
        end
    end

    -- Jika timer habis dan belum terlayani -> Kehilangan kesabaran (Cancel Order)
    if order.State == "WaitingForFood" then
        self:_handleCustomerLostPatience(customerId, order, model, archetype)
    end
end

function CustomerService:_updateBubbleText(model: Model, orderText: string, dialogueText: string)
    local head = model:FindFirstChild("Head")
    local bubble = if head then head:FindFirstChild("OrderBubble") else nil
    if bubble then
        local orderLbl = bubble:FindFirstChild("OrderText", true) :: TextLabel?
        local diagLbl = bubble:FindFirstChild("DialogueText", true) :: TextLabel?
        if orderLbl then orderLbl.Text = orderText end
        if diagLbl then diagLbl.Text = dialogueText end
    end
end

function CustomerService:_updatePatienceBar(model: Model, progress: number)
    local head = model:FindFirstChild("Head")
    local bubble = if head then head:FindFirstChild("OrderBubble") else nil
    if bubble then
        local fill = bubble:FindFirstChild("Fill", true) :: Frame?
        if fill then
            fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
            if progress > 0.5 then
                fill.BackgroundColor3 = Color3.fromRGB(50, 220, 90)
            elseif progress > 0.25 then
                fill.BackgroundColor3 = Color3.fromRGB(240, 195, 40)
            else
                fill.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
            end
        end
    end
end

-- ============================================================================
-- SERVING TRANSACTION (SELLING SYSTEM)
-- ============================================================================

function CustomerService:HandleServeCustomer(player: Player, customerId: string): { Success: boolean, Error: string?, Payout: number?, Quality: string? }
    return self:_executeServe(player, customerId, false)
end

function CustomerService:_executeServe(player: Player, customerId: string, isAutoKasir: boolean): { Success: boolean, Error: string?, Payout: number?, Quality: string? }
    local order = self._activeOrders[customerId]
    local model = self._customerModels[customerId]

    if not order or not model then
        return { Success = false, Error = "Pelanggan sudah tidak berada di antrean!" }
    end

    if order.State ~= "WaitingForFood" or order.QueueSlot ~= 1 then
        return { Success = false, Error = "Pelanggan belum berada di urutan terdepan antrean!" }
    end

    -- 1. Validasi kepemilikan plot (Pemain hanya melayani pembeli di gerobaknya sendiri)
    local gameService = self:_getService("GameService")
    local playerPlot = if gameService then gameService:GetPlayerPlot(player) else nil
    if not playerPlot or playerPlot ~= order.PlotId then
        return { Success = false, Error = "Kamu tidak bisa melayani pelanggan di gerobak pemain lain!" }
    end

    local custHrp = model.PrimaryPart
    if not isAutoKasir then
        -- 2. Validasi jarak fisik pemain ke pelanggan (hanya untuk serve manual)
        local char = player.Character
        local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
        if not hrp or not custHrp or (hrp.Position - custHrp.Position).Magnitude > 16 then
            return { Success = false, Error = "Jarak terlalu jauh dari pelanggan!" }
        end
    end

    -- 3. Periksa stok etalase gorengan di inventaris pemain
    local inventoryService = self:_getService("InventoryService")
    if not inventoryService then
        return { Success = false, Error = "Layanan inventaris tidak tersedia!" }
    end

    local inv = inventoryService:GetInventory(player)
    if not inv or not inv.CookedFood[order.RecipeId] then
        return { Success = false, Error = "Kamu belum menggoreng menu yang dipesan pelanggan!" }
    end

    local cookedStock = inv.CookedFood[order.RecipeId]
    local servedQuality: GameplayTypes.QualityResult

    -- Prioritaskan kualitas Crispy terlebih dahulu
    if (cookedStock.Crispy or 0) > 0 then
        servedQuality = "Crispy"
    elseif (cookedStock.Undercooked or 0) > 0 then
        servedQuality = "Undercooked"
    else
        return { Success = false, Error = "Stok gorengan matang kosong di etalase! (Gorengan gosong tidak dapat dijual ke pembeli)." }
    end

    -- 4. Potong 1x gorengan dari etalase
    local removed = inventoryService:RemoveCookedFood(player, order.RecipeId, servedQuality, 1)
    if not removed then
        return { Success = false, Error = "Gagal memproses penyerahan gorengan!" }
    end

    -- 5. Hitung harga & bonus upgrade bisnis/dekorasi
    local recipe = RecipesConfig.GetRecipe(order.RecipeId)
    local basePrice = if recipe then recipe.BasePrice else 2200
    local archetype = CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()

    local economyService = self:_getService("EconomyService")
    local hasPromo = economyService and economyService.HasUpgrade and economyService:HasUpgrade(player, "papan_promo")
    local hasLampuHias = economyService and economyService.HasUpgrade and economyService:HasUpgrade(player, "lampu_tenda_hias")

    if hasPromo then
        basePrice = math.floor(basePrice * 1.15)
    end

    -- Bonus event Hujan Deras (+25% harga jual gorengan hangat)
    local eventService = self:_getService("EventService")
    if eventService and eventService.IsRaining and eventService:IsRaining() then
        basePrice = math.floor(basePrice * 1.25)
    end

    local finalPayout = basePrice
    local reactionDialogue: string

    if servedQuality == "Crispy" then
        local nightBonus = if eventService and eventService.IsNightMarketActive and eventService:IsNightMarketActive() then 0.30 else 0
        local tipMult = archetype.TipMultiplier + (if hasLampuHias then 0.15 else 0) + nightBonus
        local tipBonus = math.floor(basePrice * tipMult * 0.20)
        finalPayout = basePrice + tipBonus
        reactionDialogue = archetype.Dialogues.CrispyHappy[math.random(1, #archetype.Dialogues.CrispyHappy)]
    else
        finalPayout = math.floor(basePrice * 0.5)
        reactionDialogue = archetype.Dialogues.UndercookedSad[math.random(1, #archetype.Dialogues.UndercookedSad)]
    end

    -- Terapkan multiplier cabai langka yang sedang dipasang di gerobak
    local chiliService = self:_getService("ChiliService")
    local chiliMult = if chiliService and chiliService.GetEquippedProfitMultiplier then chiliService:GetEquippedProfitMultiplier(player) else 1.0
    if chiliMult > 1.0 then
        finalPayout = math.floor(finalPayout * chiliMult)
    end

    -- Bonus event kompetisi omzet server-wide (+20%)
    local socialService = self:_getService("SocialService")
    if socialService and socialService.IsCompetitionActive and socialService:IsCompetitionActive() then
        finalPayout = math.floor(finalPayout * 1.20)
    end

    if economyService then
        economyService:AddCarriedCash(player, finalPayout, (if isAutoKasir then "[Kasir] " else "") .. "Penjualan " .. (recipe and recipe.Name or order.RecipeId))
    end

    -- 6. Catat penjualan & berikan XP ke ProgressionService (plus bonus XP cabai langka)
    local progService = self:_getService("ProgressionService")
    if progService then
        local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
        local xpGain = ProgressionConfig.XPRewards.ServeCustomerBase + (if servedQuality == "Crispy" then ProgressionConfig.XPRewards.ServeCrispyBonus else 0)
        local chiliXpBonus = if chiliService and chiliService.GetEquippedXPBonusPercent then chiliService:GetEquippedXPBonusPercent(player) else 0
        if chiliXpBonus > 0 then
            xpGain = math.floor(xpGain * (1.0 + chiliXpBonus))
        end
        progService:AddXP(player, xpGain, "Layani " .. archetype.Name)
        progService:RecordSale(player, finalPayout)
    end

    order.State = "Served"
    log:Info("Pemain %s sukses menyajikan %s (%s) ke %s (AutoKasir=%s) -> Bayaran: Rp %d", player.Name, order.RecipeId, servedQuality, customerId, tostring(isAutoKasir), finalPayout)

    self:_updateBubbleText(model, string.format("+Rp %d (%s)!", finalPayout, servedQuality:upper()), reactionDialogue)

    if custHrp then
        local prompt = custHrp:FindFirstChild("ServePrompt")
        if prompt then prompt:Destroy() end
    end

    NetworkBridge.FireClient(player, Remotes.Events.CustomerOrderCompleted, customerId, finalPayout, servedQuality)

    local ts = self:_getService("TutorialService")
    if ts and ts.OnCustomerServed then
        ts:OnCustomerServed(player)
    end

    task.spawn(function()
        task.wait(1.5)
        self:_despawnCustomer(customerId, order.PlotId)
    end)

    return { Success = true, Payout = finalPayout, Quality = servedQuality }
end

function CustomerService:SpawnKasirForPlayer(player: Player): Model?
    local userId = player.UserId
    if self._kasirModels[userId] and self._kasirModels[userId].Parent then
        return self._kasirModels[userId]
    end

    local gameService = self:_getService("GameService")
    local cartService = self:_getService("CartService")
    local plotId = (if gameService then gameService:GetPlayerPlot(player) else nil)
        or (if cartService and cartService._playerPlotIds then cartService._playerPlotIds[userId] else nil)
        or 1
    local map = Workspace:FindFirstChild("Map")
    local plots = if map then map:FindFirstChild("PlayerPlots") else nil
    local plot = if plots then plots:FindFirstChild("Plot_" .. tostring(plotId or 1)) else nil
    local baseCFrame = if plot then plot:GetPivot() else CFrame.new(0, 3, 20)
    local kasirPos = (baseCFrame * CFrame.new(5.2, 3.2, 1.5)).Position

    local kasirArch: CustomerArchetype = {
        Id = "kasir_npc",
        Name = "Kasir Mas Budi",
        Title = "Kasir Otomatis",
        BasePatience = 999,
        SpawnWeight = 0,
        TipMultiplier = 1,
        ReputationReward = 0,
        ReputationPenalty = 0,
        AllowedRecipes = {},
        OrderQuantityMax = 1,
        Colors = {
            Shirt = Color3.fromRGB(30, 145, 75),
            Pants = Color3.fromRGB(40, 42, 48),
            Skin = Color3.fromRGB(225, 185, 145),
        },
        Dialogues = { Ordering = {}, CrispyHappy = {}, UndercookedSad = {}, Impatient = {}, AngryLeave = {} },
    }

    local kasirModel = createCustomerRig("KASIR_" .. player.Name, kasirArch, kasirPos)
    kasirModel.Name = "Kasir_" .. player.Name
    if kasirModel.PrimaryPart then
        kasirModel.PrimaryPart.Anchored = true
    end
    for _, part in kasirModel:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end

    local head = kasirModel:FindFirstChild("Head")
    local bb = if head then head:FindFirstChild("OrderBubble") :: BillboardGui? else nil
    if bb then
        local bg = bb:FindFirstChildOfClass("Frame")
        local nLbl = if bg then bg:FindFirstChild("NameLabel") :: TextLabel? else nil
        local oLbl = if bg then bg:FindFirstChild("OrderLabel") :: TextLabel? else nil
        local dLbl = if bg then bg:FindFirstChild("DialogueLabel") :: TextLabel? else nil
        if nLbl then nLbl.Text = "🧑‍💼 KASIR MAS BUDI" end
        if oLbl then oLbl.Text = "Siap Melayani Otomatis!" end
        if dLbl then dLbl.Text = "Fokus goreng aja Bos!" end
    end

    kasirModel.Parent = Workspace
    self._kasirModels[userId] = kasirModel
    log:Info("Kasir NPC 'Mas Budi' ditempatkan di Plot #%s untuk pemain %s", tostring(plotId), player.Name)

    -- Jalankan loop auto-serve setiap 2.5 detik
    task.spawn(function()
        while kasirModel.Parent and self._kasirModels[userId] == kasirModel do
            task.wait(2.5)
            local currentPlot = if gameService then gameService:GetPlayerPlot(player) else nil
            local queue = if currentPlot then self._plotQueues[currentPlot] else nil
            if queue and #queue > 0 then
                local firstCustId = queue[1]
                local order = self._activeOrders[firstCustId]
                if order and order.State == "WaitingForFood" then
                    local res = self:_executeServe(player, firstCustId, true)
                    if res.Success and bb then
                        local bg = bb:FindFirstChildOfClass("Frame")
                        local dLbl = if bg then bg:FindFirstChild("DialogueLabel") :: TextLabel? else nil
                        if dLbl then
                            dLbl.Text = "Oke beres! +Rp " .. tostring(res.Payout or 0)
                        end
                    end
                end
            end
        end
    end)

    return kasirModel
end

function CustomerService:_handleCustomerLostPatience(customerId: string, order: CustomerOrder, model: Model, archetype: CustomerArchetype?)
    order.State = "LostPatience"
    log:Info("Pelanggan %s kehilangan kesabaran di Plot #%d dan meninggalkan antrean.", customerId, order.PlotId)

    local arch = archetype or CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()
    local leaveDialogue = "Lama banget nih, saya batal aja!"
    if arch and arch.Dialogues and arch.Dialogues.AngryLeave and #arch.Dialogues.AngryLeave > 0 then
        leaveDialogue = arch.Dialogues.AngryLeave[math.random(1, #arch.Dialogues.AngryLeave)]
    end
    self:_updateBubbleText(model, "BATAL! (Terlalu Lama)", leaveDialogue)

    local custHrp = model.PrimaryPart
    if custHrp then
        local prompt = custHrp:FindFirstChild("ServePrompt")
        if prompt then prompt:Destroy() end
    end

    task.spawn(function()
        task.wait(1.5)
        self:_despawnCustomer(customerId, order.PlotId)
    end)
end

function CustomerService:ClearPlotCustomers(plotId: number)
    local queue = self._plotQueues[plotId]
    if not queue then return end

    local copy = table.clone(queue)
    for _, customerId in ipairs(copy) do
        self._activeOrders[customerId] = nil
        local model = self._customerModels[customerId]
        if model and model.Parent then
            model:Destroy()
        end
        self._customerModels[customerId] = nil
    end
    self._plotQueues[plotId] = {}
    log:Info("Antrean pelanggan di Plot #%d dibersihkan karena pemilik plot keluar.", plotId)
end

function CustomerService:_despawnCustomer(customerId: string, plotId: number)
    local model = self._customerModels[customerId]
    local queue = self._plotQueues[plotId]

    -- Hapus dari antrean plot
    if queue then
        local idx = table.find(queue, customerId)
        if idx then
            table.remove(queue, idx)
        end
    end

    self._activeOrders[customerId] = nil

    -- Pelanggan berjalan keluar ke pinggir jalan lalu hancur
    if model and model.PrimaryPart then
        local humanoid = model:FindFirstChild("Humanoid") :: Humanoid?
        if humanoid then
            humanoid:MoveTo(Vector3.new(0, 2, 0)) -- Jalan ke tengah aspal lalu hilang
        end
        task.delay(2.5, function()
            model:Destroy()
            self._customerModels[customerId] = nil
        end)
    end

    -- Geser seluruh pelanggan yang tersisa di antrean maju ke slot berikutnya
    self:_advanceQueue(plotId)
end

function CustomerService:_advanceQueue(plotId: number)
    local queue = self._plotQueues[plotId]
    if not queue then return end

    for newSlot, custId in ipairs(queue) do
        local order = self._activeOrders[custId]
        local model = self._customerModels[custId]

        if order and model then
            order.QueueSlot = newSlot
            local targetPos = self:_getQueueSlotPosition(plotId, newSlot)
            local humanoid = model:FindFirstChild("Humanoid") :: Humanoid?

            if targetPos and humanoid then
                humanoid:MoveTo(targetPos)
            end

            -- Jika sekarang menempati Slot 1 terdepan, mulai pesanannya!
            if newSlot == 1 and order.State ~= "WaitingForFood" and order.State ~= "Served" and order.State ~= "LostPatience" then
                local archetype = CustomerConfig.GetArchetype(order.ArchetypeId) or CustomerConfig.GetRandomArchetype()
                local recipe = RecipesConfig.GetRecipe(order.RecipeId)
                task.spawn(function()
                    local RunService = game:GetService("RunService")
                    if humanoid and RunService:IsRunning() then
                        local arrived = false
                        local conn: RBXScriptConnection?
                        conn = humanoid.MoveToFinished:Connect(function()
                            arrived = true
                            if conn then conn:Disconnect() end
                        end)
                        local startWait = os.clock()
                        while not arrived and (os.clock() - startWait) < 4 do
                            task.wait(0.2)
                        end
                        if conn then conn:Disconnect() end
                    end
                    self:_setupActiveCustomerOrder(custId, order, model, archetype, recipe)
                end)
            end
        end
    end
end

return CustomerService
