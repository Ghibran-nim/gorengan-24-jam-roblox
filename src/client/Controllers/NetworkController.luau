--!strict
--[[
    NetworkController.luau
    Wrapper client untuk mempermudah pemanggilan fungsi dan pengiriman event ke server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local log = Logger.new("NetworkController")

local NetworkController = {
    Name = "NetworkController",
}

function NetworkController:Init()
    log:Info("Menginisialisasi NetworkController...")
    -- Memastikan NetworkBridge client berhasil tertaut dengan NetworkRemotes server
    local _ = NetworkBridge
end

function NetworkController:Start()
    log:Info("NetworkController aktif.")
end

function NetworkController:RequestStartCooking(recipeId: string): any
    log:Debug("Mengirim permintaan mulai memasak: %s", recipeId)
    return NetworkBridge.InvokeServer(Remotes.Functions.RequestStartCooking, recipeId)
end

function NetworkController:RequestCollectFood(): any
    log:Debug("Mengirim permintaan mengangkat makanan dari wajan")
    return NetworkBridge.InvokeServer(Remotes.Functions.RequestCollectFood)
end

function NetworkController:RequestDepositATM(amount: number): any
    log:Debug("Mengirim permintaan setor ATM: Rp %d", amount)
    return NetworkBridge.InvokeServer(Remotes.Functions.RequestDepositATM, amount)
end

function NetworkController:RequestWithdrawATM(amount: number): any
    log:Debug("Mengirim permintaan tarik ATM: Rp %d", amount)
    return NetworkBridge.InvokeServer(Remotes.Functions.RequestWithdrawATM, amount)
end

return NetworkController
