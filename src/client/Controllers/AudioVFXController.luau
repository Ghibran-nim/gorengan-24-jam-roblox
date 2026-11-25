--!strict
--[[
    AudioVFXController.luau
    Pusat Audio, Animasi Prosedural, Feedback UI, Optimasi Grafis Mobile & Menu Pengaturan:
    - Palet suara legal bawaan Roblox (minyak mendesis, transaksi kas, pelanggan, sirine, kentongan, UI click, roda gerobak, ambience)
    - Animasi prosedural NPC walk swing (Motor6D) dalam radius 95 studs (20Hz, 0 beban server)
    - Animasi aksi pemain (memasak, mengambil bahan, melayani, mendorong gerobak)
    - Menu Settings UI di pojok kiri bawah (SFX, Ambience/Hujan, Volume, Mode Hemat Low-FX, Kontrol)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local log = Logger.new("AudioVFXController")

-- Seluruh asset suara telah terverifikasi IsLoaded == true di Roblox Studio
local SOUNDS = {
    UiClick = "rbxasset://sounds/clickfast.wav",
    UiOpen = "rbxasset://sounds/button.wav",
    UiToggle = "rbxasset://sounds/switch.wav",
    OilSplash = "rbxasset://sounds/impact_water.mp3",
    OilSizzle = "rbxasset://sounds/action_swim.mp3",
    CrispyChime = "rbxasset://sounds/victory.wav",
    CashRegister = "rbxasset://sounds/electronicpingshort.wav",
    CustomerOrder = "rbxasset://sounds/snap.mp3",
    CustomerSad = "rbxasset://sounds/uuhhh.mp3",
    Kentongan = "rbxasset://sounds/bass.wav",
    Siren = "rbxasset://sounds/electronicpingshort.wav",
    CartWheels = "rbxasset://sounds/action_footsteps_plastic.mp3",
    Ambience = "rbxasset://sounds/action_falling.mp3",
    ActionWhoosh = "rbxasset://sounds/swoosh.wav",
}

local AudioVFXController = {
    Name = "AudioVFXController",
    _settings = {
        SfxEnabled = true,
        AmbienceEnabled = true,
        MasterVolume = 0.8,
        LowFxMode = false,
    },
    _gui = nil :: ScreenGui?,
    _modal = nil :: Frame?,
    _soundFolder = nil :: Folder?,
    _oilSizzleSound = nil :: Sound?,
    _cartWheelSound = nil :: Sound?,
    _ambienceSound = nil :: Sound?,
    _raidSoundThread = nil :: thread?,
    _cookAnimThread = nil :: thread?,
    _isCooking = false,
    _isPushing = false,
    _lastUiClick = 0,
    _hookedButtons = {} :: { [TextButton]: boolean },
}

function AudioVFXController:Init()
    log:Info("Menginisialisasi AudioVFXController...")

    local folder = SoundService:FindFirstChild("GorenganAudioBank")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "GorenganAudioBank"
        folder.Parent = SoundService
    end
    self._soundFolder = folder :: Folder

    self:_initLoopedSounds()
    self:_createSettingsUI()
    self:_bindServerAudioEvents()
    self:_bindNpcWalkLoop()
    self:_bindPlayerButtonClicks()
end

function AudioVFXController:Start()
    self:_refreshAmbienceState()
    log:Info("AudioVFXController aktif (Audio, Animasi Prosedural & Settings UI).")
end

function AudioVFXController:GetAmbienceMultiplier(): number
    if not self._settings.AmbienceEnabled then
        return 0
    end
    return self._settings.MasterVolume
end

function AudioVFXController:IsLowFxMode(): boolean
    return self._settings.LowFxMode
end

function AudioVFXController:_getSfxVolume(baseVol: number): number
    if not self._settings.SfxEnabled then
        return 0
    end
    return baseVol * self._settings.MasterVolume
end

function AudioVFXController:_playOneShot(soundId: string, volume: number, pitch: number?)
    if not self._soundFolder or not self._settings.SfxEnabled then
        return
    end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume * self._settings.MasterVolume
    s.PlaybackSpeed = pitch or 1.0
    s.Parent = self._soundFolder
    s:Play()
    Debris:AddItem(s, 3.5)
end

function AudioVFXController:PlayUIClick()
    local now = os.clock()
    if (now - self._lastUiClick) < 0.06 then return end
    self._lastUiClick = now
    self:_playOneShot(SOUNDS.UiClick, 0.22, 1.05)
end

function AudioVFXController:PlayTransactionSound(isPositive: boolean?)
    if isPositive == false then
        self:_playOneShot(SOUNDS.CustomerSad, 0.35, 0.95)
    else
        self:_playOneShot(SOUNDS.CashRegister, 0.35, 1.18)
    end
end

function AudioVFXController:PlayCrispyFanfare()
    self:_playOneShot(SOUNDS.CrispyChime, 0.38, 1.05)
end

function AudioVFXController:_initLoopedSounds()
    if not self._soundFolder then return end

    local sizzle = Instance.new("Sound")
    sizzle.Name = "CookingOilSizzle"
    sizzle.SoundId = SOUNDS.OilSizzle
    sizzle.Looped = true
    sizzle.Volume = 0
    sizzle.PlaybackSpeed = 1.75
    sizzle.Parent = self._soundFolder
    self._oilSizzleSound = sizzle

    local wheels = Instance.new("Sound")
    wheels.Name = "CartWheelsRoll"
    wheels.SoundId = SOUNDS.CartWheels
    wheels.Looped = true
    wheels.Volume = 0
    wheels.PlaybackSpeed = 0.92
    wheels.Parent = self._soundFolder
    self._cartWheelSound = wheels

    local amb = Instance.new("Sound")
    amb.Name = "StreetAmbienceBreeze"
    amb.SoundId = SOUNDS.Ambience
    amb.Looped = true
    amb.Volume = 0.045 * self._settings.MasterVolume
    amb.PlaybackSpeed = 0.45
    amb.Parent = self._soundFolder
    self._ambienceSound = amb
end

function AudioVFXController:_refreshAmbienceState()
    if self._ambienceSound then
        if self._settings.AmbienceEnabled then
            self._ambienceSound.Volume = 0.045 * self._settings.MasterVolume
            if not self._ambienceSound.IsPlaying then
                self._ambienceSound:Play()
            end
        else
            self._ambienceSound:Stop()
        end
    end

    local rainAmb = SoundService:FindFirstChild("ClientRainAmbience")
    if rainAmb and rainAmb:IsA("Sound") then
        rainAmb.Volume = 0.22 * self:GetAmbienceMultiplier()
    end
end

function AudioVFXController:_applyLowFxSetting()
    local lowFx = self._settings.LowFxMode
    local bloom = Lighting:FindFirstChild("GorenganBloom")
    if bloom and bloom:IsA("BloomEffect") then
        bloom.Enabled = not lowFx
    end
    local rays = Lighting:FindFirstChild("GorenganSunRays")
    if rays and rays:IsA("SunRaysEffect") then
        rays.Enabled = not lowFx
    end
end

-- ============================================================================
-- AUDIO & ANIMASI AKSI GAMEPLAY PEMAIN LOKAL
-- ============================================================================

function AudioVFXController:_tweenRightArmPose(offsetCFrame: CFrame, duration: number)
    local char = Players.LocalPlayer.Character
    if not char then return end
    local rUpper = char:FindFirstChild("RightUpperArm")
    local shoulder = if rUpper then rUpper:FindFirstChild("RightShoulder") :: Motor6D? else nil
    local torso = char:FindFirstChild("Torso")
    local r6Shoulder = if torso then torso:FindFirstChild("Right Shoulder") :: Motor6D? else nil
    local motor = shoulder or r6Shoulder
    if not motor then return end

    local origC0 = motor.C0
    local tw = TweenService:Create(motor, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        C0 = origC0 * offsetCFrame,
    })
    tw:Play()
    tw.Completed:Once(function()
        if motor.Parent then
            TweenService:Create(motor, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = origC0,
            }):Play()
        end
    end)
end

function AudioVFXController:SetCookingFeedback(active: boolean)
    self._isCooking = active
    if self._cookAnimThread then
        task.cancel(self._cookAnimThread)
        self._cookAnimThread = nil
    end

    if active then
        self:_playOneShot(SOUNDS.OilSplash, 0.32, 1.35)
        if self._oilSizzleSound then
            self._oilSizzleSound.Volume = self:_getSfxVolume(0.26)
            if not self._oilSizzleSound.IsPlaying then
                self._oilSizzleSound:Play()
            end
        end
        self._cookAnimThread = task.spawn(function()
            while self._isCooking do
                self:_tweenRightArmPose(CFrame.Angles(math.rad(48), math.rad(15), math.rad(-12)), 0.45)
                task.wait(0.75)
            end
        end)
    else
        if self._oilSizzleSound and self._oilSizzleSound.IsPlaying then
            self._oilSizzleSound:Stop()
        end
    end
end

function AudioVFXController:PlayGrabIngredientFeedback()
    self:_playOneShot(SOUNDS.ActionWhoosh, 0.28, 1.1)
    self:_tweenRightArmPose(CFrame.Angles(math.rad(65), 0, math.rad(-10)), 0.32)
end

function AudioVFXController:PlayServeFeedback()
    self:_playOneShot(SOUNDS.ActionWhoosh, 0.30, 1.25)
    self:_tweenRightArmPose(CFrame.Angles(math.rad(75), math.rad(-15), 0), 0.35)
end

function AudioVFXController:SetPushingCartFeedback(isPushing: boolean)
    self._isPushing = isPushing
    if not isPushing then
        if self._cartWheelSound and self._cartWheelSound.IsPlaying then
            self._cartWheelSound:Stop()
        end
        return
    end

    self:_playOneShot(SOUNDS.UiToggle, 0.25, 0.95)
    task.spawn(function()
        while self._isPushing do
            local char = Players.LocalPlayer.Character
            local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
            local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.08
            if self._cartWheelSound then
                if moving then
                    self._cartWheelSound.Volume = self:_getSfxVolume(0.18)
                    if not self._cartWheelSound.IsPlaying then
                        self._cartWheelSound:Play()
                    end
                elseif self._cartWheelSound.IsPlaying then
                    self._cartWheelSound:Stop()
                end
            end
            task.wait(0.15)
        end
        if self._cartWheelSound and self._cartWheelSound.IsPlaying then
            self._cartWheelSound:Stop()
        end
    end)
end

-- ============================================================================
-- KONEKSI EVENT SERVER -> AUDIO/ANIMASI CLIENT
-- ============================================================================

function AudioVFXController:_bindServerAudioEvents()
    NetworkBridge.OnClientEvent(Remotes.Events.CookStateChanged, function(state: string)
        self:SetCookingFeedback(state == "Cooking")
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.FoodCollected, function(quality: string)
        self:SetCookingFeedback(false)
        if quality == "Crispy" then
            self:PlayCrispyFanfare()
        elseif quality == "Burnt" then
            self:_playOneShot(SOUNDS.CustomerSad, 0.32, 0.85)
        else
            self:_playOneShot(SOUNDS.UiOpen, 0.28, 0.95)
        end
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.CustomerOrderCreated, function()
        self:_playOneShot(SOUNDS.CustomerOrder, 0.25, 1.1)
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.CustomerOrderCompleted, function(_cid: string, _payout: number, quality: string)
        self:PlayServeFeedback()
        self:PlayTransactionSound(quality ~= "Burnt")
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.LevelUpAchieved, function()
        self:PlayCrispyFanfare()
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.RecipeUnlocked, function()
        self:PlayCrispyFanfare()
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.CartPushStateChanged, function(isPushing: boolean)
        self:SetPushingCartFeedback(isPushing)
    end)

    NetworkBridge.OnClientEvent(Remotes.Events.RaidAlert, function(state: string, duration: number)
        self:_handleRaidAudio(state, duration)
    end)
end

function AudioVFXController:_handleRaidAudio(state: string, duration: number)
    if self._raidSoundThread then
        task.cancel(self._raidSoundThread)
        self._raidSoundThread = nil
    end

    if state == "Warning" then
        -- Ritme Kentongan Bambu "tok-tok-tok" selama peringatan razia
        self._raidSoundThread = task.spawn(function()
            local endsAt = os.clock() + math.min(duration or 15, 20)
            while os.clock() < endsAt do
                self:_playOneShot(SOUNDS.Kentongan, 0.36, 1.9)
                task.wait(0.22)
                self:_playOneShot(SOUNDS.Kentongan, 0.32, 2.05)
                task.wait(0.22)
                self:_playOneShot(SOUNDS.Kentongan, 0.36, 1.9)
                task.wait(1.05)
            end
        end)
    elseif state == "Active" then
        -- Sirine Satpol 2-nada lembut yang tidak mengganggu konsentrasi pemain
        self._raidSoundThread = task.spawn(function()
            local endsAt = os.clock() + math.min(duration or 45, 45)
            local high = true
            while os.clock() < endsAt do
                self:_playOneShot(SOUNDS.Siren, 0.16, if high then 0.86 else 0.66)
                high = not high
                task.wait(0.95)
            end
        end)
    end
end

-- ============================================================================
-- ANIMASI PROSEDURAL NPC (CUSTOMER & SATPOL PP) — 20Hz & DISTANCE CULLED
-- ============================================================================

local function animateNpcRig(model: Model, phase: number, isWalking: boolean)
    local torso = model:FindFirstChild("Torso")
    if not torso then return end

    local la = torso:FindFirstChild("LeftArmJoint") :: Motor6D?
    local ra = torso:FindFirstChild("RightArmJoint") :: Motor6D?
    local ll = torso:FindFirstChild("LeftLegJoint") :: Motor6D?
    local rl = torso:FindFirstChild("RightLegJoint") :: Motor6D?
    if not (la and ra and ll and rl) then return end

    local swing = if isWalking then math.sin(phase) * 0.55 else 0
    la.C0 = CFrame.new(-1.45, 0.6, 0) * CFrame.Angles(swing, 0, 0)
    ra.C0 = CFrame.new(1.45, 0.6, 0) * CFrame.Angles(-swing, 0, 0)
    ll.C0 = CFrame.new(-0.5, -1.0, 0) * CFrame.Angles(-swing, 0, 0)
    rl.C0 = CFrame.new(0.5, -1.0, 0) * CFrame.Angles(swing, 0, 0)
end

function AudioVFXController:_bindNpcWalkLoop()
    local acc = 0
    local walkTime = 0
    RunService.RenderStepped:Connect(function(dt: number)
        acc += dt
        if acc < 0.05 then return end -- ~20Hz untuk performa mobile optimal
        walkTime += acc * 9.0
        acc = 0

        local cam = Workspace.CurrentCamera
        local camPos = if cam then cam.CFrame.Position else Vector3.zero

        local function processModel(inst: Instance)
            if not inst:IsA("Model") then return end
            if string.sub(inst.Name, 1, 9) ~= "Customer_" and string.sub(inst.Name, 1, 7) ~= "Satpol_" then
                return
            end
            local hrp = inst.PrimaryPart
            local hum = inst:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end
            if (hrp.Position - camPos).Magnitude > 95 then return end
            animateNpcRig(inst, walkTime, hum.MoveDirection.Magnitude > 0.05)
        end

        for _, child in Workspace:GetChildren() do
            processModel(child)
        end
        local squad = Workspace:FindFirstChild("SatpolSquad")
        if squad then
            for _, child in squad:GetChildren() do
                processModel(child)
            end
        end
    end)
end

-- ============================================================================
-- AUTO UI CLICK FEEDBACK & MENU PENGATURAN (SETTINGS)
-- ============================================================================

function AudioVFXController:_bindPlayerButtonClicks()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local function hookBtn(inst: Instance)
        if inst:IsA("TextButton") and not self._hookedButtons[inst] then
            self._hookedButtons[inst] = true
            inst.MouseButton1Click:Connect(function()
                self:PlayUIClick()
            end)
        end
    end
    for _, d in playerGui:GetDescendants() do
        hookBtn(d)
    end
    playerGui.DescendantAdded:Connect(hookBtn)
end

function AudioVFXController:_createSettingsUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("SettingsHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SettingsHUD"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 20
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Tombol Settings di pojok kiri bawah (touch-friendly & zero overlap)
    local openBtn = Instance.new("TextButton")
    openBtn.Name = "SettingsButton"
    openBtn.Size = UDim2.new(0, 128, 0, 44)
    openBtn.Position = UDim2.new(0, 16, 1, -62)
    openBtn.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
    openBtn.BackgroundTransparency = 0.12
    openBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
    openBtn.Font = Enum.Font.FredokaOne
    openBtn.TextSize = 13
    openBtn.Text = "⚙️ Pengaturan"
    openBtn.Parent = screenGui
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 10)
    local oStroke = Instance.new("UIStroke", openBtn)
    oStroke.Color = Color3.fromRGB(85, 95, 115)
    oStroke.Thickness = 1.5

    -- Modal Pengaturan Tengah
    local modal = Instance.new("Frame")
    modal.Name = "SettingsModal"
    modal.Size = UDim2.new(0, 400, 0, 340)
    modal.Position = UDim2.new(0.5, -200, 0.5, -170)
    modal.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
    modal.Visible = false
    modal.Parent = screenGui
    Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
    local mStroke = Instance.new("UIStroke", modal)
    mStroke.Color = Color3.fromRGB(110, 165, 235)
    mStroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(145, 210, 255)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "⚙️ PENGATURAN AUDIO & GRAFIS"
    title.Parent = modal

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 34, 0, 32)
    closeBtn.Position = UDim2.new(1, -44, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextSize = 15
    closeBtn.Text = "X"
    closeBtn.Parent = modal
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.MouseButton1Click:Connect(function()
        modal.Visible = false
    end)

    openBtn.MouseButton1Click:Connect(function()
        modal.Visible = not modal.Visible
        self:_playOneShot(SOUNDS.UiOpen, 0.24, 1.0)
    end)

    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -28, 1, -60)
    list.Position = UDim2.new(0, 14, 0, 48)
    list.BackgroundTransparency = 1
    list.Parent = modal
    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function createToggleRow(name: string, labelText: string, getState: () -> boolean, onToggle: () -> ())
        local row = Instance.new("Frame")
        row.Name = name
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
        row.BorderSizePixel = 0
        row.Parent = list
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -110, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(245, 245, 250)
        lbl.Font = Enum.Font.FredokaOne
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = labelText
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Name = "ToggleBtn"
        btn.Size = UDim2.new(0, 92, 0, 30)
        btn.Position = UDim2.new(1, -100, 0.5, -15)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local function refresh()
            local on = getState()
            btn.BackgroundColor3 = if on then Color3.fromRGB(45, 150, 85) else Color3.fromRGB(130, 55, 55)
            btn.Text = if on then "AKTIF" else "MATI"
        end
        refresh()

        btn.MouseButton1Click:Connect(function()
            onToggle()
            self:_playOneShot(SOUNDS.UiToggle, 0.25, 1.0)
            refresh()
        end)
    end

    createToggleRow("RowSFX", "🔊 Efek Suara Masak & UI (SFX)", function() return self._settings.SfxEnabled end, function()
        self._settings.SfxEnabled = not self._settings.SfxEnabled
        if not self._settings.SfxEnabled and self._oilSizzleSound then
            self._oilSizzleSound:Stop()
        end
    end)

    createToggleRow("RowAmbience", "🌧️ Suara Lingkungan & Hujan", function() return self._settings.AmbienceEnabled end, function()
        self._settings.AmbienceEnabled = not self._settings.AmbienceEnabled
        self:_refreshAmbienceState()
    end)

    createToggleRow("RowLowFX", "🔋 Mode Grafis Hemat (HP Low-End)", function() return self._settings.LowFxMode end, function()
        self._settings.LowFxMode = not self._settings.LowFxMode
        self:_applyLowFxSetting()
    end)

    -- Baris Kontrol Volume
    local volRow = Instance.new("Frame")
    volRow.Name = "RowVolume"
    volRow.Size = UDim2.new(1, 0, 0, 44)
    volRow.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
    volRow.Parent = list
    Instance.new("UICorner", volRow).CornerRadius = UDim.new(0, 8)

    local volLbl = Instance.new("TextLabel")
    volLbl.Size = UDim2.new(1, -130, 1, 0)
    volLbl.Position = UDim2.new(0, 12, 0, 0)
    volLbl.BackgroundTransparency = 1
    volLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
    volLbl.Font = Enum.Font.FredokaOne
    volLbl.TextSize = 13
    volLbl.TextXAlignment = Enum.TextXAlignment.Left
    volLbl.Text = "🎚️ Volume Utama"
    volLbl.Parent = volRow

    local volBtn = Instance.new("TextButton")
    volBtn.Name = "VolumeBtn"
    volBtn.Size = UDim2.new(0, 112, 0, 30)
    volBtn.Position = UDim2.new(1, -120, 0.5, -15)
    volBtn.BackgroundColor3 = Color3.fromRGB(50, 105, 185)
    volBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    volBtn.Font = Enum.Font.FredokaOne
    volBtn.TextSize = 12
    volBtn.Text = "80% (Normal)"
    volBtn.Parent = volRow
    Instance.new("UICorner", volBtn).CornerRadius = UDim.new(0, 6)

    local presets = {
        { val = 0.4, text = "40% (Pelan)" },
        { val = 0.8, text = "80% (Normal)" },
        { val = 1.0, text = "100% (Penuh)" },
    }
    local pIdx = 2
    volBtn.MouseButton1Click:Connect(function()
        pIdx = (pIdx % #presets) + 1
        self._settings.MasterVolume = presets[pIdx].val
        volBtn.Text = presets[pIdx].text
        self:_refreshAmbienceState()
    end)

    -- Info Kontrol PC & Mobile
    local helpLbl = Instance.new("TextLabel")
    helpLbl.Name = "ControlsHint"
    helpLbl.Size = UDim2.new(1, 0, 0, 74)
    helpLbl.BackgroundColor3 = Color3.fromRGB(26, 29, 36)
    helpLbl.TextColor3 = Color3.fromRGB(195, 205, 220)
    helpLbl.Font = Enum.Font.GothamMedium
    helpLbl.TextSize = 11
    helpLbl.TextWrapped = true
    helpLbl.Text = "🎮 KONTROL: [E] Masak / Ambil / Layani • [F] Dorong Gerobak\n[Q] Bidik Gosong • [G] Lempar • [V] Icip Gerobak Tetangga\n📱 MOBILE: Semua tombol tersedia langsung di layar sentuh!"
    helpLbl.Parent = list
    Instance.new("UICorner", helpLbl).CornerRadius = UDim.new(0, 8)

    self._gui = screenGui
    self._modal = modal
    screenGui.Parent = playerGui
end

return AudioVFXController
