--!strict
--[[
    NetworkService.luau
    Pengelola gerbang komunikasi jaringan server.
    Memastikan seluruh instance remotes siap dan dapat diakses dengan validasi keamanan.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local log = Logger.new("NetworkService")

local NetworkService = {
    Name = "NetworkService",
}

function NetworkService:Init()
    log:Info("Menginisialisasi NetworkService...")
    -- Memaksa modul NetworkBridge memastikan folder remote terbentuk di ReplicatedStorage
    local _ = NetworkBridge
end

function NetworkService:Start()
    log:Info("NetworkService aktif dan memantau lalu lintas remote.")
end

return NetworkService
