--!strict
--[[
    NetworkBridge.luau
    Abstraksi lapisan jaringan terpadu untuk Client dan Server.
    Mencakup pembuatan instance otomatis di server, bounded-wait di client,
    serta validasi jarak fisik dan rate-limiting per pemain.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remotes = require(script.Parent:WaitForChild("Remotes"))
local GameConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("GameConfig"))
local Logger = require(script.Parent.Parent:WaitForChild("Utility"):WaitForChild("Logger"))

local log = Logger.new("NetworkBridge")

local isServer = RunService:IsServer()
local remotesFolder: Folder

-- Rate limiting data structures (Server-only)
local playerRateLimits: { [number]: { count: number, resetTime: number } } = {}

if isServer then
    Players.PlayerRemoving:Connect(function(player: Player)
        playerRateLimits[player.UserId] = nil
    end)
end

local NetworkBridge = {}

-- Inisialisasi folder remotes
local function getRemotesFolder(): Folder
    if remotesFolder then
        return remotesFolder
    end

    if isServer then
        local existing = ReplicatedStorage:FindFirstChild(GameConfig.RemotesFolderName)
        if existing and existing:IsA("Folder") then
            remotesFolder = existing
        else
            local newFolder = Instance.new("Folder")
            newFolder.Name = GameConfig.RemotesFolderName
            newFolder.Parent = ReplicatedStorage
            remotesFolder = newFolder
        end

        -- Buat seluruh RemoteEvent yang didefinisikan
        for _, eventName in pairs(Remotes.Events) do
            if not remotesFolder:FindFirstChild(eventName) then
                local event = Instance.new("RemoteEvent")
                event.Name = eventName
                event.Parent = remotesFolder
            end
        end

        -- Buat seluruh RemoteFunction yang didefinisikan
        for _, funcName in pairs(Remotes.Functions) do
            if not remotesFolder:FindFirstChild(funcName) then
                local func = Instance.new("RemoteFunction")
                func.Name = funcName
                func.Parent = remotesFolder
            end
        end

        log:Info("Server network remotes successfully initialized in ReplicatedStorage.")
    else
        local found = ReplicatedStorage:WaitForChild(GameConfig.RemotesFolderName, 10)
        assert(found and found:IsA("Folder"), "Client timed out waiting for NetworkRemotes in ReplicatedStorage")
        remotesFolder = found
        log:Info("Client network remotes linked successfully.")
    end

    return remotesFolder
end

-- ============================================================================
-- HELPER VALIDASI KEAMANAN (SERVER-ONLY)
-- ============================================================================

local function checkRateLimit(player: Player): boolean
    local userId = player.UserId
    local now = os.clock()
    local bucket = playerRateLimits[userId]

    if not bucket or now >= bucket.resetTime then
        playerRateLimits[userId] = { count = 1, resetTime = now + 1.0 }
        return true
    end

    bucket.count += 1
    if bucket.count > GameConfig.RateLimitRequestsPerSecond then
        log:Warn("Player %s (%d) exceeded network rate limit (%d req/s)", player.Name, userId, bucket.count)
        return false
    end

    return true
end

function NetworkBridge.ValidatePlayerDistance(player: Player, targetPosition: Vector3, maxDistanceOverride: number?): boolean
    local character = player.Character
    if not character then
        return false
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return false
    end

    local maxDist = maxDistanceOverride or GameConfig.InteractionMaxDistance
    local distance = (root.Position - targetPosition).Magnitude
    return distance <= maxDist
end

function NetworkBridge.IsFiniteNumber(v: any): boolean
    return typeof(v) == "number" and v == v and math.abs(v) < math.huge
end

function NetworkBridge.IsFiniteVector3(v: any): boolean
    if typeof(v) ~= "Vector3" then
        return false
    end
    return NetworkBridge.IsFiniteNumber(v.X) and NetworkBridge.IsFiniteNumber(v.Y) and NetworkBridge.IsFiniteNumber(v.Z)
end

function NetworkBridge.IsAuthorizedAdmin(player: Player): boolean
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return false
    end
    if RunService:IsStudio() then
        return true
    end
    return game.CreatorId > 0 and player.UserId == game.CreatorId
end

-- ============================================================================
-- SERVER-SIDE API
-- ============================================================================

function NetworkBridge.RegisterServerEvent(eventName: string, callback: (player: Player, ...any) -> ())
    assert(isServer, "RegisterServerEvent can only be called on the Server")
    local folder = getRemotesFolder()
    local remote = folder:WaitForChild(eventName, 5)
    assert(remote and remote:IsA("RemoteEvent"), "RemoteEvent not found: " .. eventName)

    remote.OnServerEvent:Connect(function(player: Player, ...: any)
        if not checkRateLimit(player) then
            return
        end

        local success, err = pcall(callback, player, ...)
        if not success then
            log:Error("Error handling event '%s' from %s: %s", eventName, player.Name, tostring(err))
        end
    end)
end

function NetworkBridge.RegisterServerFunction(functionName: string, handler: (player: Player, ...any) -> any)
    assert(isServer, "RegisterServerFunction can only be called on the Server")
    local folder = getRemotesFolder()
    local remote = folder:WaitForChild(functionName, 5)
    assert(remote and remote:IsA("RemoteFunction"), "RemoteFunction not found: " .. functionName)

    remote.OnServerInvoke = function(player: Player, ...: any)
        if not checkRateLimit(player) then
            return { Success = false, Error = "Rate limit exceeded" }
        end

        local success, result = pcall(handler, player, ...)
        if success then
            return result
        else
            log:Error("Error invoking function '%s' from %s: %s", functionName, player.Name, tostring(result))
            return { Success = false, Error = "Internal server error" }
        end
    end
end

function NetworkBridge.FireClient(player: Player, eventName: string, ...: any)
    assert(isServer, "FireClient can only be called on the Server")
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return
    end
    local folder = getRemotesFolder()
    local remote = folder:FindFirstChild(eventName)
    if remote and remote:IsA("RemoteEvent") then
        remote:FireClient(player, ...)
    else
        log:Warn("Cannot FireClient: RemoteEvent '%s' not found", eventName)
    end
end

function NetworkBridge.FireAllClients(eventName: string, ...: any)
    assert(isServer, "FireAllClients can only be called on the Server")
    local folder = getRemotesFolder()
    local remote = folder:FindFirstChild(eventName)
    if remote and remote:IsA("RemoteEvent") then
        remote:FireAllClients(...)
    else
        log:Warn("Cannot FireAllClients: RemoteEvent '%s' not found", eventName)
    end
end

-- ============================================================================
-- CLIENT-SIDE API
-- ============================================================================

function NetworkBridge.FireServer(eventName: string, ...: any)
    assert(not isServer, "FireServer can only be called on the Client")
    local folder = getRemotesFolder()
    local remote = folder:FindFirstChild(eventName)
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    else
        log:Warn("Cannot FireServer: RemoteEvent '%s' not found", eventName)
    end
end

function NetworkBridge.InvokeServer(functionName: string, ...: any): any
    assert(not isServer, "InvokeServer can only be called on the Client")
    local folder = getRemotesFolder()
    local remote = folder:FindFirstChild(functionName)
    if remote and remote:IsA("RemoteFunction") then
        local success, result = pcall(remote.InvokeServer, remote, ...)
        if success then
            return result
        else
            log:Error("InvokeServer failed for '%s': %s", functionName, tostring(result))
            return { Success = false, Error = tostring(result) }
        end
    else
        log:Warn("Cannot InvokeServer: RemoteFunction '%s' not found", functionName)
        return { Success = false, Error = "RemoteFunction not found" }
    end
end

function NetworkBridge.OnClientEvent(eventName: string, callback: (...any) -> ())
    assert(not isServer, "OnClientEvent can only be called on the Client")
    local folder = getRemotesFolder()
    local remote = folder:WaitForChild(eventName, 5)
    if remote and remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(callback)
    else
        log:Warn("Cannot listen to OnClientEvent: RemoteEvent '%s' not found", eventName)
    end
end

-- Cleanup pemain saat keluar untuk mencegah kebocoran memori (Server-side)
if isServer then
    Players.PlayerRemoving:Connect(function(player)
        playerRateLimits[player.UserId] = nil
    end)
end

-- Pastikan remotes folder terbentuk saat modul pertama kali di-require
getRemotesFolder()

return NetworkBridge
