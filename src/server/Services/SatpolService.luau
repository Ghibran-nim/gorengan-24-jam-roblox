--!strict
--[[
    SatpolService.luau
    Layanan server untuk mengelola siklus Razia Satpol PP (Signature Gameplay Gorengan 24 Jam):
    - Peringatan razia 15 detik (Kentongan & Sirine)
    - Pengerahan pasukan Satpol PP berpatroli di jalan raya
    - Deteksi gerobak liar di luar Safe Zone (Cone of vision & Raycast LOS)
    - Pengejaran adil (12.0 studs/s, dapat dihindari pemain)
    - Pembatalan kejar otomatis jika gerobak berhasil masuk Safe Zone
    - Penangkapan & Penalti: Sitaan 25% CarriedCash & bersihkan etalase gorengan (Tabungan ATM AMAN)
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service

local log = Logger.new("SatpolService")

-- Parameter konfigurasi dengan nilai bawaan aman (defensive defaults)
local RAID_WARNING_DURATION = GameConfig.RaidWarningDurationSeconds or 15
local RAID_ACTIVE_DURATION = GameConfig.RaidActiveDurationSeconds or 45
local RAID_INTERVAL = GameConfig.RaidIntervalSeconds or 120
local SATPOL_WALK_SPEED = GameConfig.SatpolPatrolWalkSpeed or 12.0
local SATPOL_DETECTION_RADIUS = GameConfig.SatpolDetectionRadius or 35
local SATPOL_CAPTURE_DISTANCE = GameConfig.SatpolCaptureDistance or 8
local SATPOL_PENALTY_PERCENT = GameConfig.SatpolPenaltyCashPercent or 0.25
local SAFE_ZONE_TAG = GameConfig.SafeZoneTag or "SafeZone"

-- Palet seragam dinas Satpol PP khas Indonesia
local SATPOL_PALETTE = {
    KhakiShirt = Color3.fromRGB(150, 130, 95),
    KhakiPants = Color3.fromRGB(100, 85, 60),
    BeretGreen = Color3.fromRGB(35, 75, 45),
    SkinTone = Color3.fromRGB(215, 160, 115),
    BadgeGold = Color3.fromRGB(240, 190, 30),
    AlertRed = Color3.fromRGB(220, 40, 40),
}

-- Titik-titik rute patroli di sepanjang Jalan Utama (Main Street)
local PATROL_WAYPOINTS = {
    Vector3.new(-40, 3, 0),
    Vector3.new(-10, 3, 0),
    Vector3.new(25, 3, 0),
    Vector3.new(65, 3, 0),
    Vector3.new(105, 3, 0),
    Vector3.new(135, 3, 0),
}

local SatpolService = {
    Name = "SatpolService",
    _currentRaidState = "Idle" :: "Idle" | "Warning" | "Active" | "Ended",
    _stateStartTime = 0,
    _satpolSquad = {} :: { Model },
    _recentlyCaptured = {} :: { [number]: number }, -- [UserId] = os.clock()
    _services = {} :: { [string]: any },
    _raidLoopActive = false,
    _squadFolder = nil :: Folder?,
}

-- Konstruktor Model Rig Satpol PP yang teroptimasi (unanchored welded parts + Humanoid)
local function createSatpolRig(satpolId: number, spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "Satpol_" .. tostring(satpolId)

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

    -- Torso (Baju Dinas Khaki)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = CFrame.new(spawnPos)
    torso.Color = SATPOL_PALETTE.KhakiShirt
    torso.Material = Enum.Material.SmoothPlastic
    torso.CanCollide = false
    torso.Anchored = false
    torso.Parent = model

    local weldTorso = Instance.new("WeldConstraint")
    weldTorso.Part0 = hrp
    weldTorso.Part1 = torso
    weldTorso.Parent = hrp

    -- Lencana Satpol PP di dada kiri
    local badge = Instance.new("Part")
    badge.Name = "Badge"
    badge.Size = Vector3.new(0.4, 0.4, 0.1)
    badge.CFrame = CFrame.new(spawnPos + Vector3.new(-0.5, 0.5, -0.55))
    badge.Color = SATPOL_PALETTE.BadgeGold
    badge.Material = Enum.Material.Neon
    badge.CanCollide = false
    badge.Anchored = false
    badge.Parent = model

    local weldBadge = Instance.new("WeldConstraint")
    weldBadge.Part0 = torso
    weldBadge.Part1 = badge
    weldBadge.Parent = torso

    -- Head (Kepala)
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.5, 0))
    head.Color = SATPOL_PALETTE.SkinTone
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.Anchored = false
    head.Parent = model

    local weldHead = Instance.new("WeldConstraint")
    weldHead.Part0 = torso
    weldHead.Part1 = head
    weldHead.Parent = torso

    -- Baret Hijau Satpol PP
    local beret = Instance.new("Part")
    beret.Name = "Beret"
    beret.Size = Vector3.new(1.3, 0.4, 1.3)
    beret.CFrame = CFrame.new(spawnPos + Vector3.new(0, 2.1, 0))
    beret.Color = SATPOL_PALETTE.BeretGreen
    beret.Material = Enum.Material.Fabric
    beret.CanCollide = false
    beret.Anchored = false
    beret.Parent = model

    local weldBeret = Instance.new("WeldConstraint")
    weldBeret.Part0 = head
    weldBeret.Part1 = beret
    weldBeret.Parent = head

    -- Mata tegas Satpol PP
    for _, eyeX in { -0.25, 0.25 } do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Size = Vector3.new(0.16, 0.18, 0.1)
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

    -- Lengan dengan Motor6D + Pentungan Dinas Satpol di tangan kanan
    local armSpecs = {
        { Name = "LeftArm", OffsetX = -1.45 },
        { Name = "RightArm", OffsetX = 1.45 },
    }
    for _, spec in ipairs(armSpecs) do
        local arm = Instance.new("Part")
        arm.Name = spec.Name
        arm.Size = Vector3.new(0.85, 1.8, 0.85)
        arm.CFrame = CFrame.new(spawnPos + Vector3.new(spec.OffsetX, 0, 0))
        arm.Color = SATPOL_PALETTE.KhakiShirt
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

        if spec.Name == "RightArm" then
            local baton = Instance.new("Part")
            baton.Name = "SatpolBaton"
            baton.Size = Vector3.new(0.25, 0.25, 1.6)
            baton.CFrame = arm.CFrame * CFrame.new(0, -0.8, -0.6)
            baton.Color = Color3.fromRGB(30, 30, 34)
            baton.Material = Enum.Material.Metal
            baton.CanCollide = false
            baton.Anchored = false
            baton.Parent = model
            local wb = Instance.new("WeldConstraint")
            wb.Part0 = arm
            wb.Part1 = baton
            wb.Parent = arm
        end
    end

    -- Legs (Celana Khaki Tua) dengan Motor6D
    local legSpecs = {
        { Name = "LeftLeg", OffsetX = -0.5 },
        { Name = "RightLeg", OffsetX = 0.5 },
    }
    for _, spec in ipairs(legSpecs) do
        local leg = Instance.new("Part")
        leg.Name = spec.Name
        leg.Size = Vector3.new(0.9, 2, 0.9)
        leg.CFrame = CFrame.new(spawnPos + Vector3.new(spec.OffsetX, -1.8, 0))
        leg.Color = SATPOL_PALETTE.KhakiPants
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

    -- Humanoid dengan kecepatan patroli adil
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.WalkSpeed = SATPOL_WALK_SPEED
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent = model

    -- Billboard Dialog & Peringatan di atas kepala
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SatpolBillboard"
    billboard.Size = UDim2.new(0, 220, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 60
    billboard.Adornee = head
    billboard.Parent = head

    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.fromScale(1, 1)
    bgFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    bgFrame.BackgroundTransparency = 0.15
    bgFrame.Parent = billboard

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = bgFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0.45, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = SATPOL_PALETTE.AlertRed
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextScaled = true
    titleLabel.Text = "🚨 PETUGAS SATPOL PP 🚨"
    titleLabel.Parent = bgFrame

    local barkLabel = Instance.new("TextLabel")
    barkLabel.Name = "BarkLabel"
    barkLabel.Size = UDim2.new(1, -8, 0.55, 0)
    barkLabel.Position = UDim2.new(0, 4, 0.45, 0)
    barkLabel.BackgroundTransparency = 1
    barkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    barkLabel.Font = Enum.Font.GothamMedium
    barkLabel.TextScaled = true
    barkLabel.Text = "Sedang Berpatroli..."
    barkLabel.Parent = bgFrame

    return model
end

local function setSatpolBark(satpolModel: Model, message: string)
    local head = satpolModel:FindFirstChild("Head")
    if not head then return end
    local billboard = head:FindFirstChild("SatpolBillboard") :: BillboardGui?
    if not billboard then return end
    local bgFrame = billboard:FindFirstChildOfClass("Frame")
    if not bgFrame then return end
    local barkLabel = bgFrame:FindFirstChild("BarkLabel") :: TextLabel?
    if barkLabel then
        barkLabel.Text = message
    end
end

function SatpolService:_getSquadFolder(): Folder
    if self._squadFolder and self._squadFolder.Parent then
        return self._squadFolder
    end
    local existing = Workspace:FindFirstChild("SatpolSquad")
    if existing and existing:IsA("Folder") then
        self._squadFolder = existing
        return existing
    end
    local squadFolder = Instance.new("Folder")
    squadFolder.Name = "SatpolSquad"
    squadFolder.Parent = Workspace
    self._squadFolder = squadFolder
    return squadFolder
end

function SatpolService:Init()
    log:Info("Menginisialisasi SatpolService...")

    Players.PlayerAdded:Connect(function(player: Player)
        task.defer(function()
            self:SyncRaidStateToPlayer(player)
        end)
    end)

    -- Daftarkan folder squad di Workspace
    self:_getSquadFolder()

    -- Registrasi RemoteFunction untuk pemicuan manual / pengujian razia
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestForceRaidEvent, function(player: Player, state: string)
        return self:ForceRaidEvent(player, state)
    end)

    -- Registrasi RemoteFunction untuk pengecekan status Safe Zone
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestCheckSafeZone, function(player: Player, checkPosition: Vector3?)
        local pos = checkPosition
        if not pos then
            local cartPos = if self._services.CartService then self._services.CartService:GetCartPosition(player) else nil
            pos = cartPos or (player.Character and player.Character:GetPivot().Position) or Vector3.zero
        end
        return {
            Success = true,
            InSafeZone = self:IsPositionInSafeZone(pos),
        }
    end)
end

function SatpolService:_getService(serviceName: string): any
    if not self._services[serviceName] then
        local Services = script.Parent
        local mod = Services:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

function SatpolService:Start()
    self:_getService("CartService")
    self:_getService("EconomyService")
    self:_getService("InventoryService")
    self:_getService("MapService")

    log:Info("SatpolService aktif dan siap mengelola siklus razia.")

    -- Mulai loop penjadwalan razia otomatis
    self._raidLoopActive = true
    task.spawn(function()
        self:_runRaidScheduler()
    end)
end

function SatpolService:IsPositionInSafeZone(position: Vector3): boolean
    -- 1. Gunakan MapService jika tersedia
    local mapService = self:_getService("MapService")
    if mapService and mapService.IsPositionInSafeZone then
        if mapService:IsPositionInSafeZone(position) then
            return true
        end
    end

    -- 2. Fallback cek CollectionService tag
    local taggedZones = CollectionService:GetTagged(SAFE_ZONE_TAG)
    for _, zone in taggedZones do
        if zone:IsA("BasePart") then
            local localPos = zone.CFrame:PointToObjectSpace(position)
            local halfSize = zone.Size * 0.5
            if math.abs(localPos.X) <= halfSize.X
                and math.abs(localPos.Y) <= halfSize.Y
                and math.abs(localPos.Z) <= halfSize.Z then
                return true
            end
        end
    end

    return false
end

function SatpolService:GetRaidState(): string
    return self._currentRaidState
end

function SatpolService:SyncRaidStateToPlayer(player: Player)
    local state = self._currentRaidState
    if state == "Warning" then
        local elapsed = os.clock() - self._stateStartTime
        local rem = math.max(1, math.ceil(RAID_WARNING_DURATION - elapsed))
        NetworkBridge.FireClient(player, Remotes.Events.RaidAlert, "Warning", rem, string.format("AWAS SATPOL PP! Razia gerobak liar dalam %d detik!", rem))
    elseif state == "Active" then
        local elapsed = os.clock() - self._stateStartTime
        local rem = math.max(1, math.ceil(RAID_ACTIVE_DURATION - elapsed))
        NetworkBridge.FireClient(player, Remotes.Events.RaidAlert, "Active", rem, "RAZIA SEDANG BERLANGSUNG! Selamatkan gerobakmu ke Safe Zone!")
    end
end

-- ============================================================================
-- SIKLUS HIDUP RAZIA (LIFECYCLE)
-- ============================================================================

function SatpolService:StartRaidWarning(durationSeconds: number?): boolean
    local duration = durationSeconds or RAID_WARNING_DURATION
    self._currentRaidState = "Warning"
    self._stateStartTime = os.clock()

    log:Warn("PERINGATAN RAZIA: Satpol PP akan tiba dalam %d detik! Mengirim notifikasi ke semua pemain...", duration)

    NetworkBridge.FireAllClients(
        Remotes.Events.RaidAlert,
        "Warning",
        duration,
        string.format("AWAS SATPOL PP! Razia gerobak liar dalam %d detik! Segera dorong gerobak ke Gang Aman!", duration)
    )

    return true
end

function SatpolService:StartActiveRaid(durationSeconds: number?): boolean
    local duration = durationSeconds or RAID_ACTIVE_DURATION
    self._currentRaidState = "Active"
    self._stateStartTime = os.clock()

    log:Warn("RAZIA AKTIF DIMULAI! Pasukan Satpol PP diterjunkan ke Jalan Utama (Durasi: %d detik).", duration)

    -- Bersihkan sisa squad lama jika ada
    self:_despawnAllSatpol()

    -- Munculkan 2-3 petugas Satpol PP di titik awal patroli
    local squadCount = 2
    local startIndices = { 1, 4 }
    for i = 1, squadCount do
        local wpIndex = startIndices[i] or 1
        local spawnPos = PATROL_WAYPOINTS[wpIndex]
        local satpolRig = createSatpolRig(i, spawnPos)
        satpolRig.Parent = self:_getSquadFolder()
        table.insert(self._satpolSquad, satpolRig)

        task.spawn(function()
            self:_runSatpolAI(satpolRig, wpIndex)
        end)
    end

    NetworkBridge.FireAllClients(
        Remotes.Events.RaidAlert,
        "Active",
        duration,
        "RAZIA DIMULAI! Pasukan Satpol PP berpatroli di jalan raya! Selamatkan gerobakmu!"
    )

    return true
end

function SatpolService:EndRaid(): boolean
    self._currentRaidState = "Ended"
    self._stateStartTime = os.clock()

    log:Info("Razia Satpol PP telah berakhir. Menarik mundur seluruh pasukan...")

    local dataService = self:_getService("DataService")
    if dataService and dataService.RecordRaidStat then
        local now = os.clock()
        for _, p in Players:GetPlayers() do
            local capTime = self._recentlyCaptured[p.UserId] or 0
            if (now - capTime) > RAID_ACTIVE_DURATION then
                dataService:RecordRaidStat(p, false)
            end
        end
    end

    self:_despawnAllSatpol()

    NetworkBridge.FireAllClients(
        Remotes.Events.RaidAlert,
        "Ended",
        0,
        "Razia telah usai. Jalanan kembali aman untuk berdagang!"
    )

    self._currentRaidState = "Idle"
    return true
end

function SatpolService:ForceRaidEvent(player: Player, state: string): { Success: boolean, State: string, Error: string? }
    log:Info("ForceRaidEvent diminta oleh %s: Target State = '%s'", player.Name, state)

    if state == "Warning" then
        self:StartRaidWarning(RAID_WARNING_DURATION)
    elseif state == "Active" then
        self:StartActiveRaid(RAID_ACTIVE_DURATION)
    elseif state == "Ended" or state == "Idle" then
        self:EndRaid()
    else
        return { Success = false, State = self._currentRaidState, Error = "Status razia tidak valid! (Pilihan: Warning, Active, Ended)" }
    end

    return { Success = true, State = self._currentRaidState }
end

function SatpolService:_despawnAllSatpol()
    for _, satpol in self._satpolSquad do
        if satpol and satpol.Parent then
            satpol:Destroy()
        end
    end
    self._satpolSquad = {}
end

-- ============================================================================
-- SATPOL PP AI BEHAVIOR (PATROL -> DETECT -> CHASE -> CAPTURE)
-- ============================================================================

function SatpolService:_runSatpolAI(satpolModel: Model, startWaypointIndex: number)
    local currentWpIndex = startWaypointIndex
    local hrp = satpolModel:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = satpolModel:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local targetPlayer: Player? = nil
    local targetCart: Model? = nil

    while satpolModel.Parent and self._currentRaidState == "Active" do
        -- --------------------------------------------------------------------
        -- FASE 1: DETEKSI GEROBAK LIAR (SCANNING)
        -- --------------------------------------------------------------------
        if not targetPlayer or not targetCart or not targetCart.Parent then
            targetPlayer = nil
            targetCart = nil

            local satpolPos = hrp.Position
            local lookVector = hrp.CFrame.LookVector

            local cartService = self:_getService("CartService")
            if cartService and cartService.GetAllActiveCarts then
                local allCarts = cartService:GetAllActiveCarts()
                local closestDist = math.huge
                local selectedPlayer: Player? = nil
                local selectedCart: Model? = nil

                for _, cartData in allCarts do
                    local p = cartData.Player
                    local cart = cartData.Cart
                    local cartPos = cartData.Position

                    -- ATURAN 1: Gerobak di dalam Safe Zone 100% KEBAL dari deteksi & razia!
                    if self:IsPositionInSafeZone(cartPos) then
                        continue
                    end

                    -- ATURAN 2: Grace period jika baru saja tertangkap (mencegah double penalty)
                    local lastCaptured = self._recentlyCaptured[p.UserId]
                    if lastCaptured and (os.clock() - lastCaptured) < 12 then
                        continue
                    end

                    -- ATURAN 3: Jarak deteksi maksimal wajar (35 studs)
                    local dist = (cartPos - satpolPos).Magnitude
                    if dist <= SATPOL_DETECTION_RADIUS and dist < closestDist then
                        -- ATURAN 4: Sudut pandang (Cone of vision ~160 derajat)
                        local toCart = (cartPos - satpolPos).Unit
                        local dot = lookVector:Dot(toCart)
                        if dot >= 0.15 then
                            -- ATURAN 5: Raycast Line of Sight (halangan dinding ruko)
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = { satpolModel, cart, p.Character }

                            local hit = Workspace:Raycast(satpolPos, toCart * dist, rayParams)
                            if not hit or not hit.Instance or not hit.Instance.CanCollide then
                                closestDist = dist
                                selectedPlayer = p
                                selectedCart = cart
                            end
                        end
                    end
                end

                if selectedPlayer and selectedCart then
                    targetPlayer = selectedPlayer
                    targetCart = selectedCart
                    setSatpolBark(satpolModel, "BERHENTI! JANGAN KABUR!")
                    log:Info("Satpol %s mendeteksi gerobak %s pada jarak %.1f studs!", satpolModel.Name, selectedPlayer.Name, closestDist)
                end
            end
        end

        -- --------------------------------------------------------------------
        -- FASE 2: PENGEJARAN (CHASE)
        -- --------------------------------------------------------------------
        if targetPlayer and targetCart and targetCart.Parent then
            local cartPos = targetCart:GetPivot().Position
            local satpolPos = hrp.Position
            local dist = (cartPos - satpolPos).Magnitude

            -- ATURAN KEADILAN: Jika gerobak berhasil masuk Safe Zone, HENTIKAN PENGEJARAN!
            if self:IsPositionInSafeZone(cartPos) then
                setSatpolBark(satpolModel, "Cih, masuk Gang Aman! Jangan kejar ke dalam!")
                log:Info("Pengejaran dibatalkan: Gerobak %s telah aman di dalam Safe Zone.", targetPlayer.Name)
                targetPlayer = nil
                targetCart = nil
                task.wait(1.5)
                continue
            end

            -- Jika target berada di luar jarak jangkau (> 50 studs), batalkan pengejaran
            if dist > 50 then
                setSatpolBark(satpolModel, "Kehilangan jejak... Lanjut patroli.")
                targetPlayer = nil
                targetCart = nil
                task.wait(1.0)
                continue
            end

            -- ATURAN PENANGKAPAN (CAPTURE): Jarak <= 8 studs dan masih di luar Safe Zone
            if dist <= SATPOL_CAPTURE_DISTANCE then
                self:_capturePlayerCart(satpolModel, targetPlayer, targetCart)
                targetPlayer = nil
                targetCart = nil
                task.wait(2.0)
                continue
            else
                -- Bergerak mengejar target
                humanoid:MoveTo(cartPos)
                setSatpolBark(satpolModel, "SERAHKAN GEROBAK! JANGAN LARI!")
                task.wait(0.35)
                continue
            end
        end

        -- --------------------------------------------------------------------
        -- FASE 3: PATROLI RUTIN JALAN UTAMA (PATROL)
        -- --------------------------------------------------------------------
        local targetWaypoint = PATROL_WAYPOINTS[currentWpIndex]
        humanoid:MoveTo(targetWaypoint)
        setSatpolBark(satpolModel, "Patroli Ketertiban Jalan...")

        -- Bounded wait dengan pengecekan interupsi berkala (0.3s)
        local startWait = os.clock()
        while (hrp.Position - targetWaypoint).Magnitude > 4 and (os.clock() - startWait) < 6 do
            if self._currentRaidState ~= "Active" or not satpolModel.Parent then break end

            -- Cek apakah ada target yang melintas saat berjalan patroli
            local cartService = self:_getService("CartService")
            if not targetPlayer and cartService then
                local allCarts = cartService:GetAllActiveCarts()
                for _, cartData in allCarts do
                    local p = cartData.Player
                    local cart = cartData.Cart
                    local cPos = cartData.Position
                    if not self:IsPositionInSafeZone(cPos) and (cPos - hrp.Position).Magnitude <= SATPOL_DETECTION_RADIUS then
                        targetPlayer = p
                        targetCart = cart
                        break
                    end
                end
                if targetPlayer then break end
            end

            task.wait(0.3)
        end

        -- Pindah ke waypoint berikutnya secara bolak-balik (ping-pong)
        currentWpIndex = (currentWpIndex % #PATROL_WAYPOINTS) + 1
        task.wait(0.5)
    end
end

-- ============================================================================
-- PENANGKAPAN & PENALTI SATPOL PP (CAPTURE & PENALTY)
-- ============================================================================

function SatpolService:_capturePlayerCart(satpolModel: Model, player: Player, cart: Model)
    local userId = player.UserId
    self._recentlyCaptured[userId] = os.clock()

    log:Warn("PENANGKAPAN: Satpol %s berhasil menyita gerobak milik %s!", satpolModel.Name, player.Name)
    setSatpolBark(satpolModel, "TERTANGKAP! Gerobak liar disita & kas didenda 25%!")

    -- 1. Penalti Sitaan Uang Kas (25% standar, atau 12% dengan Rangka Anti-Razia)
    local penaltyAmount = 0
    local ecoService = self:_getService("EconomyService")
    if ecoService and ecoService.PenalizeCarriedCash then
        local penaltyPct = SATPOL_PENALTY_PERCENT
        if ecoService.HasUpgrade and ecoService:HasUpgrade(player, "rangka_anti_razia") then
            penaltyPct = 0.12
        end
        penaltyAmount = ecoService:PenalizeCarriedCash(player, penaltyPct)
    end

    -- 2. Sita seluruh gorengan matang di etalase gerobak
    local invService = self:_getService("InventoryService")
    if invService and invService.ClearCookedFood then
        invService:ClearCookedFood(player)
    end

    -- 3. Pulangkan gerobak dan pemain kembali ke plot masing-masing
    local cartService = self:_getService("CartService")
    if cartService and cartService.ReturnCartToPlot then
        cartService:ReturnCartToPlot(player)
    end

    -- 4. Kirim notifikasi tertangkap ke client untuk efek komedi / dazed HUD vignette
    local dataService = self:_getService("DataService")
    if dataService and dataService.RecordRaidStat then
        dataService:RecordRaidStat(player, true)
    end
    NetworkBridge.FireClient(player, Remotes.Events.PlayerCapturedBySatpol, penaltyAmount)

    log:Info("Proses eksekusi penalti penangkapan %s tuntas. Kas disita: Rp %d", player.Name, penaltyAmount)
end

-- ============================================================================
-- PENJADWAL RAZIA OTOMATIS (SCHEDULER LOOP)
-- ============================================================================

function SatpolService:_runRaidScheduler()
    while self._raidLoopActive do
        -- 1. Periode Tenang (Idle / Cooldown)
        self._currentRaidState = "Idle"
        local cooldown = RAID_INTERVAL
        log:Info("Jadwal razia: Periode tenang dimulai (%d detik hingga razia berikutnya).", cooldown)

        local elapsed = 0
        while elapsed < cooldown and self._raidLoopActive do
            task.wait(1)
            elapsed += 1
            if self._currentRaidState ~= "Idle" then
                -- Interupsi manual (misalnya ForceRaidEvent)
                break
            end
        end

        if not self._raidLoopActive then break end

        -- 2. Periode Peringatan 15 Detik (Kentongan & Sirine)
        if self._currentRaidState == "Idle" then
            self:StartRaidWarning(RAID_WARNING_DURATION)
            local warnElapsed = 0
            while warnElapsed < RAID_WARNING_DURATION and self._currentRaidState == "Warning" do
                task.wait(1)
                warnElapsed += 1
            end
        end

        -- 3. Periode Razia Aktif 45 Detik (Pasukan Satpol Berpatroli)
        if self._currentRaidState == "Warning" then
            self:StartActiveRaid(RAID_ACTIVE_DURATION)
            local activeElapsed = 0
            while activeElapsed < RAID_ACTIVE_DURATION and self._currentRaidState == "Active" do
                task.wait(1)
                activeElapsed += 1
            end
        end

        -- 4. Akhiri Razia
        if self._currentRaidState == "Active" then
            self:EndRaid()
        end
    end
end

return SatpolService