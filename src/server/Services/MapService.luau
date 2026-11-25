--!strict
--[[
    MapService.luau
    Layanan server untuk membangun dan mengelola peta dunia "Gorengan 24 Jam: Awas Satpol!".
    Membangun lingkungan jalanan kota Indonesia low-poly modular secara terprogram:
    - Main Street & Sidewalks (Trotoar dengan ramp halus)
    - 8 Plot Gerobak Pemain dengan tanda kavling & area antrean
    - Central Hub & Plaza Spawning
    - Toko Bahan Baku, Kios Cabai Gacha, Bengkel Upgrade
    - ATM Center 24 Jam
    - 2 Gang Aman (Safe Zones) dengan tanda neon hijau & tag CollectionService
    - Deretan Ruko 2 lantai bertingkat
    - Tiang listrik beton, kabel gantung, lampu jalan, & dekorasi pasar malam
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service

local log = Logger.new("MapService")

local MapService = {
    Name = "MapService",
    _mapFolder = nil :: Folder?,
    _safeZoneParts = {} :: { BasePart },
    _plots = {} :: { [number]: Model },
}

-- Palet warna tema perkotaan Indonesia
local PALETTE = {
    Asphalt = Color3.fromRGB(42, 42, 46),
    RoadMarkingWhite = Color3.fromRGB(240, 240, 240),
    RoadMarkingYellow = Color3.fromRGB(245, 195, 35),
    Sidewalk = Color3.fromRGB(155, 155, 160),
    SidewalkCurb = Color3.fromRGB(120, 120, 125),
    PlotTile = Color3.fromRGB(215, 185, 145),
    PlotBorder = Color3.fromRGB(160, 130, 95),
    WoodBrown = Color3.fromRGB(120, 80, 50),
    ConcretePole = Color3.fromRGB(140, 140, 145),
    CableBlack = Color3.fromRGB(20, 20, 20),
    StreetLampWarm = Color3.fromRGB(255, 240, 190),
    SafeZoneNeon = Color3.fromRGB(50, 255, 100),
    SafeZoneWall = Color3.fromRGB(80, 100, 85),
    ATMBlue = Color3.fromRGB(20, 90, 210),
    ATMGlass = Color3.fromRGB(180, 220, 240),
    RukoPastels = {
        Color3.fromRGB(175, 210, 190), -- Mint
        Color3.fromRGB(235, 215, 175), -- Cream
        Color3.fromRGB(210, 160, 145), -- Terracotta
        Color3.fromRGB(165, 195, 225), -- Light Blue
        Color3.fromRGB(230, 200, 140), -- Warm Sand
    },
    AwningRed = Color3.fromRGB(200, 45, 45),
    AwningWhite = Color3.fromRGB(240, 240, 240),
}

-- ============================================================================
-- BUILDER HELPERS
-- ============================================================================

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

local function createSign(parent: Instance, title: string, cframe: CFrame, size: Vector2, bgColor: Color3, textColor: Color3): Model
    local model = Instance.new("Model")
    model.Name = "Sign_" .. title:gsub("%s+", "_")

    local post = createPart(model, "Post", Vector3.new(0.6, 6, 0.6), cframe * CFrame.new(0, 3, 0), PALETTE.WoodBrown, Enum.Material.Wood, true)
    local board = createPart(model, "Board", Vector3.new(size.X, size.Y, 0.4), cframe * CFrame.new(0, 6 + (size.Y * 0.5), 0), bgColor, Enum.Material.SmoothPlastic, true)

    for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "Display_" .. face.Name
        surfaceGui.Face = face
        surfaceGui.CanvasSize = Vector2.new(400, 200)
        surfaceGui.Adornee = board
        surfaceGui.Parent = board

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = textColor
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.Text = title
        textLabel.Parent = surfaceGui
    end

    model.PrimaryPart = post
    model.Parent = parent
    return model
end

-- ============================================================================
-- PROCEDURAL MAP GENERATION
-- ============================================================================

function MapService:_buildMainStreet(mapFolder: Folder)
    local roads = Instance.new("Folder")
    roads.Name = "Roads"
    roads.Parent = mapFolder

    -- Jalan aspal utama (panjang 380 studs, lebar 32 studs)
    createPart(roads, "AsphaltRoad", Vector3.new(380, 1, 32), CFrame.new(0, 0.5, 0), PALETTE.Asphalt, Enum.Material.Concrete, true)

    -- Garis marka kuning/putih putus-putus di tengah jalan (Z = 0)
    local markings = Instance.new("Folder")
    markings.Name = "Markings"
    markings.Parent = roads

    for x = -170, 170, 16 do
        createPart(markings, "CenterStripe", Vector3.new(8, 0.05, 0.8), CFrame.new(x, 1.05, 0), PALETTE.RoadMarkingYellow, Enum.Material.SmoothPlastic, false)
    end

    -- Zebra cross penyeberangan pejalan kaki di Central Hub (X = -160) dan Persimpangan (X = 0)
    for _, crossX in { -160, 0 } do
        for z = -14, 14, 3 do
            createPart(markings, "ZebraStripe", Vector3.new(3, 0.05, 1.6), CFrame.new(crossX, 1.06, z), PALETTE.RoadMarkingWhite, Enum.Material.SmoothPlastic, false)
        end
    end

    -- Trotoar Utara (Z = 22, lebar 12 studs)
    local sidewalks = Instance.new("Folder")
    sidewalks.Name = "Sidewalks"
    sidewalks.Parent = mapFolder

    createPart(sidewalks, "NorthSidewalk", Vector3.new(380, 1.4, 12), CFrame.new(0, 0.7, 22), PALETTE.Sidewalk, Enum.Material.Pavement, true)
    createPart(sidewalks, "NorthCurbRamp", Vector3.new(380, 0.4, 1.5), CFrame.new(0, 0.4, 15.5), PALETTE.SidewalkCurb, Enum.Material.Concrete, true)

    -- Trotoar Selatan (Z = -22, lebar 12 studs)
    createPart(sidewalks, "SouthSidewalk", Vector3.new(380, 1.4, 12), CFrame.new(0, 0.7, -22), PALETTE.Sidewalk, Enum.Material.Pavement, true)
    createPart(sidewalks, "SouthCurbRamp", Vector3.new(380, 0.4, 1.5), CFrame.new(0, 0.4, -15.5), PALETTE.SidewalkCurb, Enum.Material.Concrete, true)
end

function MapService:_buildPlayerPlots(mapFolder: Folder)
    local plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "PlayerPlots"
    plotsFolder.Parent = mapFolder

    -- Koordinat 8 plot yang lapang dan tidak saling bertabrakan
    local plotCoordinates = {
        -- Sisi Utara (Plot 1 - 4)
        [1] = Vector3.new(-120, 1.45, 23),
        [2] = Vector3.new(-50, 1.45, 23),
        [3] = Vector3.new(20, 1.45, 23),
        [4] = Vector3.new(90, 1.45, 23),
        -- Sisi Selatan (Plot 5 - 8)
        [5] = Vector3.new(-120, 1.45, -23),
        [6] = Vector3.new(-50, 1.45, -23),
        [7] = Vector3.new(20, 1.45, -23),
        [8] = Vector3.new(90, 1.45, -23),
    }

    for plotId = 1, 8 do
        local centerPos = plotCoordinates[plotId]
        local isNorth = centerPos.Z > 0
        local rotationY = if isNorth then 0 else math.pi

        local plotModel = Instance.new("Model")
        plotModel.Name = "Plot_" .. tostring(plotId)

        -- Ubin paving kavling (ukuran 18x12 studs)
        local pad = createPart(plotModel, "PavementPad", Vector3.new(18, 0.1, 10), CFrame.new(centerPos), PALETTE.PlotTile, Enum.Material.Concrete, true)
        plotModel.PrimaryPart = pad

        -- Garis batas kavling
        createPart(plotModel, "PadBorder", Vector3.new(18.4, 0.15, 10.4), CFrame.new(centerPos - Vector3.new(0, 0.02, 0)), PALETTE.PlotBorder, Enum.Material.Concrete, true)

        -- Papan penanda kavling gerobak
        local signOffset = if isNorth then Vector3.new(7.5, 0, 4) else Vector3.new(7.5, 0, -4)
        createSign(plotModel, "KAVLING #" .. tostring(plotId), CFrame.new(centerPos + signOffset) * CFrame.Angles(0, rotationY, 0), Vector2.new(4, 2), PALETTE.WoodBrown, Color3.fromRGB(255, 240, 180))

        -- Titik parkir gerobak (CartSpawn Attachment/Part)
        local cartSpawn = Instance.new("Part")
        cartSpawn.Name = "CartSpawn"
        cartSpawn.Size = Vector3.new(4, 1, 6)
        cartSpawn.CFrame = CFrame.new(centerPos.X - 3, centerPos.Y + 0.5, centerPos.Z) * CFrame.Angles(0, rotationY, 0)
        cartSpawn.Transparency = 1
        cartSpawn.CanCollide = false
        cartSpawn.Anchored = true
        cartSpawn.Parent = plotModel

        -- Meja dapur / wajan preparation counter
        local tableX = centerPos.X + 4
        local counter = createPart(plotModel, "PrepCounter", Vector3.new(5, 2.8, 3.5), CFrame.new(tableX, centerPos.Y + 1.4, centerPos.Z), PALETTE.WoodBrown, Enum.Material.WoodPlanks, true)

        -- Wajan mockup sederhana di atas meja
        createPart(plotModel, "WajanBase", Vector3.new(2.4, 0.4, 2.4), CFrame.new(tableX, centerPos.Y + 3.0, centerPos.Z), Color3.fromRGB(30, 30, 32), Enum.Material.Metal, true)

        -- Titik antrean pembeli (3 slot antrean di depan gerobak)
        local queueFolder = Instance.new("Folder")
        queueFolder.Name = "CustomerQueue"
        queueFolder.Parent = plotModel

        local queueDir = if isNorth then -1 else 1
        for qIndex = 1, 3 do
            local qPos = Vector3.new(centerPos.X, centerPos.Y, centerPos.Z + (qIndex * 2.8 * queueDir))
            local qPart = Instance.new("Part")
            qPart.Name = "QueueSlot_" .. tostring(qIndex)
            qPart.Size = Vector3.new(2, 0.05, 2)
            qPart.CFrame = CFrame.new(qPos)
            qPart.Transparency = 1
            qPart.CanCollide = false
            qPart.Anchored = true
            qPart.Parent = queueFolder
        end

        plotModel.Parent = plotsFolder
        self._plots[plotId] = plotModel
    end
end

function MapService:_buildCentralHub(mapFolder: Folder)
    local hub = Instance.new("Folder")
    hub.Name = "CentralHub"
    hub.Parent = mapFolder

    local hubX = -160
    -- Plaza persimpangan luas (50x50 studs)
    createPart(hub, "PlazaFloor", Vector3.new(50, 1.4, 50), CFrame.new(hubX, 0.7, 0), Color3.fromRGB(180, 175, 170), Enum.Material.Pavement, true)

    -- Gerbang Selamat Datang Kampung Gorengan
    local archModel = Instance.new("Model")
    archModel.Name = "WelcomeArch"

    local poleLeft = createPart(archModel, "ArchPoleLeft", Vector3.new(1.8, 14, 1.8), CFrame.new(hubX, 7, -14), Color3.fromRGB(160, 40, 40), Enum.Material.Wood, true)
    local poleRight = createPart(archModel, "ArchPoleRight", Vector3.new(1.8, 14, 1.8), CFrame.new(hubX, 7, 14), Color3.fromRGB(160, 40, 40), Enum.Material.Wood, true)
    local crossBeam = createPart(archModel, "ArchBeam", Vector3.new(2.4, 2.5, 30), CFrame.new(hubX, 14, 0), Color3.fromRGB(180, 45, 45), Enum.Material.Wood, true)

    -- Papan nama gerbang
    createSign(archModel, "KAMPUNG GORENGAN 24 JAM", CFrame.new(hubX, 12, 0) * CFrame.Angles(0, math.pi * 0.5, 0), Vector2.new(14, 3), Color3.fromRGB(240, 185, 40), Color3.fromRGB(120, 20, 20))

    archModel.PrimaryPart = crossBeam
    archModel.Parent = hub

    -- SpawnLocation pemain di Plaza
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "MainSpawnLocation"
    spawn.Size = Vector3.new(12, 0.5, 12)
    spawn.CFrame = CFrame.new(hubX, 1.5, 0)
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Color = Color3.fromRGB(200, 195, 190)
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = hub
end

function MapService:_buildShops(mapFolder: Folder)
    local shopsFolder = Instance.new("Folder")
    shopsFolder.Name = "Shops"
    shopsFolder.Parent = mapFolder

    -- 1. Toko Bahan Baku "Sumber Rejeki" (X = -15, Z = 38)
    local ingShop = Instance.new("Model")
    ingShop.Name = "IngredientShop"
    local ingBase = createPart(ingShop, "Building", Vector3.new(22, 12, 14), CFrame.new(-15, 6.7, 38), Color3.fromRGB(240, 220, 180), Enum.Material.Concrete, true)
    ingShop.PrimaryPart = ingBase
    -- Tenda garis merah putih
    createPart(ingShop, "Awning", Vector3.new(22.5, 0.4, 6), CFrame.new(-15, 8.5, 29) * CFrame.Angles(math.rad(15), 0, 0), PALETTE.AwningRed, Enum.Material.Fabric, false)
    createSign(ingShop, "TOKO BAHAN BAKU", CFrame.new(-15, 8.5, 30.5), Vector2.new(12, 2.2), Color3.fromRGB(220, 40, 40), Color3.fromRGB(255, 255, 255))
    -- Prompt part
    local ingPrompt = createPart(ingShop, "ShopInteractionPart", Vector3.new(4, 3, 2), CFrame.new(-15, 2.5, 30), Color3.fromRGB(200, 200, 200), Enum.Material.Wood, true)
    ingPrompt.Transparency = 0.5
    local ingP = Instance.new("ProximityPrompt")
    ingP.Name = "IngredientShopPrompt"
    ingP.ActionText = "Buka Toko Bahan"
    ingP.ObjectText = "Toko Bahan Baku 'Sumber Rejeki'"
    ingP.HoldDuration = 0.3
    ingP.MaxActivationDistance = 9
    ingP.Parent = ingPrompt
    ingShop.Parent = shopsFolder

    -- 2. Kios Cabai Gacha "Pedas Mampus" (X = 55, Z = 38)
    local chiliShop = Instance.new("Model")
    chiliShop.Name = "ChiliGachaShop"
    local chiliBase = createPart(chiliShop, "Building", Vector3.new(18, 11, 14), CFrame.new(55, 6.2, 38), Color3.fromRGB(210, 80, 60), Enum.Material.Concrete, true)
    chiliShop.PrimaryPart = chiliBase
    createPart(chiliShop, "Awning", Vector3.new(18.5, 0.4, 5.5), CFrame.new(55, 8.0, 29.5) * CFrame.Angles(math.rad(15), 0, 0), Color3.fromRGB(40, 160, 60), Enum.Material.Fabric, false)
    createSign(chiliShop, "KIOS CABAI GACHA", CFrame.new(55, 8.0, 30.5), Vector2.new(11, 2.2), Color3.fromRGB(180, 30, 20), Color3.fromRGB(255, 240, 100))
    local chiliPrompt = createPart(chiliShop, "ShopInteractionPart", Vector3.new(4, 3, 2), CFrame.new(55, 2.5, 30), Color3.fromRGB(200, 200, 200), Enum.Material.Wood, true)
    chiliPrompt.Transparency = 0.5
    local chiliP = Instance.new("ProximityPrompt")
    chiliP.Name = "ChiliShopPrompt"
    chiliP.ActionText = "Buka Kios Cabai"
    chiliP.ObjectText = "Kios Cabai & Bibit Langka"
    chiliP.HoldDuration = 0.3
    chiliP.MaxActivationDistance = 9
    chiliP.Parent = chiliPrompt
    chiliShop.Parent = shopsFolder

    -- 3. Bengkel Upgrade Gerobak "Maju Lancar" (X = -85, Z = 38)
    local upgShop = Instance.new("Model")
    upgShop.Name = "UpgradeShop"
    local upgBase = createPart(upgShop, "Building", Vector3.new(24, 13, 14), CFrame.new(-85, 7.2, 38), Color3.fromRGB(110, 120, 135), Enum.Material.Metal, true)
    upgShop.PrimaryPart = upgBase
    -- Rolling door abu-abu terbuka
    createPart(upgShop, "RollingDoor", Vector3.new(16, 7, 0.5), CFrame.new(-85, 4.2, 30.8), Color3.fromRGB(75, 80, 85), Enum.Material.DiamondPlate, true)
    createSign(upgShop, "BENGKEL UPGRADE GEROBAK", CFrame.new(-85, 9.5, 30.8), Vector2.new(14, 2.4), Color3.fromRGB(40, 50, 65), Color3.fromRGB(240, 190, 40))
    local upgPrompt = createPart(upgShop, "ShopInteractionPart", Vector3.new(4, 3, 2), CFrame.new(-85, 2.5, 30), Color3.fromRGB(180, 180, 180), Enum.Material.Metal, true)
    upgPrompt.Transparency = 0.5
    local upgP = Instance.new("ProximityPrompt")
    upgP.Name = "UpgradeShopPrompt"
    upgP.ActionText = "Buka Bengkel Upgrade"
    upgP.ObjectText = "Bengkel Gerobak 'Maju Lancar'"
    upgP.HoldDuration = 0.3
    upgP.MaxActivationDistance = 9
    upgP.Parent = upgPrompt
    upgShop.Parent = shopsFolder
end

function MapService:_buildATMAndBank(mapFolder: Folder)
    local bankFolder = Instance.new("Folder")
    bankFolder.Name = "ATMAndBank"
    bankFolder.Parent = mapFolder

    local atmX = 135
    local atmZ = 38
    local atmModel = Instance.new("Model")
    atmModel.Name = "ATM_Center"

    -- Gedung Mini ATM kaca modern
    local building = createPart(atmModel, "Booth", Vector3.new(16, 11, 12), CFrame.new(atmX, 6.2, atmZ), Color3.fromRGB(235, 240, 245), Enum.Material.Concrete, true)
    atmModel.PrimaryPart = building

    -- Kaca depan transparan
    createPart(atmModel, "FrontGlass", Vector3.new(14, 7, 0.4), CFrame.new(atmX, 4.2, atmZ - 5.8), PALETTE.ATMGlass, Enum.Material.Glass, true).Transparency = 0.6

    -- Papan nama neon biru ATM 24 JAM
    createSign(atmModel, "ATM CENTER 24 JAM", CFrame.new(atmX, 8.5, atmZ - 6.0), Vector2.new(12, 2.2), PALETTE.ATMBlue, Color3.fromRGB(255, 255, 255))

    -- 2 Unit Mesin ATM interaktif
    for _, offset in { -3.5, 3.5 } do
        local machine = createPart(atmModel, "ATMMachine", Vector3.new(3, 5, 2.5), CFrame.new(atmX + offset, 3.2, atmZ - 3), PALETTE.ATMBlue, Enum.Material.Metal, true)
        -- Layar monitor ATM yang menyala
        createPart(atmModel, "Screen", Vector3.new(1.8, 1.2, 0.2), CFrame.new(atmX + offset, 4.0, atmZ - 4.2), Color3.fromRGB(100, 220, 255), Enum.Material.Neon, false)
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Gunakan ATM"
        prompt.ObjectText = "Setor / Tarik Tabungan"
        prompt.HoldDuration = 0.5
        prompt.MaxActivationDistance = 8
        prompt.RequiresLineOfSight = false
        prompt.Parent = machine
    end

    atmModel.Parent = bankFolder
end

function MapService:_buildSafeAlleys(mapFolder: Folder)
    local safeZonesFolder = Instance.new("Folder")
    safeZonesFolder.Name = "SafeAlleys"
    safeZonesFolder.Parent = mapFolder

    -- Koordinat 2 Gang Aman yang strategis di sisi Selatan
    local safeAlleyConfigs = {
        { Name = "SafeZone_Barat", X = -15, Z = -50, Width = 16, Length = 42 },
        { Name = "SafeZone_Timur", X = 105, Z = -50, Width = 16, Length = 42 },
    }

    for _, config in safeAlleyConfigs do
        local alleyModel = Instance.new("Model")
        alleyModel.Name = config.Name

        -- Lantai gang paving bata merah
        createPart(alleyModel, "AlleyFloor", Vector3.new(config.Width, 1.4, config.Length), CFrame.new(config.X, 0.7, config.Z), Color3.fromRGB(165, 120, 100), Enum.Material.Brick, true)

        -- Dinding ruko pembatas gang (Kiri dan Kanan)
        local wallHalfWidth = config.Width * 0.5 + 1
        createPart(alleyModel, "WallLeft", Vector3.new(2, 14, config.Length), CFrame.new(config.X - wallHalfWidth, 7, config.Z), PALETTE.SafeZoneWall, Enum.Material.Concrete, true)
        createPart(alleyModel, "WallRight", Vector3.new(2, 14, config.Length), CFrame.new(config.X + wallHalfWidth, 7, config.Z), PALETTE.SafeZoneWall, Enum.Material.Concrete, true)

        -- Gerbang Neon Hijau Penanda Gang Aman (Di bibir gang, Z = -28)
        local archEntrance = CFrame.new(config.X, 8, -28)
        createPart(alleyModel, "ArchTop", Vector3.new(config.Width + 2, 1.8, 1.8), archEntrance, Color3.fromRGB(30, 80, 40), Enum.Material.Metal, true)
        createSign(alleyModel, "GANG AMAN (SAFE ZONE)", archEntrance + Vector3.new(0, 1.5, 0), Vector2.new(12, 2.2), Color3.fromRGB(20, 160, 50), Color3.fromRGB(255, 255, 255))

        -- Lampu neon hijau penanda zona aman
        local neonLamp = createPart(alleyModel, "NeonBeacon", Vector3.new(config.Width, 0.4, 0.4), archEntrance - Vector3.new(0, 1, 0), PALETTE.SafeZoneNeon, Enum.Material.Neon, false)
        local greenLight = Instance.new("PointLight")
        greenLight.Color = PALETTE.SafeZoneNeon
        greenLight.Brightness = 2.0
        greenLight.Range = 24
        greenLight.Shadows = false -- Dioptimalkan untuk performa mobile
        greenLight.Parent = neonLamp

        -- ZONEPART: Deteksi Bounding Box Safe Zone untuk Server & Satpol AI
        local zonePart = Instance.new("Part")
        zonePart.Name = "ZonePart"
        zonePart.Size = Vector3.new(config.Width, 15, config.Length)
        zonePart.CFrame = CFrame.new(config.X, 7.5, config.Z)
        zonePart.Transparency = 1
        zonePart.CanCollide = false
        zonePart.Anchored = true
        zonePart.Parent = alleyModel

        -- Tag CollectionService resmi
        CollectionService:AddTag(zonePart, GameConfig.SafeZoneTag)
        table.insert(self._safeZoneParts, zonePart)

        alleyModel.Parent = safeZonesFolder
    end
end

function MapService:_buildRukoRow(mapFolder: Folder)
    local rukoFolder = Instance.new("Folder")
    rukoFolder.Name = "RukoArea"
    rukoFolder.Parent = mapFolder

    -- Bangun deretan ruko bertingkat 2 di sisi Selatan (Z = -44)
    local rukoXs = { -155, -120, -85, -50, 20, 55, 140, 165 }
    for i, x in rukoXs do
        local pastelColor = PALETTE.RukoPastels[(i % #PALETTE.RukoPastels) + 1]
        local rukoModel = Instance.new("Model")
        rukoModel.Name = "Ruko_" .. tostring(i)

        -- Lantai 1 & 2
        local building = createPart(rukoModel, "Building", Vector3.new(24, 18, 18), CFrame.new(x, 9.7, -44), pastelColor, Enum.Material.Concrete, true)
        rukoModel.PrimaryPart = building

        -- Pintu gulung (Rolling door) lantai 1
        createPart(rukoModel, "RollingDoor", Vector3.new(16, 7.5, 0.4), CFrame.new(x, 4.5, -34.8), Color3.fromRGB(90, 95, 100), Enum.Material.DiamondPlate, true)

        -- Kanopi lantai 2
        createPart(rukoModel, "Canopy", Vector3.new(20, 0.4, 4), CFrame.new(x, 9.5, -33.5) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(150, 60, 50), Enum.Material.Fabric, false)

        -- Jendela lantai 2
        for _, winX in { -5, 5 } do
            createPart(rukoModel, "Window", Vector3.new(4, 4.5, 0.3), CFrame.new(x + winX, 13.5, -34.8), Color3.fromRGB(160, 200, 220), Enum.Material.Glass, true).Transparency = 0.5
        end

        rukoModel.Parent = rukoFolder
    end
end

function MapService:_buildStreetProps(mapFolder: Folder)
    local propsFolder = Instance.new("Folder")
    propsFolder.Name = "StreetProps"
    propsFolder.Parent = mapFolder

    -- Tiang listrik beton dengan lampu jalan & kabel gantung (setiap 40 studs)
    local poleXs = { -160, -120, -80, -40, 0, 40, 80, 120, 160 }
    for i, x in poleXs do
        local poleModel = Instance.new("Model")
        poleModel.Name = "TiangListrik_" .. tostring(i)

        -- Tiang utama
        local pole = createPart(poleModel, "ConcretePole", Vector3.new(1.2, 18, 1.2), CFrame.new(x, 9.5, 16.5), PALETTE.ConcretePole, Enum.Material.Concrete, true)
        poleModel.PrimaryPart = pole

        -- Palang kayu/besi atas (crossarm kabel)
        createPart(poleModel, "Crossarm", Vector3.new(1.0, 0.6, 6), CFrame.new(x, 17, 16.5), Color3.fromRGB(60, 60, 65), Enum.Material.Wood, false)

        -- Lampu jalan merkuri (PointLight hangat tanpa shadow untuk mobile)
        local lampHead = createPart(poleModel, "LampHead", Vector3.new(1.6, 0.6, 2.4), CFrame.new(x, 15, 14.5), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, false)
        local bulb = createPart(poleModel, "Bulb", Vector3.new(1.0, 0.3, 1.6), CFrame.new(x, 14.6, 14.5), PALETTE.StreetLampWarm, Enum.Material.Neon, false)

        local light = Instance.new("PointLight")
        light.Color = PALETTE.StreetLampWarm
        light.Brightness = 1.6
        light.Range = 28
        light.Shadows = false
        light.Parent = bulb

        poleModel.Parent = propsFolder

        -- Hubungkan kabel listrik ke tiang berikutnya
        local nextX = poleXs[i + 1]
        if nextX then
            local dist = nextX - x
            local midX = x + (dist * 0.5)
            -- Kabel atas dan bawah
            createPart(propsFolder, "Kabel_1", Vector3.new(dist, 0.15, 0.15), CFrame.new(midX, 16.8, 14.5), PALETTE.CableBlack, Enum.Material.SmoothPlastic, false)
            createPart(propsFolder, "Kabel_2", Vector3.new(dist, 0.15, 0.15), CFrame.new(midX, 16.5, 18.5), PALETTE.CableBlack, Enum.Material.SmoothPlastic, false)
        end
    end

    -- Papan Leaderboard Pedagang Sukses di Central Plaza (X = -160, Z = 22)
    local lbModel = Instance.new("Model")
    lbModel.Name = "LeaderboardBoard"
    createPart(lbModel, "BoardLeft", Vector3.new(12, 10, 0.6), CFrame.new(-167, 7, 22), Color3.fromRGB(45, 55, 70), Enum.Material.Wood, true)
    createSign(lbModel, "TOP SULTAN GORENGAN", CFrame.new(-167, 11, 22), Vector2.new(11, 1.8), Color3.fromRGB(240, 190, 40), Color3.fromRGB(20, 20, 20))

    createPart(lbModel, "BoardRight", Vector3.new(12, 10, 0.6), CFrame.new(-153, 7, 22), Color3.fromRGB(45, 55, 70), Enum.Material.Wood, true)
    createSign(lbModel, "PENGGORENG CRISPY TERBAIK", CFrame.new(-153, 11, 22), Vector2.new(11, 1.8), Color3.fromRGB(220, 80, 40), Color3.fromRGB(255, 255, 255))
    lbModel.Parent = propsFolder
end

-- ============================================================================
-- LIFECYCLE SERVICE
-- ============================================================================

function MapService:Init()
    log:Info("Menginisialisasi MapService...")

    local existing = Workspace:FindFirstChild("Map")
    if existing and existing:IsA("Folder") then
        log:Info("Peta 'Map' yang sudah ada terdeteksi di Workspace. Memverifikasi struktur...")
        self._mapFolder = existing
        self:_indexExistingMap(existing)
    else
        log:Info("Peta belum ditemukan. Membangun peta modular 'Gorengan 24 Jam'...")
        self:BuildCompleteMap()
    end
end

function MapService:Start()
    log:Info("MapService aktif. %d Safe Zones & %d Plot siap digunakan.", #self._safeZoneParts, #self:GetAvailablePlotIds())
end

function MapService:BuildCompleteMap()
    local startTime = os.clock()

    -- Hapus map lama jika ada
    local oldMap = Workspace:FindFirstChild("Map")
    if oldMap then
        oldMap:Destroy()
    end

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "Map"
    mapFolder.Parent = Workspace
    self._mapFolder = mapFolder

    self:_buildMainStreet(mapFolder)
    self:_buildPlayerPlots(mapFolder)
    self:_buildCentralHub(mapFolder)
    self:_buildShops(mapFolder)
    self:_buildATMAndBank(mapFolder)
    self:_buildSafeAlleys(mapFolder)
    self:_buildRukoRow(mapFolder)
    self:_buildStreetProps(mapFolder)
    self:_buildPolishDecorations(mapFolder)

    local elapsed = (os.clock() - startTime) * 1000
    log:Info("Peta modular berhasil dibangun dalam %.2f ms. Total instance terpasang di Workspace.Map.", elapsed)
end

function MapService:_buildPolishDecorations(mapFolder: Folder)
    local existing = mapFolder:FindFirstChild("PolishDecorations")
    if existing then
        existing:Destroy()
    end

    local decoFolder = Instance.new("Folder")
    decoFolder.Name = "PolishDecorations"
    decoFolder.Parent = mapFolder

    -- 1. Landmark Tugu Gorengan Nusantara di Central Hub Plaza (X = -146, Z = -16)
    local tugu = Instance.new("Model")
    tugu.Name = "TuguGorenganNusantara"
    local base1 = createPart(tugu, "PedestalBase", Vector3.new(9, 1.4, 9), CFrame.new(-146, 2.1, -16), Color3.fromRGB(115, 115, 125), Enum.Material.Concrete, true)
    createPart(tugu, "PedestalMid", Vector3.new(6, 2.2, 6), CFrame.new(-146, 3.9, -16), Color3.fromRGB(165, 45, 40), Enum.Material.Brick, true)
    createPart(tugu, "Pillar", Vector3.new(2.4, 5.5, 2.4), CFrame.new(-146, 7.7, -16), Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic, true)
    local goldenGorengan = createPart(tugu, "GoldenGorenganSculpture", Vector3.new(3.8, 1.4, 3.8), CFrame.new(-146, 11.2, -16) * CFrame.Angles(math.rad(12), math.rad(35), math.rad(8)), Color3.fromRGB(245, 185, 40), Enum.Material.Neon, false)
    local tuguLight = Instance.new("PointLight")
    tuguLight.Color = Color3.fromRGB(255, 210, 110)
    tuguLight.Range = 22
    tuguLight.Brightness = 1.4
    tuguLight.Shadows = false
    tuguLight.Parent = goldenGorengan
    createSign(tugu, "TUGU GORENGAN", CFrame.new(-146, 2.4, -11.2), Vector2.new(6, 1.6), Color3.fromRGB(35, 35, 42), Color3.fromRGB(255, 215, 65))
    tugu.PrimaryPart = base1
    tugu.Parent = decoFolder

    -- 2. Pos Ronda & Kentongan Bambu di gerbang Safe Zone Barat & Timur
    local posLocations = {
        { Name = "PosRonda_Barat", Pos = Vector3.new(-26.5, 1.4, -27) },
        { Name = "PosRonda_Timur", Pos = Vector3.new(93.5, 1.4, -27) },
    }
    for _, cfg in ipairs(posLocations) do
        local posModel = Instance.new("Model")
        posModel.Name = cfg.Name
        local p = cfg.Pos
        local floor = createPart(posModel, "Floor", Vector3.new(5.5, 0.5, 5.5), CFrame.new(p.X, p.Y + 0.25, p.Z), PALETTE.WoodBrown, Enum.Material.WoodPlanks, true)
        for _, ox in { -2.2, 2.2 } do
            for _, oz in { -2.2, 2.2 } do
                createPart(posModel, "Post", Vector3.new(0.45, 6, 0.45), CFrame.new(p.X + ox, p.Y + 3.2, p.Z + oz), PALETTE.WoodBrown, Enum.Material.Wood, true)
            end
        end
        createPart(posModel, "Roof", Vector3.new(6.8, 0.8, 6.8), CFrame.new(p.X, p.Y + 6.4, p.Z), Color3.fromRGB(185, 50, 45), Enum.Material.Slate, false)
        createPart(posModel, "KentonganBambu", Vector3.new(0.55, 1.8, 0.55), CFrame.new(p.X + 2.4, p.Y + 4.4, p.Z + 2.2), Color3.fromRGB(195, 160, 80), Enum.Material.Wood, false)
        posModel.PrimaryPart = floor
        posModel.Parent = decoFolder
    end

    -- 3. Pohon Tropis Rindang & Bangku Tongkrongan di sepanjang trotoar luar
    local treeXs = { -138, -72, -4, 68, 128 }
    for _, tx in ipairs(treeXs) do
        for _, tz in { 30.5, -30.5 } do
            local tree = Instance.new("Model")
            tree.Name = "PohonTropis"
            local trunk = createPart(tree, "Trunk", Vector3.new(1.5, 7, 1.5), CFrame.new(tx, 4.9, tz), Color3.fromRGB(105, 70, 45), Enum.Material.Wood, true)
            local c1 = createPart(tree, "FoliageMain", Vector3.new(6.5, 4.2, 6.5), CFrame.new(tx, 9.6, tz), Color3.fromRGB(55, 145, 65), Enum.Material.Grass, false)
            c1.Shape = Enum.PartType.Ball
            local c2 = createPart(tree, "FoliageTop", Vector3.new(4.8, 3.6, 4.8), CFrame.new(tx + 1.2, 11.2, tz - 0.8), Color3.fromRGB(70, 165, 75), Enum.Material.Grass, false)
            c2.Shape = Enum.PartType.Ball
            tree.PrimaryPart = trunk
            tree.Parent = decoFolder
        end
    end

    -- 4. Bangku Tongkrongan & Tong Sampah Kebersihan Jalanan
    local benchXs = { -102, -32, 38, 108 }
    for _, bx in ipairs(benchXs) do
        createPart(decoFolder, "BangkuTrotoar", Vector3.new(4.6, 0.45, 1.6), CFrame.new(bx, 2.2, 27.5), Color3.fromRGB(35, 120, 190), Enum.Material.SmoothPlastic, true)
        createPart(decoFolder, "TongSampah", Vector3.new(1.1, 1.8, 1.1), CFrame.new(bx + 3.2, 2.3, 27.5), Color3.fromRGB(45, 155, 75), Enum.Material.Metal, true)
    end

    -- 5. Umbul-umbul Merah Putih Kampung Gorengan pada tiang jalan utama
    for _, ux in { -120, -40, 40, 120 } do
        createPart(decoFolder, "BenderaMerah", Vector3.new(0.15, 2.0, 2.6), CFrame.new(ux, 12.2, 16.5), Color3.fromRGB(220, 35, 35), Enum.Material.Fabric, false)
        createPart(decoFolder, "BenderaPutih", Vector3.new(0.15, 2.0, 2.6), CFrame.new(ux, 10.2, 16.5), Color3.fromRGB(245, 245, 245), Enum.Material.Fabric, false)
    end
end

function MapService:_indexExistingMap(mapFolder: Folder)
    -- Indeks zona aman
    local safeAlleys = mapFolder:FindFirstChild("SafeAlleys")
    if safeAlleys then
        for _, alley in safeAlleys:GetChildren() do
            local zone = alley:FindFirstChild("ZonePart")
            if zone and zone:IsA("BasePart") then
                CollectionService:AddTag(zone, GameConfig.SafeZoneTag)
                table.insert(self._safeZoneParts, zone)
            end
        end
    end

    -- Indeks plot
    local plots = mapFolder:FindFirstChild("PlayerPlots")
    if plots then
        for i = 1, 8 do
            local p = plots:FindFirstChild("Plot_" .. tostring(i))
            if p and p:IsA("Model") then
                self._plots[i] = p
            end
        end
    end

    if not mapFolder:FindFirstChild("PolishDecorations") then
        self:_buildPolishDecorations(mapFolder)
    end
end

-- ============================================================================
-- PUBLIC QUERY APIS
-- ============================================================================

function MapService:GetPlot(plotId: number): Model?
    return self._plots[plotId]
end

function MapService:GetPlotCartCFrame(plotId: number): CFrame?
    local plot = self._plots[plotId]
    if plot then
        local spawnPart = plot:FindFirstChild("CartSpawn")
        if spawnPart and spawnPart:IsA("BasePart") then
            return spawnPart.CFrame
        end
        if plot.PrimaryPart then
            return plot.PrimaryPart.CFrame + Vector3.new(0, 1.5, 0)
        end
    end
    return nil
end

function MapService:GetAvailablePlotIds(): { number }
    local ids = {}
    for id = 1, 8 do
        if self._plots[id] then
            table.insert(ids, id)
        end
    end
    return ids
end

function MapService:GetSafeZoneParts(): { BasePart }
    return self._safeZoneParts
end

function MapService:IsPositionInSafeZone(position: Vector3): boolean
    for _, zonePart in self._safeZoneParts do
        local localPos = zonePart.CFrame:PointToObjectSpace(position)
        local halfSize = zonePart.Size * 0.5
        if math.abs(localPos.X) <= halfSize.X
            and math.abs(localPos.Y) <= halfSize.Y
            and math.abs(localPos.Z) <= halfSize.Z then
            return true
        end
    end
    return false
end

return MapService
