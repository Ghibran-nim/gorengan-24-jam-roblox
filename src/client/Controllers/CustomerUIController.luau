--!strict
--[[
    CustomerUIController.luau
    Mengelola feedback client saat pelanggan memesan dan membayar gorengan.
    Menampilkan notifikasi transaksi sukses, bonus tips, dan tombol sentuh sajikan pesanan untuk perangkat mobile.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Controller = GameplayTypes.Controller

local log = Logger.new("CustomerUIController")

local CustomerUIController = {
    Name = "CustomerUIController",
}

function CustomerUIController:Init()
    log:Info("Menginisialisasi CustomerUIController...")

    -- Dengarkan notifikasi transaksi penjualan berhasil
    NetworkBridge.OnClientEvent(Remotes.Events.CustomerOrderCompleted, function(customerId: string, payout: number, quality: string)
        log:Info("Transaksi selesai untuk %s -> Terima Rp %d (%s)", customerId, payout, quality)

        local HUDController = require(script.Parent:WaitForChild("HUDController"))
        if HUDController and (HUDController :: any).ShowToastNotification then
            local icon = if quality == "Crispy" then "✨" else "⚠️"
            local message = string.format("%s Terjual! +Rp %d (%s)", icon, payout, quality:upper())
            local hud = HUDController :: any
            hud:ShowToastNotification(message, if quality == "Crispy" then "Success" else "Warning")
        end
    end)
end

function CustomerUIController:Start()
    log:Info("CustomerUIController aktif.")
end

return CustomerUIController
