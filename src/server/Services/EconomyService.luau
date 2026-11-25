--!strict
--[[
    EconomyService.luau
    Layanan otoritatif server untuk mengelola kas pedagang (CarriedCash),
    tabungan aman di ATM (BankedCash), pembelian bahan baku di toko,
    serta pembelian upgrade gerobak dan peralatan.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local UpgradesConfig = require(Shared:WaitForChild("Config"):WaitForChild("UpgradesConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type PlayerEconomyData = GameplayTypes.PlayerEconomyData

local log = Logger.new("EconomyService")

local EconomyService = {
    Name = "EconomyService",
    _playerWallets = {} :: { [number]: PlayerEconomyData },
    _playerUpgrades = {} :: { [number]: { [string]: boolean } },
    _services = {} :: { [string]: any },
}

function EconomyService:Init()
    log:Info("Menginisialisasi EconomyService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupPlayerEconomy(player)
    end)

    for _, player in Players:GetPlayers() do
        self:_setupPlayerEconomy(player)
    end

    -- 1. Handler Beli Bahan Baku Toko
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestBuyIngredient, function(player: Player, packId: string)
        return self:BuyIngredient(player, packId)
    end)

    -- 2. Handler Beli Upgrade
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestBuyUpgrade, function(player: Player, upgradeId: string)
        return self:BuyUpgrade(player, upgradeId)
    end)

    -- 3. Handler Meminta Daftar Upgrade
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetUpgrades, function(player: Player)
        local owned = self._playerUpgrades[player.UserId] or {}
        return { Success = true, Upgrades = owned }
    end)

    -- 4. Handler Setor ATM
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestDepositATM, function(player: Player, amount: number)
        return self:DepositToATM(player, amount)
    end)

    -- 5. Handler Tarik ATM
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestWithdrawATM, function(player: Player, amount: number)
        return self:WithdrawFromATM(player, amount)
    end)
end

function EconomyService:Start()
    local Server = script.Parent
    self._services.InventoryService = require(Server:WaitForChild("InventoryService"))
    local tsMod = Server:FindFirstChild("TutorialService")
    if tsMod then
        self._services.TutorialService = require(tsMod)
    end
    local progMod = Server:FindFirstChild("ProgressionService")
    if progMod then
        self._services.ProgressionService = require(progMod)
    end
    local cartMod = Server:FindFirstChild("CartService")
    if cartMod then
        self._services.CartService = require(cartMod)
    end
    local custMod = Server:FindFirstChild("CustomerService")
    if custMod then
        self._services.CustomerService = require(custMod)
    end
    local dataMod = Server:FindFirstChild("DataService")
    if dataMod then
        local dataService = require(dataMod)
        self._services.DataService = dataService
        dataService:RegisterDomain("Economy",
            function(player: Player, profile: any)
                local userId = player.UserId
                self._playerWallets[userId] = {
                    CarriedCash = profile.Economy.CarriedCash,
                    BankedCash = profile.Economy.BankedCash,
                    Reputation = profile.Economy.Reputation,
                }
                local upgrades = {}
                for upgId, owned in pairs(profile.Upgrades or {}) do
                    if owned == true then
                        upgrades[upgId] = true
                    end
                end
                self._playerUpgrades[userId] = upgrades
                self:SyncWalletToClient(player)
                self:SyncUpgradesToClient(player)

                local cartService = self._services.CartService
                if cartService and cartService.ApplyUpgradeVisuals then
                    for upgId, _ in pairs(upgrades) do
                        cartService:ApplyUpgradeVisuals(player, upgId)
                    end
                end
                if upgrades["kasir_npc"] then
                    local custService = self._services.CustomerService
                    if custService and custService.SpawnKasirForPlayer then
                        custService:SpawnKasirForPlayer(player)
                    end
                end
            end,
            function(player: Player, profile: any)
                local userId = player.UserId
                local wallet = self._playerWallets[userId]
                if wallet then
                    profile.Economy.CarriedCash = wallet.CarriedCash
                    profile.Economy.BankedCash = wallet.BankedCash
                    profile.Economy.Reputation = wallet.Reputation
                end
                local upg = self._playerUpgrades[userId]
                if upg then
                    profile.Upgrades = table.clone(upg)
                end
            end,
            function(userId: number)
                self._playerWallets[userId] = nil
                self._playerUpgrades[userId] = nil
            end
        )
    end
    log:Info("EconomyService aktif dan terhubung dengan InventoryService & ProgressionService.")
end

function EconomyService:_setupPlayerEconomy(player: Player)
    local userId = player.UserId
    if not self._playerWallets[userId] then
        self._playerWallets[userId] = {
            CarriedCash = EconomyConfig.StartingCarriedCash,
            BankedCash = EconomyConfig.StartingBankedCash,
            Reputation = EconomyConfig.StartingReputation,
        }
        self._playerUpgrades[userId] = {}
        log:Info("Ekonomi awal disiapkan untuk %s: Rp %d Kas | Rp %d Tabungan", player.Name, EconomyConfig.StartingCarriedCash, EconomyConfig.StartingBankedCash)
        self:SyncWalletToClient(player)
        self:SyncUpgradesToClient(player)
    end
end

function EconomyService:GetWallet(player: Player): PlayerEconomyData?
    if not self._playerWallets[player.UserId] then
        self:_setupPlayerEconomy(player)
    end
    return self._playerWallets[player.UserId]
end

function EconomyService:HasUpgrade(player: Player, upgradeId: string): boolean
    if not self._playerUpgrades[player.UserId] then
        self:_setupPlayerEconomy(player)
    end
    local upgrades = self._playerUpgrades[player.UserId]
    return if upgrades then (upgrades[upgradeId] == true) else false
end

function EconomyService:_notifySocialLeaderboard(player: Player)
    local Server = script and script.Parent
    local dataService = self._services.DataService
    if dataService and dataService.MarkDirty then
        dataService:MarkDirty(player, "EconomyChanged")
    end
    local socialMod = if Server then Server:FindFirstChild("SocialService") else nil
    if socialMod then
        local socialService = require(socialMod)
        if socialService and socialService.RefreshPlayerStats then
            socialService:RefreshPlayerStats(player)
            socialService:ScheduleLeaderboardBroadcast()
        end
    end
end

function EconomyService:SyncWalletToClient(player: Player)
    local wallet = self._playerWallets[player.UserId]
    if wallet then
        NetworkBridge.FireClient(player, Remotes.Events.PlayerEconomyUpdated, wallet.CarriedCash, wallet.BankedCash, wallet.Reputation)
        self:_notifySocialLeaderboard(player)
    end
end

function EconomyService:SyncUpgradesToClient(player: Player)
    local upgrades = self._playerUpgrades[player.UserId]
    if upgrades then
        NetworkBridge.FireClient(player, Remotes.Events.UpgradesUpdated, upgrades)
    end
end

function EconomyService:AddCarriedCash(player: Player, amount: number, reason: string): boolean
    if amount <= 0 then return false end
    local wallet = self._playerWallets[player.UserId]
    if not wallet then return false end

    wallet.CarriedCash += amount
    log:Info("Tambah Kas %s: +Rp %d (%s) -> Total: Rp %d", player.Name, amount, reason, wallet.CarriedCash)
    self:SyncWalletToClient(player)
    return true
end

function EconomyService:PenalizeCarriedCash(player: Player, penaltyPercent: number): number
    local wallet = self._playerWallets[player.UserId]
    if not wallet or wallet.CarriedCash <= 0 then return 0 end

    local pct = math.clamp(penaltyPercent, 0, 1)
    local penaltyAmount = math.floor(wallet.CarriedCash * pct)
    wallet.CarriedCash -= penaltyAmount

    log:Warn("PENALTI SATPOL: Kas %s disita %d%% (-Rp %d). Sisa Kas: Rp %d | Tabungan Bank AMAN: Rp %d", player.Name, pct * 100, penaltyAmount, wallet.CarriedCash, wallet.BankedCash)
    self:SyncWalletToClient(player)
    return penaltyAmount
end

function EconomyService:DeductCarriedCash(player: Player, amount: number, reason: string): boolean
    if amount <= 0 then return false end
    local wallet = self._playerWallets[player.UserId]
    if not wallet or wallet.CarriedCash < amount then return false end

    wallet.CarriedCash -= amount
    log:Info("Potong Kas %s: -Rp %d (%s) -> Sisa: Rp %d", player.Name, amount, reason, wallet.CarriedCash)
    self:SyncWalletToClient(player)
    return true
end

-- ============================================================================
-- TRANSAKSI TOKO BAHAN BAKU
-- ============================================================================

function EconomyService:BuyIngredient(player: Player, packId: any): { Success: boolean, Error: string?, NewCash: number?, PackName: string? }
    if typeof(packId) ~= "string" or #packId > 40 then
        return { Success = false, Error = "ID paket bahan tidak valid!" }
    end
    local pack = EconomyConfig.GetIngredientPack(packId)
    if not pack then
        return { Success = false, Error = "Paket bahan baku tidak valid!" }
    end

    local wallet = self._playerWallets[player.UserId]
    if not wallet then
        return { Success = false, Error = "Data dompet pemain tidak ditemukan!" }
    end

    if wallet.CarriedCash < pack.Price then
        return { Success = false, Error = string.format("Uang kas tidak cukup! Membutuhkan Rp %d (Kas kamu: Rp %d)", pack.Price, wallet.CarriedCash) }
    end

    local inventoryService = self._services.InventoryService
    if not inventoryService then
        return { Success = false, Error = "Layanan inventaris tidak aktif!" }
    end

    -- Tambah stok bahan ke inventaris
    local added = inventoryService:HandleTakeIngredients(player, pack.Id, pack.Amount)
    if not added or not added.Success then
        return { Success = false, Error = added and added.Error or "Gagal menambahkan stok bahan!" }
    end

    -- Potong uang kas secara atomik
    wallet.CarriedCash -= pack.Price
    log:Info("Beli Bahan: %s membeli %s seharga Rp %d (Sisa Kas: Rp %d)", player.Name, pack.Name, pack.Price, wallet.CarriedCash)
    self:SyncWalletToClient(player)

    return { Success = true, NewCash = wallet.CarriedCash, PackName = pack.Name }
end

-- ============================================================================
-- TRANSAKSI UPGRADE GEROBAK
-- ============================================================================

function EconomyService:BuyUpgrade(player: Player, upgradeId: any): { Success: boolean, Error: string?, NewCash: number?, UpgradeName: string? }
    if typeof(upgradeId) ~= "string" or #upgradeId > 40 then
        return { Success = false, Error = "ID upgrade tidak valid!" }
    end
    local upgrade = UpgradesConfig.GetUpgrade(upgradeId)
    if not upgrade then
        return { Success = false, Error = "Item upgrade tidak dikenali!" }
    end

    local userId = player.UserId
    local wallet = self:GetWallet(player)
    local owned = self._playerUpgrades[userId]

    if not wallet or not owned then
        return { Success = false, Error = "Data pemain tidak ditemukan!" }
    end

    if owned[upgradeId] then
        return { Success = false, Error = "Peningkatan ini sudah kamu miliki!" }
    end

    -- Validasi persyaratan Level
    local progService = self._services.ProgressionService
    if not progService and script and script.Parent then
        local mod = script.Parent:FindFirstChild("ProgressionService")
        if mod then progService = require(mod); self._services.ProgressionService = progService end
    end
    if progService and upgrade.RequiredLevel and upgrade.RequiredLevel > 1 then
        local prog = progService:GetProgression(player)
        if prog.Level < upgrade.RequiredLevel then
            return {
                Success = false,
                Error = string.format("Membutuhkan Level %d untuk memasang %s (Level kamu: %d)!", upgrade.RequiredLevel, upgrade.Name, prog.Level),
            }
        end
    end

    -- Validasi prasyarat upgrade sebelumnya
    if upgrade.PrerequisiteId and not owned[upgrade.PrerequisiteId] then
        local prereq = UpgradesConfig.GetUpgrade(upgrade.PrerequisiteId)
        local prereqName = if prereq then prereq.Name else upgrade.PrerequisiteId
        return {
            Success = false,
            Error = string.format("Harus memiliki '%s' terlebih dahulu!", prereqName),
        }
    end

    if wallet.CarriedCash < upgrade.Cost then
        return { Success = false, Error = string.format("Uang kas tidak cukup! Biaya: Rp %d (Kas kamu: Rp %d)", upgrade.Cost, wallet.CarriedCash) }
    end

    -- Potong uang kas dan catat upgrade
    wallet.CarriedCash -= upgrade.Cost
    owned[upgradeId] = true

    log:Info("Beli Upgrade: %s membeli '%s' seharga Rp %d", player.Name, upgrade.Name, upgrade.Cost)
    self:SyncWalletToClient(player)
    self:SyncUpgradesToClient(player)

    -- Terapkan efek visual fisik ke gerobak
    local cartService = self._services.CartService
    if not cartService and script and script.Parent then
        local mod = script.Parent:FindFirstChild("CartService")
        if mod then cartService = require(mod); self._services.CartService = cartService end
    end
    if cartService and cartService.ApplyUpgradeVisuals then
        cartService:ApplyUpgradeVisuals(player, upgradeId)
    end

    -- Jika upgrade adalah Kasir NPC, spawn kasir di gerobak pemain!
    if upgradeId == "kasir_npc" then
        local custService = self._services.CustomerService
        if not custService and script and script.Parent then
            local mod = script.Parent:FindFirstChild("CustomerService")
            if mod then custService = require(mod); self._services.CustomerService = custService end
        end
        if custService and custService.SpawnKasirForPlayer then
            custService:SpawnKasirForPlayer(player)
        end
    end

    local ts = self._services and self._services.TutorialService
    if ts and ts.OnUpgradeOrATMUsed then
        ts:OnUpgradeOrATMUsed(player)
    end

    return { Success = true, NewCash = wallet.CarriedCash, UpgradeName = upgrade.Name }
end

-- ============================================================================
-- TRANSAKSI ATM
-- ============================================================================

function EconomyService:DepositToATM(player: Player, amount: any): { Success: boolean, Error: string?, CarriedCash: number?, BankedCash: number? }
    if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount <= 0 or math.floor(amount) ~= amount then
        return { Success = false, Error = "Jumlah setoran tidak valid!" }
    end

    local wallet = self._playerWallets[player.UserId]
    if not wallet then
        return { Success = false, Error = "Data dompet tidak ditemukan!" }
    end

    if wallet.CarriedCash < amount then
        return { Success = false, Error = "Uang tunai kas tidak mencukupi untuk disetor!" }
    end

    wallet.CarriedCash -= amount
    wallet.BankedCash += amount
    log:Info("Setor ATM: %s menyetor Rp %d (Kas: Rp %d | Bank: Rp %d)", player.Name, amount, wallet.CarriedCash, wallet.BankedCash)
    self:SyncWalletToClient(player)

    local ts = self._services and self._services.TutorialService
    if ts and ts.OnUpgradeOrATMUsed then
        ts:OnUpgradeOrATMUsed(player)
    end

    return { Success = true, CarriedCash = wallet.CarriedCash, BankedCash = wallet.BankedCash }
end

function EconomyService:WithdrawFromATM(player: Player, amount: any): { Success: boolean, Error: string?, CarriedCash: number?, BankedCash: number? }
    if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount <= 0 or math.floor(amount) ~= amount then
        return { Success = false, Error = "Jumlah penarikan tidak valid!" }
    end

    local wallet = self._playerWallets[player.UserId]
    if not wallet then
        return { Success = false, Error = "Data dompet tidak ditemukan!" }
    end

    if wallet.BankedCash < amount then
        return { Success = false, Error = "Saldo tabungan ATM tidak mencukupi!" }
    end

    wallet.BankedCash -= amount
    wallet.CarriedCash += amount
    log:Info("Tarik ATM: %s menarik Rp %d (Kas: Rp %d | Bank: Rp %d)", player.Name, amount, wallet.CarriedCash, wallet.BankedCash)
    self:SyncWalletToClient(player)

    return { Success = true, CarriedCash = wallet.CarriedCash, BankedCash = wallet.BankedCash }
end

return EconomyService
