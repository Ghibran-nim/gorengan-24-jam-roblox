--!strict
--[[
    TimeService.luau
    Layanan otoritatif server untuk siklus waktu 24 jam (12 menit real-time = 720 detik):
    - Mengubah Lighting.ClockTime & parameter atmosfer (Pagi, Siang, Sore, Malam)
    - Mengatur penyalaan lampu jalan (StreetLamp PointLight) saat Sore/Malam
    - Menyinkronkan jam, fase waktu, dan hari ke seluruh pemain
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local TimeScheduleConfig = require(Shared:WaitForChild("Config"):WaitForChild("TimeScheduleConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type TimeState = GameplayTypes.TimeState
type DayPhaseId = GameplayTypes.DayPhaseId

local log = Logger.new("TimeService")

local CYCLE_DURATION = GameConfig.DayCycleDurationSeconds or TimeScheduleConfig.CycleDurationSeconds or 720

local TimeService = {
    Name = "TimeService",
    _cycleOffsetSeconds = (TimeScheduleConfig.StartingClockTime / 24) * CYCLE_DURATION,
    _currentPhaseId = "Pagi" :: DayPhaseId,
    _lastLampsOn = false,
    _dayCount = 1,
    _running = false,
    _cachedLampLights = {} :: { PointLight },
    _phaseChangedListeners = {} :: { (DayPhaseId) -> () },
}

function TimeService:Init()
    log:Info("Menginisialisasi TimeService (Siklus 24h = %d detik)...", CYCLE_DURATION)

    -- Efek pencahayaan atmosfer ringan yang ramah performa mobile
    if not Lighting:FindFirstChild("GorenganAtmosphere") then
        local atmo = Instance.new("Atmosphere")
        atmo.Name = "GorenganAtmosphere"
        atmo.Density = 0.22
        atmo.Offset = 0.25
        atmo.Color = Color3.fromRGB(220, 205, 185)
        atmo.Decay = Color3.fromRGB(165, 150, 130)
        atmo.Glare = 0.1
        atmo.Haze = 0.8
        atmo.Parent = Lighting
    end

    if not Lighting:FindFirstChild("GorenganBloom") then
        local bloom = Instance.new("BloomEffect")
        bloom.Name = "GorenganBloom"
        bloom.Intensity = 0.16
        bloom.Size = 18
        bloom.Threshold = 1.15
        bloom.Parent = Lighting
    end

    if not Lighting:FindFirstChild("GorenganSunRays") then
        local rays = Instance.new("SunRaysEffect")
        rays.Name = "GorenganSunRays"
        rays.Intensity = 0.08
        rays.Spread = 0.45
        rays.Parent = Lighting
    end

    Players.PlayerAdded:Connect(function(player: Player)
        task.defer(function()
            self:SyncTimeToPlayer(player)
        end)
    end)

    self:_applyLightingForClockTime(TimeScheduleConfig.StartingClockTime, true)
end

function TimeService:Start()
    self._running = true
    log:Info("TimeService aktif dan menyinkronkan waktu ke seluruh pemain.")

    task.spawn(function()
        local lastBroadcast = 0
        while self._running do
            local dt = 1.0
            self:AdvanceTime(dt)

            local now = os.clock()
            if (now - lastBroadcast) >= 5.0 then
                lastBroadcast = now
                self:BroadcastTimeState()
            end

            task.wait(dt)
        end
    end)
end

function TimeService:AdvanceTime(realSeconds: number)
    local totalSec = self._cycleOffsetSeconds + realSeconds
    if totalSec >= CYCLE_DURATION then
        local daysPassed = math.floor(totalSec / CYCLE_DURATION)
        self._dayCount += daysPassed
        totalSec = totalSec % CYCLE_DURATION
    end
    self._cycleOffsetSeconds = totalSec

    local clockTime = (self._cycleOffsetSeconds / CYCLE_DURATION) * 24
    self:_applyLightingForClockTime(clockTime, false)
end

function TimeService:SetClockTime(hour: number)
    local clamped = hour % 24
    self._cycleOffsetSeconds = (clamped / 24) * CYCLE_DURATION
    self:_applyLightingForClockTime(clamped, true)
    self:BroadcastTimeState()
end

function TimeService:GetTimeState(): TimeState
    local clockTime = (self._cycleOffsetSeconds / CYCLE_DURATION) * 24
    local hour = math.floor(clockTime) % 24
    local minute = math.floor((clockTime - math.floor(clockTime)) * 60) % 60
    local phase = TimeScheduleConfig.GetPhaseForHour(clockTime)

    return {
        ClockTime = clockTime,
        Hour = hour,
        Minute = minute,
        PhaseId = phase.Id,
        PhaseName = phase.Name,
        DayCount = self._dayCount,
    }
end

function TimeService:GetCurrentPhaseId(): DayPhaseId
    return self._currentPhaseId
end

function TimeService:OnPhaseChanged(callback: (DayPhaseId) -> ())
    table.insert(self._phaseChangedListeners, callback)
end

function TimeService:SyncTimeToPlayer(player: Player)
    local state = self:GetTimeState()
    NetworkBridge.FireClient(player, Remotes.Events.TimeStateUpdated, state)
end

function TimeService:BroadcastTimeState()
    local state = self:GetTimeState()
    NetworkBridge.FireAllClients(Remotes.Events.TimeStateUpdated, state)
end

function TimeService:_applyLightingForClockTime(clockTime: number, forceSync: boolean)
    Lighting.ClockTime = clockTime

    local phase = TimeScheduleConfig.GetPhaseForHour(clockTime)
    Lighting.Ambient = Lighting.Ambient:Lerp(phase.Ambient, if forceSync then 1 else 0.25)
    Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(phase.OutdoorAmbient, if forceSync then 1 else 0.25)
    Lighting.ColorShift_Top = Lighting.ColorShift_Top:Lerp(phase.ColorShiftTop, if forceSync then 1 else 0.25)
    Lighting.Brightness = Lighting.Brightness + (phase.Brightness - Lighting.Brightness) * (if forceSync then 1 else 0.25)

    -- Toggle lampu jalan saat Sore/Malam
    local shouldLampsBeOn = phase.StreetLampsOn or clockTime >= 17.5 or clockTime < 5.5
    if forceSync or shouldLampsBeOn ~= self._lastLampsOn then
        self._lastLampsOn = shouldLampsBeOn
        self:_setStreetLampsEnabled(shouldLampsBeOn)
    end

    if phase.Id ~= self._currentPhaseId then
        self._currentPhaseId = phase.Id
        log:Info("Perubahan Fase Waktu: %s %s (Jam %02d:00)", phase.Icon, phase.Name, math.floor(clockTime))
        self:BroadcastTimeState()
        for _, cb in ipairs(self._phaseChangedListeners) do
            task.spawn(cb, phase.Id)
        end
    end
end

function TimeService:_setStreetLampsEnabled(enabled: boolean)
    local map = Workspace:FindFirstChild("Map")
    if not map then return end

    if #self._cachedLampLights == 0 then
        for _, desc in map:GetDescendants() do
            if desc:IsA("PointLight") and desc.Parent and desc.Parent.Name == "Bulb" then
                table.insert(self._cachedLampLights, desc)
            end
        end
    end

    for idx = #self._cachedLampLights, 1, -1 do
        local light = self._cachedLampLights[idx]
        if light and light.Parent then
            light.Enabled = enabled
        else
            table.remove(self._cachedLampLights, idx)
        end
    end
end

return TimeService