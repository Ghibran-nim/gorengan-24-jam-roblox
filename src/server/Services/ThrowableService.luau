--!strict
--[[
    ThrowableService.luau
    Layanan otoritatif server untuk mekanik gorengan gosong sebagai senjata lempar komedi:
    - Mengambil & membekali gorengan gosong dari inventaris etalase pemain
    - Validasi penuh server atas kepemilikan item, cooldown lempar, jarak maks, dan payload arah
    - Simulasi proyektil balistik stepped raycast di server (anti-fake-position & anti-tembus-tembok)
    - Efek ragdoll sementara (2 detik) dengan perlindungan Safe Zone, Spawn Protection, dan Target Immunity
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

local log = Logger.new("ThrowableService")

-- Konstanta mekanik dengan defensive fallback
local THROW_COOLDOWN = GameConfig.BurntThrowCooldownSeconds or 3.5
local THROW_MAX_DISTANCE = GameConfig.BurntThrowMaxDistance or 55
local THROW_SPEED = GameConfig.BurntThrowProjectileSpeed or 65
local THROW_GRAVITY = GameConfig.BurntThrowGravity or 38
local THROW_HIT_RADIUS = GameConfig.BurntThrowHitRadius or 3.2
local RAGDOLL_DURATION = GameConfig.BurntRagdollDurationSeconds or 2.0
local TARGET_IMMUNITY = GameConfig.BurntTargetImmunitySeconds or 8.0
local SPAWN_PROTECTION = GameConfig.BurntSpawnProtectionSeconds or 5.0
local PAIR_HARASSMENT_COOLDOWN = GameConfig.BurntPairHarassmentCooldownSeconds or 10.0

local COMEDY_HIT_BARKS = {
    "BLETAK! Kena Gorengan Gosong!",
    "PAIT BANGET! Gosong maksimal!",
    "DUAR! Bakwan arang mendarat!",
    "KENA DEH! Bau sangit!",
    "ASTAGA! Gorengan gosong melayang!",
}

local COMEDY_MISS_BARKS = {
    "BLETAK!",
    "PLOK!",
    "KREK!",
    "MELESET!",
}

type RagdollBackup = {
    Token: number,
    DisabledMotors: { Motor6D },
    DisabledAnimConstraints: { AnimationConstraint },
    CreatedInstances: { Instance },
}

local ThrowableService = {
    Name = "ThrowableService",
    _equippedPlayers = {} :: { [number]: { Equipped: boolean, RecipeId: string } },
    _lastThrowTime = {} :: { [number]: number },
    _targetImmunityUntil = {} :: { [number]: number },
    _pairThrowCooldowns = {} :: { [string]: number },
    _activeRagdolls = {} :: { [number]: RagdollBackup },
    _ragdollTokenCounter = 0,
    _spawnTimes = {} :: { [number]: number },
    _heldProps = {} :: { [number]: BasePart },
    _services = {} :: { [string]: any },
}

function ThrowableService:_getService(serviceName: string): any
    if not self._services[serviceName] then
        local servicesFolder = script and script.Parent
        local mod = if servicesFolder then servicesFolder:FindFirstChild(serviceName) else nil
        if mod then
            self._services[serviceName] = require(mod)
        end
    end
    return self._services[serviceName]
end

local function isValidDirection(vec: any): boolean
    if typeof(vec) ~= "Vector3" then
        return false
    end
    -- Tolak NaN atau Infinity
    if vec.X ~= vec.X or vec.Y ~= vec.Y or vec.Z ~= vec.Z then
        return false
    end
    if math.abs(vec.X) == math.huge or math.abs(vec.Y) == math.huge or math.abs(vec.Z) == math.huge then
        return false
    end
    if vec.Magnitude < 0.01 then
        return false
    end
    return true
end

function ThrowableService:Init()
    log:Info("Menginisialisasi ThrowableService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_onPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self:_onPlayerRemoving(player)
    end)

    for _, player in Players:GetPlayers() do
        self:_onPlayerAdded(player)
    end

    -- RemoteFunction: Mengambil / Membekali gorengan gosong
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestEquipBurntFood, function(player: Player, recipeId: any)
        if recipeId ~= nil and (typeof(recipeId) ~= "string" or #recipeId > 40) then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:HandleEquipBurntFood(player, recipeId)
    end)

    -- RemoteFunction: Melempar gorengan gosong
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestThrowBurntFood, function(player: Player, aimDirection: any, recipeId: any)
        if recipeId ~= nil and (typeof(recipeId) ~= "string" or #recipeId > 40) then
            return { Success = false, Error = "ID resep tidak valid!" }
        end
        return self:HandleThrowBurntFood(player, aimDirection, recipeId)
    end)
end

function ThrowableService:Start()
    self:_getService("InventoryService")
    self:_getService("CartService")
    self:_getService("SatpolService")
    log:Info("ThrowableService aktif dengan validasi server & proteksi anti-griefing.")
end

function ThrowableService:_onPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function(char: Model)
        self._spawnTimes[player.UserId] = os.clock()
        self:UnequipBurntFood(player)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                self:UnequipBurntFood(player)
            end)
        end
    end)
    if player.Character then
        self._spawnTimes[player.UserId] = os.clock()
    end
end

function ThrowableService:_onPlayerRemoving(player: Player)
    local userId = player.UserId
    self._equippedPlayers[userId] = nil
    self._lastThrowTime[userId] = nil
    self._targetImmunityUntil[userId] = nil
    self._activeRagdolls[userId] = nil
    self._spawnTimes[userId] = nil

    local prefix = tostring(userId) .. "_"
    local suffix = "_" .. tostring(userId)
    for key in pairs(self._pairThrowCooldowns) do
        if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then
            self._pairThrowCooldowns[key] = nil
        end
    end

    local prop = self._heldProps[userId]
    if prop then
        prop:Destroy()
        self._heldProps[userId] = nil
    end
end

function ThrowableService:IsPlayerRagdolled(player: Player): boolean
    return self._activeRagdolls[player.UserId] ~= nil
end

function ThrowableService:_attachHeldProp(player: Player)
    self:_removeHeldProp(player)
    local char = player.Character
    if not char then return end

    local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart")
    if not hand or not hand:IsA("BasePart") then return end

    local prop = Instance.new("Part")
    prop.Name = "HeldBurntGorengan"
    prop.Size = Vector3.new(0.85, 0.35, 0.85)
    prop.Color = Color3.fromRGB(32, 26, 24)
    prop.Material = Enum.Material.Slate
    prop.CanCollide = false
    prop.Massless = true
    prop.CFrame = hand.CFrame * CFrame.new(0, -0.35, -0.25)

    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "BurntSmoke"
    smoke.Color = ColorSequence.new(Color3.fromRGB(45, 45, 45))
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.6) })
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.0) })
    smoke.Rate = 8
    smoke.Speed = NumberRange.new(0.8, 1.8)
    smoke.Lifetime = NumberRange.new(0.6, 1.1)
    smoke.Parent = prop

    prop.Parent = char

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hand
    weld.Part1 = prop
    weld.Parent = prop

    self._heldProps[player.UserId] = prop
end

function ThrowableService:_removeHeldProp(player: Player)
    local prop = self._heldProps[player.UserId]
    if prop then
        prop:Destroy()
        self._heldProps[player.UserId] = nil
    end
end

function ThrowableService:HandleEquipBurntFood(player: Player, preferredRecipeId: string?): { Success: boolean, Equipped: boolean?, TotalBurnt: number?, Error: string? }
    local userId = player.UserId
    local invService = self:_getService("InventoryService")
    if not invService then
        return { Success = false, Error = "Layanan inventaris tidak tersedia!" }
    end

    local totalBurnt = invService:GetTotalBurntCount(player)
    local current = self._equippedPlayers[userId]

    -- Toggle lepas jika sudah memegang
    if current and current.Equipped then
        self:UnequipBurntFood(player)
        return { Success = true, Equipped = false, TotalBurnt = totalBurnt }
    end

    if totalBurnt < 1 then
        return { Success = false, Equipped = false, TotalBurnt = 0, Error = "Kamu belum punya gorengan gosong! Masak sampai gosong (>80%) terlebih dahulu." }
    end

    local cartService = self:_getService("CartService")
    if cartService and cartService:IsPushing(player) then
        return { Success = false, Equipped = false, TotalBurnt = totalBurnt, Error = "Lepaskan dorongan gerobak sebelum mengambil gorengan gosong!" }
    end

    local recipeId = preferredRecipeId or "bakwan_sayur"
    self._equippedPlayers[userId] = { Equipped = true, RecipeId = recipeId }
    self:_attachHeldProp(player)

    NetworkBridge.FireClient(player, Remotes.Events.BurntFoodEquippedChanged, true, recipeId, totalBurnt)
    log:Info("Pemain %s mengambil gorengan gosong ke tangan (Stok: %d)", player.Name, totalBurnt)

    return { Success = true, Equipped = true, TotalBurnt = totalBurnt }
end

function ThrowableService:UnequipBurntFood(player: Player)
    local userId = player.UserId
    local wasEquipped = self._equippedPlayers[userId] ~= nil
    self._equippedPlayers[userId] = nil
    self:_removeHeldProp(player)

    if wasEquipped then
        local invService = self:_getService("InventoryService")
        local totalBurnt = if invService then invService:GetTotalBurntCount(player) else 0
        NetworkBridge.FireClient(player, Remotes.Events.BurntFoodEquippedChanged, false, nil, totalBurnt)
    end
end

function ThrowableService:HandleThrowBurntFood(player: Player, aimDirection: any, preferredRecipeId: string?): { Success: boolean, Error: string?, ThrowId: string?, RemainingBurnt: number?, CooldownRemaining: number? }
    local userId = player.UserId

    -- 1. Validasi payload tipe & batas vektor
    if not isValidDirection(aimDirection) then
        log:Warn("Payload aimDirection tidak valid dari pemain %s", player.Name)
        return { Success = false, Error = "Arah lemparan tidak valid!" }
    end

    -- 2. Validasi karakter hidup & tidak sedang ragdoll / dorong gerobak
    local char = player.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if not char or not hrp or not humanoid or humanoid.Health <= 0 then
        return { Success = false, Error = "Karakter tidak dapat melempar saat ini!" }
    end

    if self:IsPlayerRagdolled(player) then
        return { Success = false, Error = "Kamu masih sempoyongan terkena gorengan gosong!" }
    end

    local cartService = self:_getService("CartService")
    if cartService and cartService:IsPushing(player) then
        return { Success = false, Error = "Lepaskan gerobak terlebih dahulu sebelum melempar!" }
    end

    -- 3. Validasi Cooldown server-side (anti-spam)
    local now = os.clock()
    local lastThrow = self._lastThrowTime[userId] or 0
    local elapsed = now - lastThrow
    if elapsed < THROW_COOLDOWN then
        local remaining = THROW_COOLDOWN - elapsed
        return {
            Success = false,
            Error = string.format("Tunggu %.1f detik sebelum melempar lagi!", remaining),
            CooldownRemaining = remaining,
        }
    end

    -- 4. Validasi kepemilikan item & pemotongan stok atomik di server
    local invService = self:_getService("InventoryService")
    if not invService then
        return { Success = false, Error = "Layanan inventaris tidak aktif!" }
    end

    local equippedState = self._equippedPlayers[userId]
    local targetRecipe = preferredRecipeId or (if equippedState then equippedState.RecipeId else nil)
    local consumed, usedRecipeId = invService:ConsumeAnyBurntFood(player, targetRecipe)
    if not consumed then
        self:UnequipBurntFood(player)
        return { Success = false, Error = "Stok gorengan gosong kosong! Masak gorengan hingga gosong (>80%) dulu." }
    end

    -- 5. Catat cooldown & hitung posisi awal otoritatif dari posisi karakter di server
    self._lastThrowTime[userId] = now
    local remainingBurnt = invService:GetTotalBurntCount(player)
    if remainingBurnt <= 0 then
        self:UnequipBurntFood(player)
    elseif equippedState then
        NetworkBridge.FireClient(player, Remotes.Events.BurntFoodEquippedChanged, true, equippedState.RecipeId, remainingBurnt)
    end

    local unitDir = (aimDirection :: Vector3).Unit
    local origin = hrp.Position + Vector3.new(0, 1.4, 0) + (unitDir * 2.2)
    local initialVelocity = (unitDir * THROW_SPEED) + Vector3.new(0, 8, 0)
    local throwId = HttpService:GenerateGUID(false)

    log:Info("Pemain %s melempar gorengan gosong '%s' (ThrowId: %s, Sisa: %d)", player.Name, tostring(usedRecipeId), throwId, remainingBurnt)

    -- 6. Siarkan visual peluncuran proyektil ke semua client
    NetworkBridge.FireAllClients(
        Remotes.Events.BurntFoodThrown,
        throwId,
        userId,
        origin,
        initialVelocity,
        THROW_GRAVITY,
        usedRecipeId or "bakwan_sayur"
    )

    -- 7. Jalankan simulasi lintasan & deteksi tumbukan otoritatif di server
    task.spawn(function()
        self:_simulateProjectile(throwId, player, origin, initialVelocity)
    end)

    return {
        Success = true,
        ThrowId = throwId,
        RemainingBurnt = remainingBurnt,
    }
end

function ThrowableService:_findPlayerFromHit(hitInstance: Instance): Player?
    local current: Instance? = hitInstance
    while current and current ~= Workspace do
        if current:IsA("Model") then
            local targetPlayer = Players:GetPlayerFromCharacter(current)
            if targetPlayer then
                return targetPlayer
            end
        end
        current = current.Parent
    end
    return nil
end

function ThrowableService:_checkProximityPlayerHit(thrower: Player, segmentStart: Vector3, segmentEnd: Vector3): (Player?, Vector3?)
    local segment = segmentEnd - segmentStart
    local segLenSq = segment.X * segment.X + segment.Y * segment.Y + segment.Z * segment.Z

    for _, candidate in Players:GetPlayers() do
        if candidate ~= thrower and candidate.Character then
            local hrp = candidate.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = candidate.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                -- Proyeksi titik HRP ke segmen lintasan
                local t = 0
                if segLenSq > 0.0001 then
                    t = math.clamp((hrp.Position - segmentStart):Dot(segment) / segLenSq, 0, 1)
                end
                local closestPoint = segmentStart + (segment * t)
                if (hrp.Position - closestPoint).Magnitude <= THROW_HIT_RADIUS then
                    return candidate, closestPoint
                end
            end
        end
    end

    return nil, nil
end

function ThrowableService:_simulateProjectile(throwId: string, thrower: Player, origin: Vector3, initialVelocity: Vector3)
    local pos = origin
    local vel = initialVelocity
    local dt = 0.03
    local maxFlightTime = 2.0
    local elapsed = 0
    local totalTraveled = 0

    local cartService = self:_getService("CartService")
    local throwerCart = if cartService then cartService:GetPlayerCart(thrower) else nil

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList: { Instance } = {}
    if thrower.Character then table.insert(ignoreList, thrower.Character) end
    if throwerCart then table.insert(ignoreList, throwerCart) end
    rayParams.FilterDescendantsInstances = ignoreList

    while elapsed < maxFlightTime and totalTraveled < THROW_MAX_DISTANCE do
        local nextPos = pos + (vel * dt)
        local segment = nextPos - pos
        local segDist = segment.Magnitude

        -- 1. Raycast terlebih dahulu (anti-tembus tembok)
        local hitResult = Workspace:Raycast(pos, segment, rayParams)
        local hitPos = if hitResult then hitResult.Position else nextPos

        -- 2. Cek apakah mengenai karakter pemain di segmen yang tidak terhalang tembok
        if hitResult and hitResult.Instance then
            local hitPlayer = self:_findPlayerFromHit(hitResult.Instance)
            if hitPlayer and hitPlayer ~= thrower then
                self:_handlePlayerHit(throwId, thrower, hitPlayer, hitResult.Position, vel.Unit)
                return
            elseif hitResult.Instance.CanCollide or (hitResult.Instance.Parent and hitResult.Instance.Parent:IsA("Model")) then
                local eventService = self:_getService("EventService")
                if eventService and eventService.OnNpcHitByBurntFood and eventService:OnNpcHitByBurntFood(hitResult.Instance, thrower) then
                    NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitResult.Position, nil, "BLETAK! AMPUN!")
                    return
                end

                if hitResult.Instance.CanCollide then
                    local proxPlayer, proxPos = self:_checkProximityPlayerHit(thrower, pos, hitPos)
                    if proxPlayer and proxPos then
                        self:_handlePlayerHit(throwId, thrower, proxPlayer, proxPos, vel.Unit)
                        return
                    end

                    local missBark = COMEDY_MISS_BARKS[math.random(1, #COMEDY_MISS_BARKS)]
                    NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitResult.Position, nil, missBark)
                    return
                end
            end
        else
            local proxPlayer, proxPos = self:_checkProximityPlayerHit(thrower, pos, nextPos)
            if proxPlayer and proxPos then
                self:_handlePlayerHit(throwId, thrower, proxPlayer, proxPos, vel.Unit)
                return
            end
        end

        pos = nextPos
        vel = vel - Vector3.new(0, THROW_GRAVITY * dt, 0)
        elapsed += dt
        totalTraveled += segDist
        task.wait(dt)
    end

    -- Jika mencapai batas jarak maksimum (55 studs) tanpa benturan
    NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, pos, nil, "PLOK!")
end

function ThrowableService:_handlePlayerHit(throwId: string, thrower: Player, target: Player, hitPosition: Vector3, pushDirection: Vector3)
    if target == thrower then return end

    local targetId = target.UserId
    local now = os.clock()

    -- 1. Cek perlindungan Safe Zone
    local satpolService = self:_getService("SatpolService")
    if satpolService and satpolService.IsPositionInSafeZone and satpolService:IsPositionInSafeZone(hitPosition) then
        log:Info("Lemparan %s mengenai %s di dalam Safe Zone (dilindungi dari ragdoll).", thrower.Name, target.Name)
        NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitPosition, targetId, "🛡️ AMAN DI GANG!")
        return
    end

    -- 2. Cek Spawn Protection (5 detik pasca spawn)
    local spawnTime = self._spawnTimes[targetId] or 0
    if (now - spawnTime) < SPAWN_PROTECTION then
        NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitPosition, targetId, "🛡️ BARU SPAWN!")
        return
    end

    -- 3. Cek Target Immunity Cooldown & Anti-Harassment Per-Pasangan (anti-stunlock / anti-griefing)
    local immuneUntil = self._targetImmunityUntil[targetId] or 0
    if now < immuneUntil then
        NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitPosition, targetId, "😵 MASIH KEBAL!")
        return
    end

    local pairKey = tostring(thrower.UserId) .. "_" .. tostring(targetId)
    local pairUntil = self._pairThrowCooldowns[pairKey] or 0
    if now < pairUntil then
        NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitPosition, targetId, "🛡️ COOLDOWN TARGET!")
        return
    end
    self._pairThrowCooldowns[pairKey] = now + PAIR_HARASSMENT_COOLDOWN

    -- 4. Terapkan Ragdoll Sementara!
    local bark = COMEDY_HIT_BARKS[math.random(1, #COMEDY_HIT_BARKS)]
    self:ApplyTemporaryRagdoll(target, pushDirection)
    NetworkBridge.FireAllClients(Remotes.Events.BurntFoodImpact, throwId, hitPosition, targetId, bark)
    log:Info("HIT! %s melempar gorengan gosong tepat mengenai %s -> Ragdoll %.1fs", thrower.Name, target.Name, RAGDOLL_DURATION)
end

function ThrowableService:ApplyTemporaryRagdoll(target: Player, pushDirection: Vector3?): boolean
    local char = target.Character
    local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if not char or not hrp or not humanoid or humanoid.Health <= 0 then
        return false
    end

    local userId = target.UserId
    local now = os.clock()

    -- Cek lagi apakah target sedang kebal atau baru di-ragdoll
    if self._activeRagdolls[userId] or now < (self._targetImmunityUntil[userId] or 0) then
        return false
    end

    -- Hentikan dorongan gerobak secara aman agar gerobak tidak terseret/nyangkut
    local cartService = self:_getService("CartService")
    if cartService and cartService.IsPushing and cartService:IsPushing(target) then
        cartService:StopPushCart(target)
    end

    self._ragdollTokenCounter += 1
    local token = self._ragdollTokenCounter
    self._targetImmunityUntil[userId] = now + RAGDOLL_DURATION + TARGET_IMMUNITY

    local disabledMotors: { Motor6D } = {}
    local disabledAnimConstraints: { AnimationConstraint } = {}
    local createdInstances: { Instance } = {}

    -- Konversi sementara sendi untuk Ragdoll (mendukung rig modern AnimationConstraint & klasik Motor6D)
    for _, desc in char:GetDescendants() do
        if desc:IsA("AnimationConstraint") then
            if desc.Name == "Root" or desc.Name == "Neck" then
                continue
            end
            if desc.Enabled then
                desc.Enabled = false
                table.insert(disabledAnimConstraints, desc)
            end
        elseif desc:IsA("Motor6D") and desc.Part0 and desc.Part1 then
            if desc.Name == "Root" or desc.Name == "RootJoint" or desc.Name == "Neck" then
                continue
            end

            local att0 = Instance.new("Attachment")
            att0.Name = "RagdollAtt0"
            att0.CFrame = desc.C0
            att0.Parent = desc.Part0

            local att1 = Instance.new("Attachment")
            att1.Name = "RagdollAtt1"
            att1.CFrame = desc.C1
            att1.Parent = desc.Part1

            local socket = Instance.new("BallSocketConstraint")
            socket.Name = "RagdollSocket"
            socket.Attachment0 = att0
            socket.Attachment1 = att1
            socket.LimitsEnabled = true
            socket.TwistLimitsEnabled = true
            socket.UpperAngle = 60
            socket.Parent = desc.Part0

            table.insert(createdInstances, att0)
            table.insert(createdInstances, att1)
            table.insert(createdInstances, socket)

            desc.Enabled = false
            table.insert(disabledMotors, desc)
        end
    end

    self._activeRagdolls[userId] = {
        Token = token,
        DisabledMotors = disabledMotors,
        DisabledAnimConstraints = disabledAnimConstraints,
        CreatedInstances = createdInstances,
    }

    humanoid.PlatformStand = true
    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)

    -- Dorongan komedi ringan
    if pushDirection and not hrp.Anchored then
        local dir = Vector3.new(pushDirection.X, 0, pushDirection.Z)
        local flatDir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, 1)
        pcall(function()
            hrp:ApplyImpulse((flatDir * 24 + Vector3.new(0, 16, 0)) * hrp.AssemblyMass)
        end)
    end

    NetworkBridge.FireAllClients(Remotes.Events.PlayerRagdollStateChanged, userId, true, RAGDOLL_DURATION)

    -- Jadwalkan pemulihan otomatis setelah durasi singkat (2 detik)
    task.delay(RAGDOLL_DURATION, function()
        self:RestoreFromRagdoll(target, token)
    end)

    return true
end

function ThrowableService:RestoreFromRagdoll(target: Player, expectedToken: number?)
    local userId = target.UserId
    local backup = self._activeRagdolls[userId]
    if not backup then return end
    if expectedToken and backup.Token ~= expectedToken then return end

    self._activeRagdolls[userId] = nil

    if target.Parent ~= Players then
        return
    end

    for _, inst in backup.CreatedInstances do
        if inst and inst.Parent then
            inst:Destroy()
        end
    end

    for _, motor in backup.DisabledMotors do
        if motor and motor.Parent then
            motor.Enabled = true
        end
    end

    for _, animCon in backup.DisabledAnimConstraints do
        if animCon and animCon.Parent then
            animCon.Enabled = true
        end
    end

    local char = target.Character
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if humanoid then
        humanoid.PlatformStand = false
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    NetworkBridge.FireAllClients(Remotes.Events.PlayerRagdollStateChanged, userId, false, 0)
    log:Info("Pemain %s bangkit kembali dari efek ragdoll gorengan gosong.", target.Name)
end

return ThrowableService