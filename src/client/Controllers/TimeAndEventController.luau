--!strict
--[[
    TimeAndEventController.luau
    Mengelola antarmuka waktu siklus 24 jam dan umpan balik visual/audio Random Events di client:
    - Panel jam & fase waktu (Pagi, Siang, Sore, Malam) sinkron dengan server
    - Daftar pil event aktif (maksimal 2 event bersamaan) dengan hitung mundur waktu nyata
    - Efek hujan deras (partikel hujan mengikuti kamera + kabut lembut + suara hujan terukur)
    - Pembersihan total efek partikel, suara, dan koneksi saat event berakhir
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local TimeScheduleConfig = require(Shared:WaitForChild("Config"):WaitForChild("TimeScheduleConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type TimeState = GameplayTypes.TimeState

local log = Logger.new("TimeAndEventController")

local PHASE_ICONS: { [string]: string } = {
    Pagi = "🌅",
    Siang = "☀️",
    Sore = "🌇",
    Malam = "🌙",
}

local TimeAndEventController = {
    Name = "TimeAndEventController",
    _timeState = {
        ClockTime = 7.0,
        Hour = 7,
        Minute = 0,
        PhaseId = "Pagi",
        PhaseName = "Pagi Cerah",
        DayCount = 1,
    } :: TimeState,
    _activeEvents = {} :: { [string]: { Name: string, Icon: string, EndsAt: number, Color: Color3 } },
    _gui = nil :: ScreenGui?,
    _clockLabel = nil :: TextLabel?,
    _eventsContainer = nil :: Frame?,
    _rainPart = nil :: Part?,
    _rainSound = nil :: Sound?,
    _rainConn = nil :: RBXScriptConnection?,
    _defaultFogEnd = 100000,
    _defaultFogColor = Color3.fromRGB(192, 192, 192),
}

function TimeAndEventController:Init()
    log:Info("Menginisialisasi TimeAndEventController...")

    self._defaultFogEnd = Lighting.FogEnd
    self._defaultFogColor = Lighting.FogColor

    NetworkBridge.OnClientEvent(Remotes.Events.TimeStateUpdated, function(state: any)
        if typeof(state) == "table" then
            self._timeState = state :: TimeState
            self:_updateClockLabel()
        end
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.WorldEventStarted, function(payload: any)
        if typeof(payload) == "table" and typeof(payload.EventId) == "string" then
            self:HandleEventStarted(payload)
        end
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.WorldEventEnded, function(eventId: string, eventName: string?)
        self:HandleEventEnded(eventId, eventName)
    end)

    self:_createWorldHUD()

    -- Perbarui timer event aktif setiap 0.5 detik
    task.spawn(function()
        while true do
            task.wait(0.5)
            self:_refreshEventPills()
        end
    end)
end

function TimeAndEventController:Start()
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetWorldState)
        if res and res.Success then
            if typeof(res.TimeState) == "table" then
                self._timeState = res.TimeState
                self:_updateClockLabel()
            end
            if typeof(res.ActiveEvents) == "table" then
                for _, ev in ipairs(res.ActiveEvents) do
                    self:HandleEventStarted({
                        EventId = ev.EventId,
                        Name = ev.Name,
                        Icon = ev.Icon or "⚡",
                        Duration = ev.RemainingSeconds or ev.Duration,
                        Description = ev.Description,
                        BannerColor = ev.BannerColor or Color3.fromRGB(70, 120, 200),
                    })
                end
            end
        end
    end)
    log:Info("TimeAndEventController aktif.")
end

function TimeAndEventController:_notify(message: string, alertType: string)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, alertType)
    end
end

function TimeAndEventController:_createWorldHUD()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("WorldTimeHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WorldTimeHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 1. Clock & Day Phase Pill (Kiri atas tepat di bawah InventoryHUD, bebas overlap)
    local clockFrame = Instance.new("Frame")
    clockFrame.Name = "ClockPanel"
    clockFrame.Size = UDim2.new(0, 260, 0, 34)
    clockFrame.Position = UDim2.new(0, 16, 0, 152)
    clockFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
    clockFrame.BackgroundTransparency = 0.2
    clockFrame.BorderSizePixel = 0
    clockFrame.Parent = screenGui

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = clockFrame

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Color3.fromRGB(75, 85, 105)
    cStroke.Thickness = 1.2
    cStroke.Parent = clockFrame

    local clockLbl = Instance.new("TextLabel")
    clockLbl.Name = "ClockLabel"
    clockLbl.Size = UDim2.new(1, -16, 1, 0)
    clockLbl.Position = UDim2.new(0, 8, 0, 0)
    clockLbl.BackgroundTransparency = 1
    clockLbl.TextColor3 = Color3.fromRGB(240, 242, 250)
    clockLbl.Font = Enum.Font.FredokaOne
    clockLbl.TextSize = 13
    clockLbl.TextXAlignment = Enum.TextXAlignment.Left
    clockLbl.Text = "🌅 Hari 1 • 07:00 (Pagi Cerah)"
    clockLbl.Parent = clockFrame

    -- 2. Active Events Container (Di bawah ClockPanel)
    local evContainer = Instance.new("Frame")
    evContainer.Name = "ActiveEventsContainer"
    evContainer.Size = UDim2.new(0, 260, 0, 76)
    evContainer.Position = UDim2.new(0, 16, 0, 192)
    evContainer.BackgroundTransparency = 1
    evContainer.Parent = screenGui

    local evLayout = Instance.new("UIListLayout")
    evLayout.Padding = UDim.new(0, 6)
    evLayout.Parent = evContainer

    self._gui = screenGui
    self._clockLabel = clockLbl
    self._eventsContainer = evContainer
    screenGui.Parent = playerGui
    self:_updateClockLabel()
end

function TimeAndEventController:_updateClockLabel()
    if not self._clockLabel then return end
    local s = self._timeState
    local icon = PHASE_ICONS[s.PhaseId] or "🕒"
    self._clockLabel.Text = string.format("%s Hari %d • %02d:%02d (%s)", icon, s.DayCount or 1, s.Hour or 7, s.Minute or 0, s.PhaseName or "Pagi")
end

function TimeAndEventController:_refreshEventPills()
    if not self._eventsContainer then return end
    for _, child in self._eventsContainer:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local now = os.clock()
    for eventId, info in pairs(self._activeEvents) do
        local rem = math.max(0, math.ceil(info.EndsAt - now))
        local pill = Instance.new("Frame")
        pill.Name = "EventPill_" .. eventId
        pill.Size = UDim2.new(1, 0, 0, 30)
        pill.BackgroundColor3 = info.Color
        pill.BackgroundTransparency = 0.15
        pill.BorderSizePixel = 0
        pill.Parent = self._eventsContainer

        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(0, 8)
        pc.Parent = pill

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -14, 1, 0)
        lbl.Position = UDim2.new(0, 7, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.Font = Enum.Font.FredokaOne
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.format("%s %s (%ds)", info.Icon, info.Name, rem)
        lbl.Parent = pill
    end
end

function TimeAndEventController:HandleEventStarted(payload: any)
    local eventId = payload.EventId :: string
    local name = payload.Name or eventId
    local icon = payload.Icon or "⚡"
    local duration = payload.Duration or 30
    local color = payload.BannerColor or Color3.fromRGB(70, 120, 200)

    self._activeEvents[eventId] = {
        Name = name,
        Icon = icon,
        EndsAt = os.clock() + duration,
        Color = color,
    }
    self:_refreshEventPills()

    self:_notify(string.format("%s %s! %s", icon, name:upper(), tostring(payload.RewardText or payload.Description or "")), "Warning")

    if eventId == "hujan_deras" then
        self:_startRainVFX()
    elseif eventId == "pasar_malam_hantu" then
        Lighting.ColorShift_Bottom = Color3.fromRGB(90, 60, 145)
    end
end

function TimeAndEventController:HandleEventEnded(eventId: string, eventName: string?)
    self._activeEvents[eventId] = nil
    self:_refreshEventPills()

    if eventId == "hujan_deras" then
        self:_stopRainVFX()
    elseif eventId == "pasar_malam_hantu" then
        Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
    end

    if eventName then
        log:Info("Event berakhir di client: %s", eventName)
    end
end

function TimeAndEventController:_startRainVFX()
    self:_stopRainVFX()

    -- Kabut hujan lembut (tetap mudah dibaca di mobile)
    Lighting.FogColor = Color3.fromRGB(115, 130, 150)
    Lighting.FogEnd = 360

    -- Partikel hujan di atas kamera pemain
    local rainPart = Instance.new("Part")
    rainPart.Name = "ClientRainVFX"
    rainPart.Size = Vector3.new(60, 1, 60)
    rainPart.Transparency = 1
    rainPart.Anchored = true
    rainPart.CanCollide = false
    rainPart.Parent = Workspace

    local audioMod = script.Parent:FindFirstChild("AudioVFXController")
    local audioCtrl = if audioMod then require(audioMod) else nil
    local lowFx = if audioCtrl and (audioCtrl :: any).IsLowFxMode then (audioCtrl :: any):IsLowFxMode() else false
    local ambMult = if audioCtrl and (audioCtrl :: any).GetAmbienceMultiplier then (audioCtrl :: any):GetAmbienceMultiplier() else 1.0

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "RainDrops"
    emitter.Color = ColorSequence.new(Color3.fromRGB(185, 215, 255))
    emitter.Size = NumberSequence.new(0.18)
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.7) })
    emitter.Rate = if lowFx then 45 else 110
    emitter.Lifetime = NumberRange.new(0.9, 1.3)
    emitter.Speed = NumberRange.new(38, 48)
    emitter.EmissionDirection = Enum.NormalId.Bottom
    emitter.Parent = rainPart

    local rainSound = Instance.new("Sound")
    rainSound.Name = "ClientRainAmbience"
    rainSound.SoundId = "rbxasset://sounds/action_swim.mp3"
    rainSound.Volume = 0.22 * ambMult
    rainSound.PlaybackSpeed = 0.75
    rainSound.Looped = true
    rainSound.Parent = SoundService
    rainSound:Play()

    self._rainPart = rainPart
    self._rainSound = rainSound
    self._rainConn = RunService.RenderStepped:Connect(function()
        local cam = Workspace.CurrentCamera
        if cam and rainPart.Parent then
            rainPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 26, 0))
        end
    end)
end

function TimeAndEventController:_stopRainVFX()
    if self._rainConn then
        self._rainConn:Disconnect()
        self._rainConn = nil
    end
    if self._rainPart then
        self._rainPart:Destroy()
        self._rainPart = nil
    end
    if self._rainSound then
        self._rainSound:Stop()
        self._rainSound:Destroy()
        self._rainSound = nil
    end
    Lighting.FogEnd = self._defaultFogEnd
    Lighting.FogColor = self._defaultFogColor
end

return TimeAndEventController