--!strict
--[[
    ThrowableController.luau
    Mengelola mekanik client untuk gorengan gosong sebagai senjata lempar komedi:
    - Tombol sentuh mobile & shortcut PC ([Q] Bidik, [G] / Klik Kiri Lempar)
    - Crosshair bidikan saat mode lempar aktif
    - Animasi ayunan lengan prosedural R15/R6
    - Simulasi proyektil visual 60fps dengan efek asap & rotasi
    - VFX tumbukan (ledakan remah, cincin kejut, teks komedi 3D, bintang pusing ragdoll)
    - Sound effect bawaan Roblox yang aman & responsif
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

local log = Logger.new("ThrowableController")

local THROW_COOLDOWN = GameConfig.BurntThrowCooldownSeconds or 3.5

local SOUND_IDS = {
    Throw = "rbxasset://sounds/action_jump.mp3",
    Impact = "rbxasset://sounds/action_get_up.mp3",
    ComedyHit = "rbxasset://sounds/uuhhh.mp3",
}

local ThrowableController = {
    Name = "ThrowableController",
    _isEquipped = false,
    _equippedRecipeId = nil :: string?,
    _totalBurnt = 0,
    _cooldownUntil = 0,
    _gui = nil :: ScreenGui?,
    _throwBtn = nil :: TextButton?,
    _aimBtn = nil :: TextButton?,
    _cooldownFill = nil :: Frame?,
    _crosshair = nil :: Frame?,
    _activeProjectiles = {} :: { [string]: { Part: BasePart, Active: boolean } },
    _dizzyBillboards = {} :: { [number]: BillboardGui },
}

local function playWorldSound(parent: Instance, soundId: string, volume: number, speed: number)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = speed
    sound.RollOffMaxDistance = 60
    sound.RollOffMinDistance = 8
    sound.Parent = parent
    sound:Play()
    Debris:AddItem(sound, 3)
end

function ThrowableController:Init()
    log:Info("Menginisialisasi ThrowableController...")

    -- Sinkronisasi jumlah gorengan gosong dari pembaruan inventaris
    NetworkBridge.OnClientEvent(Remotes.Events.InventoryUpdated, function(_ingredients: any, cookedFood: any)
        local count = 0
        if typeof(cookedFood) == "table" then
            for _, qualities in pairs(cookedFood) do
                if typeof(qualities) == "table" then
                    count += (qualities.Burnt or 0)
                end
            end
        end
        self._totalBurnt = count
        self:_updateHUD()
    end)

    -- Event status memegang gorengan gosong
    NetworkBridge.OnClientEvent(Remotes.Events.BurntFoodEquippedChanged, function(isEquipped: boolean, recipeId: string?, totalBurnt: number)
        self._isEquipped = isEquipped
        self._equippedRecipeId = recipeId
        self._totalBurnt = totalBurnt or self._totalBurnt
        self:_updateHUD()
    end)

    -- Event peluncuran proyektil gorengan gosong dari pemain mana pun
    NetworkBridge.OnClientEvent(Remotes.Events.BurntFoodThrown, function(throwId: string, throwerUserId: number, origin: Vector3, velocity: Vector3, gravity: number, recipeId: string)
        self:_playThrowAnimationForUser(throwerUserId)
        self:_spawnVisualProjectile(throwId, origin, velocity, gravity)
    end)

    -- Event benturan proyektil
    NetworkBridge.OnClientEvent(Remotes.Events.BurntFoodImpact, function(throwId: string, hitPosition: Vector3, hitPlayerUserId: number?, comedyText: string)
        self:_handleImpactVFX(throwId, hitPosition, hitPlayerUserId, comedyText)
    end)

    -- Event ragdoll sementara pemain
    NetworkBridge.OnClientEvent(Remotes.Events.PlayerRagdollStateChanged, function(targetUserId: number, isRagdolled: boolean, duration: number)
        self:_handleRagdollFeedback(targetUserId, isRagdolled, duration)
    end)

    -- Input PC: [G] Lempar cepat, [Q] Toggle Bidik, Klik Kiri saat Mode Bidik
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.G then
            self:ThrowBurntFood()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:ToggleEquipBurntFood()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self._isEquipped then
            self:ThrowBurntFood(true)
        end
    end)

    self:_createThrowableUI()

    -- Update bar cooldown secara halus
    RunService.RenderStepped:Connect(function()
        if self._cooldownFill and self._cooldownUntil > os.clock() then
            local remaining = self._cooldownUntil - os.clock()
            local ratio = math.clamp(remaining / THROW_COOLDOWN, 0, 1)
            self._cooldownFill.Size = UDim2.fromScale(ratio, 1)
            self._cooldownFill.Visible = true
        elseif self._cooldownFill and self._cooldownFill.Visible then
            self._cooldownFill.Visible = false
            self:_updateHUD()
        end
    end)
end

function ThrowableController:Start()
    task.spawn(function()
        local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestGetInventory)
        if res and res.Success and typeof(res.CookedFood) == "table" then
            local count = 0
            for _, qualities in pairs(res.CookedFood) do
                if typeof(qualities) == "table" then
                    count += (qualities.Burnt or 0)
                end
            end
            self._totalBurnt = count
            self:_updateHUD()
        end
    end)
    log:Info("ThrowableController aktif (PC: [Q] Bidik / [G] Lempar, Mobile: Tombol HUD).")
end

function ThrowableController:_createThrowableUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ThrowableHUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ThrowableHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 1. Crosshair Bidikan Tengah Layar (Muncul saat mode bidik aktif)
    local crosshair = Instance.new("Frame")
    crosshair.Name = "AimCrosshair"
    crosshair.Size = UDim2.new(0, 34, 0, 34)
    crosshair.Position = UDim2.new(0.5, -17, 0.5, -17)
    crosshair.BackgroundTransparency = 1
    crosshair.Visible = false
    crosshair.Parent = screenGui

    local chStroke = Instance.new("UIStroke")
    chStroke.Color = Color3.fromRGB(255, 90, 40)
    chStroke.Thickness = 2.5
    chStroke.Parent = crosshair

    local chCorner = Instance.new("UICorner")
    chCorner.CornerRadius = UDim.new(1, 0)
    chCorner.Parent = crosshair

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0.5, -3, 0.5, -3)
    dot.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
    dot.BorderSizePixel = 0
    dot.Parent = crosshair
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    -- 2. Panel Tombol Touch-Friendly (Di atas ActionDock pojok kanan bawah)
    local throwBtn = Instance.new("TextButton")
    throwBtn.Name = "ThrowBurntButton"
    throwBtn.Size = UDim2.new(0, 130, 0, 52)
    throwBtn.Position = UDim2.new(1, -146, 1, -128)
    throwBtn.BackgroundColor3 = Color3.fromRGB(165, 50, 35)
    throwBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    throwBtn.Font = Enum.Font.FredokaOne
    throwBtn.TextSize = 14
    throwBtn.Text = "🔥 Lempar (0)"
    throwBtn.AutoButtonColor = true
    throwBtn.Parent = screenGui

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 10)
    tCorner.Parent = throwBtn

    local tStroke = Instance.new("UIStroke")
    tStroke.Color = Color3.fromRGB(245, 160, 60)
    tStroke.Thickness = 1.5
    tStroke.Parent = throwBtn

    local cdBg = Instance.new("Frame")
    cdBg.Name = "CooldownOverlay"
    cdBg.Size = UDim2.fromScale(0, 1)
    cdBg.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    cdBg.BackgroundTransparency = 0.45
    cdBg.BorderSizePixel = 0
    cdBg.Visible = false
    cdBg.Parent = throwBtn

    local cdCorner = Instance.new("UICorner")
    cdCorner.CornerRadius = UDim.new(0, 10)
    cdCorner.Parent = cdBg

    throwBtn.MouseButton1Click:Connect(function()
        self:ThrowBurntFood(false)
    end)

    -- 3. Tombol Toggle Bidik (Mobile & PC)
    local aimBtn = Instance.new("TextButton")
    aimBtn.Name = "AimToggleButton"
    aimBtn.Size = UDim2.new(0, 84, 0, 52)
    aimBtn.Position = UDim2.new(1, -238, 1, -128)
    aimBtn.BackgroundColor3 = Color3.fromRGB(55, 58, 66)
    aimBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    aimBtn.Font = Enum.Font.FredokaOne
    aimBtn.TextSize = 13
    aimBtn.Text = "🎯 Bidik\n[Q]"
    aimBtn.Parent = screenGui

    local aCorner = Instance.new("UICorner")
    aCorner.CornerRadius = UDim.new(0, 10)
    aCorner.Parent = aimBtn

    local aStroke = Instance.new("UIStroke")
    aStroke.Color = Color3.fromRGB(95, 105, 120)
    aStroke.Thickness = 1.5
    aStroke.Parent = aimBtn

    aimBtn.MouseButton1Click:Connect(function()
        self:ToggleEquipBurntFood()
    end)

    self._gui = screenGui
    self._throwBtn = throwBtn
    self._aimBtn = aimBtn
    self._cooldownFill = cdBg
    self._crosshair = crosshair
    screenGui.Parent = playerGui

    self:_updateHUD()
end

function ThrowableController:_updateHUD()
    if self._crosshair then
        self._crosshair.Visible = self._isEquipped
    end

    if self._aimBtn then
        if self._isEquipped then
            self._aimBtn.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
            self._aimBtn.Text = "🎯 Bidik\n(AKTIF)"
        else
            self._aimBtn.BackgroundColor3 = Color3.fromRGB(55, 58, 66)
            self._aimBtn.Text = "🎯 Bidik\n[Q]"
        end
    end

    if self._throwBtn then
        if self._totalBurnt > 0 then
            self._throwBtn.BackgroundColor3 = Color3.fromRGB(185, 50, 35)
            self._throwBtn.Text = string.format("🔥 Lempar (%d)\n[G]", self._totalBurnt)
        else
            self._throwBtn.BackgroundColor3 = Color3.fromRGB(70, 62, 62)
            self._throwBtn.Text = "🔥 Gosong (0)\nMasak >80%"
        end
    end
end

function ThrowableController:_notify(message: string, alertType: string)
    local HUDController = require(script.Parent:WaitForChild("HUDController"))
    if HUDController and (HUDController :: any).ShowToastNotification then
        (HUDController :: any):ShowToastNotification(message, alertType)
    end
end

function ThrowableController:ToggleEquipBurntFood(recipeId: string?)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestEquipBurntFood, recipeId)
    if res and res.Success then
        self._isEquipped = res.Equipped == true
        self._totalBurnt = res.TotalBurnt or self._totalBurnt
        self:_updateHUD()
        if self._isEquipped then
            self:_notify("🎯 Mode Bidik Aktif! Arahkan & klik/tekan [G] untuk melempar!", "Warning")
        end
    elseif res and res.Error then
        self:_notify("⚠️ " .. res.Error, "Warning")
    end
end

function ThrowableController:_computeAimDirection(useMousePointer: boolean): Vector3
    local camera = Workspace.CurrentCamera
    local localPlayer = Players.LocalPlayer
    local char = localPlayer.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

    if useMousePointer and camera then
        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        return ray.Direction.Unit
    elseif camera then
        return camera.CFrame.LookVector.Unit
    elseif hrp then
        return hrp.CFrame.LookVector.Unit
    end

    return Vector3.new(0, 0, -1)
end

function ThrowableController:ThrowBurntFood(useMousePointer: boolean?)
    if os.clock() < self._cooldownUntil then
        local rem = self._cooldownUntil - os.clock()
        self:_notify(string.format("⏳ Tunggu %.1f detik lagi!", rem), "Warning")
        return
    end

    local aimDir = self:_computeAimDirection(useMousePointer == true)
    local res = NetworkBridge.InvokeServer(Remotes.Functions.RequestThrowBurntFood, aimDir, self._equippedRecipeId)

    if res and res.Success then
        self._cooldownUntil = os.clock() + THROW_COOLDOWN
        if res.RemainingBurnt ~= nil then
            self._totalBurnt = res.RemainingBurnt
            if self._totalBurnt <= 0 then
                self._isEquipped = false
            end
        end
        self:_updateHUD()
    elseif res and res.Error then
        if res.CooldownRemaining then
            self._cooldownUntil = os.clock() + res.CooldownRemaining
        end
        self:_notify("⚠️ " .. res.Error, "Warning")
    end
end

function ThrowableController:_playThrowAnimationForUser(userId: number)
    local thrower = Players:GetPlayerByUserId(userId)
    local char = if thrower then thrower.Character else nil
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        playWorldSound(hrp, SOUND_IDS.Throw, 0.45, 1.65)
    end

    -- Animasi prosedural ayunan lengan kanan (kompatibel R15 AnimationConstraint/Motor6D & R6)
    local rightUpperArm = char:FindFirstChild("RightUpperArm")
    local torso = char:FindFirstChild("Torso")
    local shoulder: Instance? = nil

    if rightUpperArm then
        shoulder = rightUpperArm:FindFirstChild("RightShoulder")
    elseif torso then
        shoulder = torso:FindFirstChild("Right Shoulder")
    end

    if not shoulder then return end

    if shoulder:IsA("Motor6D") then
        local originalC0 = shoulder.C0
        task.spawn(function()
            if not shoulder or not shoulder.Parent then return end
            shoulder.C0 = originalC0 * CFrame.Angles(math.rad(135), 0, math.rad(-10))
            task.wait(0.08)
            if not shoulder or not shoulder.Parent then return end
            shoulder.C0 = originalC0 * CFrame.Angles(math.rad(-45), 0, math.rad(8))
            task.wait(0.14)
            if not shoulder or not shoulder.Parent then return end
            shoulder.C0 = originalC0
        end)
    elseif shoulder:IsA("AnimationConstraint") then
        task.spawn(function()
            local start = os.clock()
            local conn: RBXScriptConnection
            conn = RunService.Stepped:Connect(function()
                if not shoulder or not shoulder.Parent then
                    conn:Disconnect()
                    return
                end
                local t = os.clock() - start
                if t < 0.08 then
                    shoulder.Transform = CFrame.Angles(math.rad(135), 0, math.rad(-10))
                elseif t < 0.24 then
                    shoulder.Transform = CFrame.Angles(math.rad(-45), 0, math.rad(8))
                else
                    conn:Disconnect()
                end
            end)
        end)
    end
end

function ThrowableController:_spawnVisualProjectile(throwId: string, origin: Vector3, velocity: Vector3, gravity: number)
    local proj = Instance.new("Part")
    proj.Name = "BurntProjectile_" .. throwId
    proj.Size = Vector3.new(0.95, 0.42, 0.95)
    proj.Color = Color3.fromRGB(28, 22, 20)
    proj.Material = Enum.Material.Slate
    proj.Anchored = true
    proj.CanCollide = false
    proj.CFrame = CFrame.new(origin)

    -- Jejak asap gosong saat terbang
    local smoke = Instance.new("ParticleEmitter")
    smoke.Color = ColorSequence.new(Color3.fromRGB(45, 45, 45))
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) })
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.0) })
    smoke.Rate = 35
    smoke.Speed = NumberRange.new(1, 3)
    smoke.Lifetime = NumberRange.new(0.35, 0.65)
    smoke.Parent = proj

    proj.Parent = Workspace

    local state = { Part = proj, Active = true }
    self._activeProjectiles[throwId] = state

    task.spawn(function()
        local pos = origin
        local vel = velocity
        local spinAngle = 0
        local elapsed = 0

        while state.Active and proj.Parent and elapsed < 2.2 do
            local dt = RunService.RenderStepped:Wait()
            elapsed += dt
            pos = pos + (vel * dt)
            vel = vel - Vector3.new(0, gravity * dt, 0)
            spinAngle += dt * 14
            proj.CFrame = CFrame.new(pos) * CFrame.Angles(spinAngle, spinAngle * 0.7, 0)
        end

        if proj.Parent then
            proj:Destroy()
        end
        self._activeProjectiles[throwId] = nil
    end)
end

function ThrowableController:_handleImpactVFX(throwId: string, hitPosition: Vector3, hitPlayerUserId: number?, comedyText: string)
    local active = self._activeProjectiles[throwId]
    if active then
        active.Active = false
        if active.Part and active.Part.Parent then
            active.Part:Destroy()
        end
        self._activeProjectiles[throwId] = nil
    end

    -- Anchor titik ledakan sementara
    local impactAnchor = Instance.new("Part")
    impactAnchor.Name = "BurntImpactVFX"
    impactAnchor.Size = Vector3.new(0.5, 0.5, 0.5)
    impactAnchor.Transparency = 1
    impactAnchor.Anchored = true
    impactAnchor.CanCollide = false
    impactAnchor.CFrame = CFrame.new(hitPosition)
    impactAnchor.Parent = Workspace

    playWorldSound(impactAnchor, SOUND_IDS.Impact, 0.5, 0.85)

    -- Partikel ledakan remah gosong + asap
    local burst = Instance.new("ParticleEmitter")
    burst.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 30, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 80, 75)),
    })
    burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
    burst.Speed = NumberRange.new(8, 18)
    burst.SpreadAngle = Vector2.new(180, 180)
    burst.Lifetime = NumberRange.new(0.4, 0.8)
    burst.Rate = 0
    burst.Parent = impactAnchor
    burst:Emit(20)

    -- Cincin kejut kartun
    local ring = Instance.new("Part")
    ring.Name = "ImpactRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.15, 1.5, 1.5)
    ring.Color = if hitPlayerUserId then Color3.fromRGB(255, 110, 40) else Color3.fromRGB(70, 65, 60)
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.25
    ring.Anchored = true
    ring.CanCollide = false
    ring.CFrame = CFrame.new(hitPosition) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 7.0, 7.0),
        Transparency = 1,
    }):Play()

    -- Teks komedi mengambang 3D
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 220, 0, 56)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 65
    bb.Adornee = impactAnchor
    bb.Parent = impactAnchor

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.FredokaOne
    txt.TextScaled = true
    txt.TextStrokeTransparency = 0.2
    txt.TextColor3 = if hitPlayerUserId then Color3.fromRGB(255, 225, 60) else Color3.fromRGB(220, 220, 220)
    txt.Text = comedyText or "BLETAK!"
    txt.Parent = bb

    TweenService:Create(bb, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 4.2, 0),
    }):Play()

    Debris:AddItem(ring, 0.45)
    Debris:AddItem(impactAnchor, 1.4)
end

function ThrowableController:_handleRagdollFeedback(targetUserId: number, isRagdolled: boolean, duration: number)
    local target = Players:GetPlayerByUserId(targetUserId)
    local char = if target then target.Character else nil

    if isRagdolled then
        if char then
            local head = char:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                playWorldSound(head, SOUND_IDS.ComedyHit, 0.65, 1.15)

                local old = self._dizzyBillboards[targetUserId]
                if old then old:Destroy() end

                local dizzy = Instance.new("BillboardGui")
                dizzy.Name = "DizzyStarsGui"
                dizzy.Size = UDim2.new(0, 160, 0, 50)
                dizzy.StudsOffset = Vector3.new(0, 2.2, 0)
                dizzy.AlwaysOnTop = true
                dizzy.Adornee = head
                dizzy.Parent = head

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.fromScale(1, 1)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.FredokaOne
                lbl.TextScaled = true
                lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
                lbl.TextStrokeTransparency = 0.2
                lbl.Text = "💫 😵 GOSONG! 💫"
                lbl.Parent = dizzy

                self._dizzyBillboards[targetUserId] = dizzy
                Debris:AddItem(dizzy, duration + 0.3)
            end
        end

        if targetUserId == Players.LocalPlayer.UserId then
            self:_notify("😵 BLETAK! Kamu sempoyongan terkena gorengan gosong!", "Burnt")
        end
    else
        local old = self._dizzyBillboards[targetUserId]
        if old then
            old:Destroy()
            self._dizzyBillboards[targetUserId] = nil
        end
    end
end

return ThrowableController