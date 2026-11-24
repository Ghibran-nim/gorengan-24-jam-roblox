--!strict
--[[
    GameController.luau
    Koordinator global status client dan siklus hidup antarmuka pemain lokal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("GameController")

local GameController = {
    Name = "GameController",
}

function GameController:Init()
    log:Info("Menginisialisasi GameController...")

    -- Dengarkan notifikasi umum dari server
    NetworkBridge.OnClientEvent(Remotes.Events.NotificationFired, function(message: string, alertType: string?)
        log:Info("Notifikasi Server [%s]: %s", alertType or "INFO", message)
    end)

    -- Dengarkan peringatan razia Satpol PP
    NetworkBridge.OnClientEvent(Remotes.Events.RaidAlert, function(state: string, timeRemaining: number)
        log:Warn("PERINGATAN RAZIA: Status '%s' (Sisa waktu: %d detik)!", state, timeRemaining)
    end)
end

function GameController:Start()
    log:Info("GameController aktif.")
end

return GameController
