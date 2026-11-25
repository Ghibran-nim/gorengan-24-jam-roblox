--!strict
--[[
    EventService.luau
    Layanan otoritatif server untuk penjadwalan, orkestrasi, dan pembersihan Random Events:
    1. Hujan Deras Tropis (hujan_deras)
    2. Food Vlogger Viral (food_vlogger)
    3. Pelanggan Sultan Misterius (pelanggan_misterius)
    4. Aksi Copet Jalanan (copet — Spawn -> Approach -> StealAttempt -> Escape)
    5. Preman Palak Lapak (preman — Spawn -> Approach -> Threaten -> Retreat)
    6. Razia Satpol PP Mendadak (razia_satpol — Terkoordinasi dengan SatpolService)
    7. Malam Jumat Pasar Malam (pasar_malam_hantu — Event khusus malam)

    Menjamin maksimal 2 event bersamaan, cooldown terukur, tidak tumpang tindih ID,
    dan pembersihan total koneksi/NPC saat berhenti.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local EventsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EventsConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type WorldEventDefinition = EventsConfig.WorldEventDefinition
type ActiveWorldEvent = GameplayTypes.ActiveWorldEvent

local log = Logger.new("EventService")

type InternalEventState = {
    Token: number,
    Definition: WorldEventDefinition,
    StartTime: number,
    Duration: number,
    Active: boolean,
    Connections: { RBXScriptConnection },
    SpawnedInstances: { Instance },
    CleanupCallbacks: { () -> () },
}

local EventService = {
    Name = "EventService",
    _activeEvents = {} :: { [string]: InternalEventState },
    _cooldownsUntil = {} :: { [string]: number },
    _eventTokenCounter = 0,
    _rainActive = false,
    _nightMarketActive = false,
    _schedulerActive = false,
    _phaseListenerBound = false,
    _npcFolder = nil :: Folder?,
    _npcEventBindings = {} :: { [Model]: { EventId: string, Type: string, TargetPlayer: Player?, OnHitByBurnt: ((Player) -> ())? } },
    _services = {} :: { [string]: any },
}

function EventService:_getNpcFolder(): Folder
    if self._npcFolder and self._npcFolder.Parent then
        return self._npcFolder
    end
    local existing = Workspace:FindFirstChild("EventNPCs")
    if existing and existing:IsA("Folder") then
        self._npcFolder = existing
        return existing
    end
    local folder = Instance.new("Folder")
    folder.Name = "EventNPCs"
    folder.Parent = Workspace
    self._npcFolder = folder
    return folder
end

function EventService:_ensureNightPhaseListener()
    if self._phaseListenerBound then
        return
    end
    local timeService = self:_getService("TimeService")
    if timeService and timeService.OnPhaseChanged then
        self._phaseListenerBound = true
        timeService:OnPhaseChanged(function(newPhase)
            if newPhase ~= "Malam" and self:IsEventActive("pasar_malam_hantu") then
                log:Info("Fajar menyingsing: mengakhiri event khusus malam Pasar Malam.")
                self:StopEvent("pasar_malam_hantu")
            end
        end)
    end
end

function EventService:_getService(serviceName: string): any
    if not self._services[serviceName] and script and script.Parent then
        local mod = script.Parent:FindFirstChild(serviceName)
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

local function createEventNpcRig(name: string, shirtColor: Color3, pantsColor: Color3, skinColor: Color3, titleText: string, spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = name

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.CFrame = CFrame.new(spawnPos)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = model
    model.PrimaryPart = hrp

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = CFrame.new(spawnPos)
    torso.Color = shirtColor
    torso.Material = Enum.Material.SmoothPlastic
    torso.CanCollide = false
    torso.Anchored = false
    torso.Parent = model
    local wt = Instance.new("WeldConstraint"); wt.Part0 = hrp; wt.Part1 = torso; wt.Parent = hrp

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.5, 0))
    head.Color = skinColor
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.Anchored = false
    head.Parent = model
    local wh = Instance.new("WeldConstraint"); wh.Part0 = torso; wh.Part1 = head; wh.Parent = torso

    for _, offset in { -0.5, 0.5 } do
        local leg = Instance.new("Part")
        leg.Name = "Leg"
        leg.Size = Vector3.new(0.9, 2, 0.9)
        leg.CFrame = CFrame.new(spawnPos + Vector3.new(offset, -1.8, 0))
        leg.Color = pantsColor
        leg.Material = Enum.Material.SmoothPlastic
        leg.CanCollide = false
        leg.Anchored = false
        leg.Parent = model
        local wl = Instance.new("WeldConstraint"); wl.Part0 = torso; wl.Part1 = leg; wl.Parent = torso
    end

    local hum = Instance.new("Humanoid")
    hum.Name = "Humanoid"
    hum.WalkSpeed = 13.5
    hum.MaxHealth = 100
    hum.Health = 100
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.Parent = model

    local bb = Instance.new("BillboardGui")
    bb.Name = "EventNpcBillboard"
    bb.Size = UDim2.new(0, 220, 0, 74)
    bb.StudsOffset = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Adornee = head
    bb.Parent = head

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    bg.BackgroundTransparency = 0.15
    bg.Parent = bb
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = bg

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLabel"
    titleLbl.Size = UDim2.new(1, -8, 0.45, 0)
    titleLbl.Position = UDim2.new(0, 4, 0, 2)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.FredokaOne
    titleLbl.TextScaled = true
    titleLbl.TextColor3 = Color3.fromRGB(255, 195, 60)
    titleLbl.Text = titleText
    titleLbl.Parent = bg

    local barkLbl = Instance.new("TextLabel")
    barkLbl.Name = "BarkLabel"
    barkLbl.Size = UDim2.new(1, -8, 0.55, 0)
    barkLbl.Position = UDim2.new(0, 4, 0.45, 0)
    barkLbl.BackgroundTransparency = 1
    barkLbl.Font = Enum.Font.GothamBold
    barkLbl.TextScaled = true
    barkLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    barkLbl.Text = "..."
    barkLbl.Parent = bg

    return model
end

local function setNpcBark(model: Model, text: string)
    local head = model:FindFirstChild("Head")
    local bb = if head then head:FindFirstChild("EventNpcBillboard") :: BillboardGui? else nil
    local bg = if bb then bb:FindFirstChildOfClass("Frame") else nil
    local lbl = if bg then bg:FindFirstChild("BarkLabel") :: TextLabel? else nil
    if lbl then
        lbl.Text = text
    end
end

function EventService:Init()
    log:Info("Menginisialisasi EventService...")

    self:_getNpcFolder()

    -- Permintaan status waktu & daftar event aktif oleh client
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetWorldState, function(_player: Player)
        local timeService = self:_getService("TimeService")
        local timeState = if timeService and timeService.GetTimeState then timeService:GetTimeState() else nil
        return {
            Success = true,
            TimeState = timeState,
            ActiveEvents = self:GetActiveEventsList(),
        }
    end)

    -- Remote untuk pemicuan / penghentian event (Testing & Admin)
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestForceWorldEvent, function(_player: Player, action: any, eventId: any)
        if typeof(action) ~= "string" then
            return { Success = false, Error = "Aksi tidak valid!" }
        end
        if action == "StopAll" then
            self:StopAllEvents()
            return { Success = true }
        elseif action == "Stop" and typeof(eventId) == "string" then
            local stopped = self:StopEvent(eventId)
            return { Success = stopped }
        elseif action == "Start" and typeof(eventId) == "string" then
            return self:StartEvent(eventId, true)
        end
        return { Success = false, Error = "Perintah event tidak dikenali!" }
    end)
end

function EventService:Start()
    self:_getService("TimeService")
    self:_getService("CustomerService")
    self:_getService("EconomyService")
    self:_getService("SatpolService")
    self:_getService("CartService")
    self:_getService("ProgressionService")

    -- Jika waktu berubah dari Malam ke Pagi, hentikan event khusus malam
    self:_ensureNightPhaseListener()

    self._schedulerActive = true
    task.spawn(function()
        self:_runSchedulerLoop()
    end)
    log:Info("EventService aktif dan siap mengelola 7 random events.")
end

function EventService:GetActiveEventCount(): number
    local count = 0
    for _ in pairs(self._activeEvents) do
        count += 1
    end
    return count
end

function EventService:GetActiveEventsList(): { ActiveWorldEvent }
    local list: { ActiveWorldEvent } = {}
    local now = os.clock()
    for id, state in pairs(self._activeEvents) do
        local rem = math.max(1, math.ceil((state.StartTime + state.Duration) - now))
        table.insert(list, {
            EventId = id,
            Name = state.Definition.Name,
            Icon = state.Definition.Icon,
            StartTime = state.StartTime,
            Duration = state.Duration,
            RemainingSeconds = rem,
            Description = state.Definition.Description,
            BannerColor = state.Definition.BannerColor,
        })
    end
    return list
end

function EventService:IsEventActive(eventId: string): boolean
    return self._activeEvents[eventId] ~= nil
end

function EventService:IsRaining(): boolean
    return self._rainActive
end

function EventService:IsNightMarketActive(): boolean
    return self._nightMarketActive
end

function EventService:_runSchedulerLoop()
    while self._schedulerActive do
        local waitSecs = math.random(EventsConfig.SchedulerMinIntervalSeconds, EventsConfig.SchedulerMaxIntervalSeconds)
        task.wait(waitSecs)
        if not self._schedulerActive then break end

        if #Players:GetPlayers() == 0 then
            continue
        end

        if self:GetActiveEventCount() >= EventsConfig.MaxConcurrentEvents then
            continue
        end

        local timeService = self:_getService("TimeService")
        local currentPhase = if timeService then timeService:GetCurrentPhaseId() else "Siang"
        local now = os.clock()

        local candidates: { WorldEventDefinition } = {}
        local totalWeight = 0

        for _, def in ipairs(EventsConfig.GetAllEvents()) do
            if not self:IsEventActive(def.Id) and now >= (self._cooldownsUntil[def.Id] or 0) then
                if table.find(def.AllowedPhases, currentPhase) then
                    -- Jangan memicu razia lewat scheduler jika Satpol sedang aktif
                    if def.Id == "razia_satpol" then
                        local satpol = self:_getService("SatpolService")
                        if satpol and satpol:GetRaidState() ~= "Idle" then
                            continue
                        end
                    end
                    table.insert(candidates, def)
                    totalWeight += def.Weight
                end
            end
        end

        if totalWeight > 0 and #candidates > 0 then
            local roll = math.random(1, totalWeight)
            local acc = 0
            for _, def in ipairs(candidates) do
                acc += def.Weight
                if roll <= acc then
                    self:StartEvent(def.Id, false)
                    break
                end
            end
        end
    end
end

function EventService:StartEvent(eventId: string, ignoreCooldownAndPhase: boolean?): { Success: boolean, Error: string? }
    local def = EventsConfig.GetEvent(eventId)
    if not def then
        return { Success = false, Error = "Event '" .. tostring(eventId) .. "' tidak ditemukan!" }
    end

    if self:IsEventActive(eventId) then
        return { Success = false, Error = "Event '" .. def.Name .. "' sedang berlangsung!" }
    end

    if self:GetActiveEventCount() >= EventsConfig.MaxConcurrentEvents then
        return { Success = false, Error = "Batas maksimal event bersamaan (" .. tostring(EventsConfig.MaxConcurrentEvents) .. ") telah tercapai!" }
    end

    local now = os.clock()
    if not ignoreCooldownAndPhase then
        if now < (self._cooldownsUntil[eventId] or 0) then
            return { Success = false, Error = "Event sedang dalam cooldown!" }
        end
        local timeService = self:_getService("TimeService")
        local phase = if timeService then timeService:GetCurrentPhaseId() else "Siang"
        if not table.find(def.AllowedPhases, phase) then
            return { Success = false, Error = "Event tidak sesuai fase waktu saat ini (" .. phase .. ")!" }
        end
    end

    self._eventTokenCounter += 1
    local token = self._eventTokenCounter

    local state: InternalEventState = {
        Token = token,
        Definition = def,
        StartTime = now,
        Duration = def.Duration,
        Active = true,
        Connections = {},
        SpawnedInstances = {},
        CleanupCallbacks = {},
    }

    self._activeEvents[eventId] = state
    self._cooldownsUntil[eventId] = now + def.Duration + def.Cooldown
    self:_ensureNightPhaseListener()

    log:Info("EVENT DIMULAI: %s %s (Durasi: %ds | Token #%d)", def.Icon, def.Name, def.Duration, token)

    NetworkBridge.FireAllClients(Remotes.Events.WorldEventStarted, {
        EventId = def.Id,
        Name = def.Name,
        Icon = def.Icon,
        Duration = def.Duration,
        Description = def.Description,
        RewardText = def.RewardText,
        ConsequenceText = def.ConsequenceText,
        BannerColor = def.BannerColor,
    })

    -- Jalankan handler mekanik event spesifik
    if eventId == "hujan_deras" then
        self:_startRainEvent(state)
    elseif eventId == "food_vlogger" then
        self:_startSpecialCustomerEvent(state, "food_vlogger")
    elseif eventId == "pelanggan_misterius" then
        self:_startSpecialCustomerEvent(state, "misterius")
    elseif eventId == "copet" then
        self:_startCopetEvent(state)
    elseif eventId == "preman" then
        self:_startPremanEvent(state)
    elseif eventId == "razia_satpol" then
        self:_startSatpolEvent(state)
    elseif eventId == "pasar_malam_hantu" then
        self:_startNightMarketEvent(state)
    end

    -- Jadwalkan penghentian otomatis setelah durasi selesai
    task.delay(def.Duration, function()
        local current = self._activeEvents[eventId]
        if current and current.Token == token then
            self:StopEvent(eventId)
        end
    end)

    return { Success = true }
end

function EventService:StopEvent(eventId: string): boolean
    local state = self._activeEvents[eventId]
    if not state then
        return false
    end

    state.Active = false
    self._activeEvents[eventId] = nil

    -- Putus seluruh koneksi event & bersihkan instans NPC/objek
    for _, conn in ipairs(state.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, inst in ipairs(state.SpawnedInstances) do
        if inst:IsA("Model") then
            self._npcEventBindings[inst] = nil
        end
        if inst and inst.Parent then
            inst:Destroy()
        end
    end
    for _, cb in ipairs(state.CleanupCallbacks) do
        pcall(cb)
    end

    log:Info("EVENT BERAKHIR & DIBERSIHKAN: %s (%s)", state.Definition.Name, eventId)
    NetworkBridge.FireAllClients(Remotes.Events.WorldEventEnded, eventId, state.Definition.Name)
    return true
end

function EventService:StopAllEvents()
    local ids = {}
    for id in pairs(self._activeEvents) do
        table.insert(ids, id)
    end
    for _, id in ipairs(ids) do
        self:StopEvent(id)
    end
end

-- ============================================================================
-- IMPLEMENTASI MEKANIK 7 RANDOM EVENTS
-- ============================================================================

function EventService:_startRainEvent(state: InternalEventState)
    self._rainActive = true

    local cartService = self:_getService("CartService")
    local satpolService = self:_getService("SatpolService")

    table.insert(state.CleanupCallbacks, function()
        self._rainActive = false
        for _, p in Players:GetPlayers() do
            local char = p.Character
            local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
            local pushing = if cartService and cartService.IsPushing then cartService:IsPushing(p) else false
            if hum and not pushing then
                hum.WalkSpeed = GameConfig.NormalWalkSpeed
            end
        end
    end)

    -- Perlambatan jalan ringan di jalan basah di luar Safe Zone
    task.spawn(function()
        while state.Active do
            for _, p in Players:GetPlayers() do
                local char = p.Character
                local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
                local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
                local pushing = if cartService and cartService.IsPushing then cartService:IsPushing(p) else false
                if hrp and hum and not pushing then
                    local inSafe = if satpolService and satpolService.IsPositionInSafeZone then satpolService:IsPositionInSafeZone(hrp.Position) else false
                    hum.WalkSpeed = if inSafe then GameConfig.NormalWalkSpeed else 14
                end
            end
            task.wait(1.0)
        end
    end)
end

function EventService:_startSpecialCustomerEvent(state: InternalEventState, archetypeId: string)
    local custService = self:_getService("CustomerService")
    if not custService or not custService.SpawnSpecialCustomer then return end

    local spawnedIds: { string } = {}
    local gameService = self:_getService("GameService")

    local players = Players:GetPlayers()
    if #players > 0 then
        local plotId = (if gameService then gameService:GetPlayerPlot(players[1]) else nil) or 1
        local custId = custService:SpawnSpecialCustomer(archetypeId, plotId)
        if custId then
            table.insert(spawnedIds, custId)
        end
    else
        local custId = custService:SpawnSpecialCustomer(archetypeId, 1)
        if custId then
            table.insert(spawnedIds, custId)
        end
    end

    table.insert(state.CleanupCallbacks, function()
        for _, cid in ipairs(spawnedIds) do
            if custService._activeOrders and custService._activeOrders[cid] then
                local ord = custService._activeOrders[cid]
                if ord.State ~= "Served" then
                    custService:_despawnCustomer(cid, ord.PlotId)
                end
            end
        end
    end)
end

function EventService:_startCopetEvent(state: InternalEventState)
    local ecoService = self:_getService("EconomyService")
    local satpolService = self:_getService("SatpolService")
    local progService = self:_getService("ProgressionService")

    -- Cari target pemain yang membawa uang kas
    local targetPlayer: Player? = nil
    for _, p in Players:GetPlayers() do
        local wallet = if ecoService then ecoService:GetWallet(p) else nil
        if wallet and wallet.CarriedCash >= 5000 then
            targetPlayer = p
            break
        end
    end
    if not targetPlayer then
        targetPlayer = Players:GetPlayers()[1]
    end

    local spawnPos = Vector3.new(-35, 3.5, 4)
    local copetModel = createEventNpcRig(
        "Copet_" .. tostring(state.Token),
        Color3.fromRGB(32, 32, 38),
        Color3.fromRGB(25, 25, 28),
        Color3.fromRGB(210, 170, 130),
        "🥷 COPET JALANAN!",
        spawnPos
    )
    copetModel.Parent = self:_getNpcFolder()
    table.insert(state.SpawnedInstances, copetModel)
    setNpcBark(copetModel, "Hehe... dompet siapa tuh?!")

    local resolved = false
    local function handleRepelled(heroPlayer: Player)
        if resolved or not state.Active then return end
        resolved = true
        setNpcBark(copetModel, "AMPUN BANG! AMPUN! *kabur*")
        if ecoService then
            ecoService:AddCarriedCash(heroPlayer, 3000, "Hadiah Usir Copet")
        end
        if progService then
            progService:AddXP(heroPlayer, 15, "Usir Copet Jalanan")
        end
        NetworkBridge.FireClient(heroPlayer, Remotes.Events.NotificationFired, "🥷 Berhasil mengusir Copet! Hadiah +Rp 3.000 & +15 XP!", "Success")
        task.delay(1.0, function()
            if state.Active then self:StopEvent(state.Definition.Id) end
        end)
    end

    self._npcEventBindings[copetModel] = {
        EventId = state.Definition.Id,
        Type = "Copet",
        TargetPlayer = targetPlayer,
        OnHitByBurnt = handleRepelled,
    }

    local hrp = copetModel.PrimaryPart :: BasePart
    local shooPrompt = Instance.new("ProximityPrompt")
    shooPrompt.Name = "ShooCopetPrompt"
    shooPrompt.ActionText = "Usir Copet!"
    shooPrompt.ObjectText = "Copet Jalanan"
    shooPrompt.HoldDuration = 0.2
    shooPrompt.MaxActivationDistance = 10
    shooPrompt.RequiresLineOfSight = false
    shooPrompt.Parent = hrp

    table.insert(state.Connections, shooPrompt.Triggered:Connect(function(triggerPlayer: Player)
        handleRepelled(triggerPlayer)
    end))

    -- Telegraph warning 2.5 detik sebelum mengejar
    if targetPlayer then
        NetworkBridge.FireClient(targetPlayer, Remotes.Events.NotificationFired, "🥷 AWAS COPET MENGINCAR KASMU! Lari ke Gang Aman atau usir/lempar gosong!", "Warning")
    end

    task.spawn(function()
        task.wait(2.5)
        local hum = copetModel:FindFirstChildOfClass("Humanoid")
        while state.Active and not resolved and copetModel.Parent and hum do
            if targetPlayer and targetPlayer.Character and targetPlayer.Character.PrimaryPart then
                local tPos = targetPlayer.Character.PrimaryPart.Position
                if satpolService and satpolService:IsPositionInSafeZone(tPos) then
                    setNpcBark(copetModel, "Yah dia masuk Gang Aman... Cabut ah!")
                    resolved = true
                    task.delay(1.2, function()
                        if state.Active then self:StopEvent(state.Definition.Id) end
                    end)
                    break
                end

                hum:MoveTo(tPos)
                setNpcBark(copetModel, "Sini dompet lo!")
                if (hrp.Position - tPos).Magnitude <= 5.5 then
                    resolved = true
                    local wallet = if ecoService then ecoService:GetWallet(targetPlayer) else nil
                    local stealAmt = if wallet then math.min(15000, math.floor(wallet.CarriedCash * 0.10)) else 0
                    if stealAmt > 0 and ecoService then
                        ecoService:DeductCarriedCash(targetPlayer, stealAmt, "Dicopet di Jalan")
                        NetworkBridge.FireClient(targetPlayer, Remotes.Events.NotificationFired, string.format("🥷 DOMPET DICOPET -Rp %d! (Tabungan ATM tetap aman!)", stealAmt), "Burnt")
                    end
                    setNpcBark(copetModel, "Hahaha lumayan buat ngopi! *kabur*")
                    task.delay(1.2, function()
                        if state.Active then self:StopEvent(state.Definition.Id) end
                    end)
                    break
                end
            end
            task.wait(0.4)
        end
    end)
end

function EventService:_startPremanEvent(state: InternalEventState)
    local ecoService = self:_getService("EconomyService")
    local progService = self:_getService("ProgressionService")
    local cartService = self:_getService("CartService")

    local targetPlayer = Players:GetPlayers()[1]
    local targetPos = Vector3.new(-100, 3.5, 22)
    if targetPlayer and cartService then
        local cPos = cartService:GetCartPosition(targetPlayer)
        if cPos then
            targetPos = cPos + Vector3.new(0, 0, -6)
        end
    end

    local premanModel = createEventNpcRig(
        "Preman_" .. tostring(state.Token),
        Color3.fromRGB(145, 35, 35),
        Color3.fromRGB(35, 35, 42),
        Color3.fromRGB(200, 155, 115),
        "💪 PREMAN PALAK LAPAK",
        targetPos + Vector3.new(12, 0, -8)
    )
    premanModel.Parent = self:_getNpcFolder()
    table.insert(state.SpawnedInstances, premanModel)
    setNpcBark(premanModel, "Bayar uang keamanan Rp 5.000 atau wajan gua tendang!")

    local resolved = false
    local function handleDefeat(heroPlayer: Player)
        if resolved or not state.Active then return end
        resolved = true
        setNpcBark(premanModel, "ADUH AMPUN BOS! GAK JADI PALAK! *kabur*")
        if progService then
            progService:AddXP(heroPlayer, 20, "Usir Preman Lapak")
        end
        if ecoService then
            local w = ecoService:GetWallet(heroPlayer)
            if w then w.Reputation += 5; ecoService:SyncWalletToClient(heroPlayer) end
        end
        NetworkBridge.FireClient(heroPlayer, Remotes.Events.NotificationFired, "💪 Preman kabur terbirit-birit! +20 XP & +5 Reputasi!", "Success")
        task.delay(1.0, function()
            if state.Active then self:StopEvent(state.Definition.Id) end
        end)
    end

    self._npcEventBindings[premanModel] = {
        EventId = state.Definition.Id,
        Type = "Preman",
        TargetPlayer = targetPlayer,
        OnHitByBurnt = handleDefeat,
    }

    local hrp = premanModel.PrimaryPart :: BasePart
    local payPrompt = Instance.new("ProximityPrompt")
    payPrompt.Name = "PayPremanPrompt"
    payPrompt.ActionText = "Bayar Keamanan (Rp 5.000)"
    payPrompt.ObjectText = "Preman Lapak"
    payPrompt.KeyboardKeyCode = Enum.KeyCode.E
    payPrompt.HoldDuration = 0.2
    payPrompt.MaxActivationDistance = 10
    payPrompt.RequiresLineOfSight = false
    payPrompt.Parent = hrp

    local shooPrompt = Instance.new("ProximityPrompt")
    shooPrompt.Name = "ShooPremanPrompt"
    shooPrompt.ActionText = "Usir Preman!"
    shooPrompt.ObjectText = "Preman Lapak"
    shooPrompt.KeyboardKeyCode = Enum.KeyCode.F
    shooPrompt.HoldDuration = 0.4
    shooPrompt.MaxActivationDistance = 10
    shooPrompt.RequiresLineOfSight = false
    shooPrompt.Parent = hrp

    table.insert(state.Connections, payPrompt.Triggered:Connect(function(p: Player)
        if resolved or not state.Active then return end
        if ecoService and ecoService:DeductCarriedCash(p, 5000, "Uang Keamanan Preman") then
            resolved = true
            setNpcBark(premanModel, "Nah gitu dong cakep! Aman bos!")
            NetworkBridge.FireClient(p, Remotes.Events.NotificationFired, "💸 Membayar Rp 5.000 — Preman pergi meninggalkan lapak.", "Warning")
            task.delay(1.2, function()
                if state.Active then self:StopEvent(state.Definition.Id) end
            end)
        else
            NetworkBridge.FireClient(p, Remotes.Events.NotificationFired, "⚠️ Kas tidak cukup Rp 5.000! Usir [F] atau lempar gorengan gosong!", "Warning")
        end
    end))

    table.insert(state.Connections, shooPrompt.Triggered:Connect(function(p: Player)
        handleDefeat(p)
    end))

    task.spawn(function()
        local hum = premanModel:FindFirstChildOfClass("Humanoid")
        if hum then hum:MoveTo(targetPos) end
        -- Batas waktu mengancam 12 detik sebelum memalak otomatis maks Rp 5.000 dan pergi
        local elapsed = 0
        while state.Active and not resolved and elapsed < 12 do
            task.wait(0.5)
            elapsed += 0.5
        end
        if state.Active and not resolved and targetPlayer and ecoService then
            resolved = true
            local w = ecoService:GetWallet(targetPlayer)
            local amt = if w then math.min(5000, w.CarriedCash) else 0
            if amt > 0 then
                ecoService:DeductCarriedCash(targetPlayer, amt, "Dipalak Preman")
                NetworkBridge.FireClient(targetPlayer, Remotes.Events.NotificationFired, string.format("💪 Preman merampas Rp %d dari laci kas! (ATM tetap aman)", amt), "Burnt")
            end
            setNpcBark(premanModel, "Segitu doang? Yaudah gua cabut!")
            task.delay(1.2, function()
                if state.Active then self:StopEvent(state.Definition.Id) end
            end)
        end
    end)
end

function EventService:_startSatpolEvent(state: InternalEventState)
    local satpol = self:_getService("SatpolService")
    if not satpol then return end

    table.insert(state.CleanupCallbacks, function()
        if satpol:GetRaidState() ~= "Idle" then
            satpol:EndRaid()
        end
    end)

    satpol:StartRaidWarning(GameConfig.RaidWarningDurationSeconds or 15)
    task.spawn(function()
        local warnDur = GameConfig.RaidWarningDurationSeconds or 15
        local t = 0
        while t < warnDur and state.Active do
            task.wait(1)
            t += 1
        end
        if state.Active then
            satpol:StartActiveRaid(GameConfig.RaidActiveDurationSeconds or 45)
        end
    end)
end

function EventService:_startNightMarketEvent(state: InternalEventState)
    self._nightMarketActive = true
    local custService = self:_getService("CustomerService")
    local spawnedId: string? = nil

    if custService and custService.SpawnSpecialCustomer then
        local gameService = self:_getService("GameService")
        local p = Players:GetPlayers()[1]
        local plotId = (if p and gameService then gameService:GetPlayerPlot(p) else nil) or 1
        spawnedId = custService:SpawnSpecialCustomer("hantu", plotId)
    end

    table.insert(state.CleanupCallbacks, function()
        self._nightMarketActive = false
        if spawnedId and custService and custService._activeOrders and custService._activeOrders[spawnedId] then
            local ord = custService._activeOrders[spawnedId]
            if ord.State ~= "Served" then
                custService:_despawnCustomer(spawnedId, ord.PlotId)
            end
        end
    end)
end

function EventService:OnNpcHitByBurntFood(hitInstance: Instance, thrower: Player): boolean
    local current: Instance? = hitInstance
    while current and current ~= Workspace do
        if current:IsA("Model") then
            local binding = self._npcEventBindings[current]
            if binding and binding.OnHitByBurnt then
                binding.OnHitByBurnt(thrower)
                return true
            end
        end
        current = current.Parent
    end
    return false
end

return EventService