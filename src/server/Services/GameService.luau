--!strict
--[[
    GameService.luau
    Koordinator global siklus hidup pemain dan status permainan di server.
    Mengelola penetapan plot gerobak pemain, pelacakan waktu siklus hari, dan pembersihan data saat disconnect.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service

local log = Logger.new("GameService")

local GameService = {
    Name = "GameService",
    _playerPlots = {} :: { [number]: number }, -- [UserId] = PlotId (1..8)
    _plotOwners = {} :: { [number]: number },  -- [PlotId] = UserId (kunci kepemilikan dua arah)
    _availablePlots = { 1, 2, 3, 4, 5, 6, 7, 8 } :: { number },
    _serverStartTime = 0,
}

function GameService:_getService(serviceName: string): any
    local Server = script and script.Parent
    local mod = if Server then Server:FindFirstChild(serviceName) else nil
    return if mod then require(mod) else nil
end

function GameService:Init()
    log:Info("Menginisialisasi GameService...")
    self._serverStartTime = os.clock()

    Players.PlayerAdded:Connect(function(player: Player)
        self:_onPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self:_onPlayerRemoving(player)
    end)

    -- Tangani pemain yang mungkin sudah ada sebelum service selesai init
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            self:_onPlayerAdded(player)
        end)
    end
end

function GameService:Start()
    log:Info("Memulai loop siklus waktu GameService...")
    local Server = script.Parent
    self._cartService = require(Server:WaitForChild("CartService"))

    -- Spawn gerobak untuk pemain yang sudah bergabung
    for _, player in Players:GetPlayers() do
        local plotId = self._playerPlots[player.UserId]
        if plotId and self._cartService then
            self._cartService:SpawnPlayerCart(player, plotId)
        end
    end

    task.spawn(function()
        self:_runDayCycleLoop()
    end)
end

function GameService:_onPlayerAdded(player: Player)
    local userId = player.UserId
    log:Info("Pemain bergabung: %s (ID: %d)", player.Name, userId)

    -- Hindari alokasi ganda bila pemain sudah memiliki plot
    if self._playerPlots[userId] then
        return
    end

    -- Berikan slot plot gerobak yang tersedia secara eksklusif (maks 8 pemain)
    if #self._availablePlots > 0 then
        local plotId = table.remove(self._availablePlots, 1) :: number
        if self._plotOwners[plotId] and self._plotOwners[plotId] ~= userId then
            log:Warn("Konflik plot #%d dicegah untuk %s!", plotId, player.Name)
            return
        end
        self._playerPlots[userId] = plotId
        self._plotOwners[plotId] = userId
        log:Info("Plot gerobak #%d dialokasikan untuk pemain %s", plotId, player.Name)

        if self._cartService then
            self._cartService:SpawnPlayerCart(player, plotId)
        end
    else
        log:Warn("Seluruh plot gerobak penuh (maks %d)! Pemain %s dalam mode penonton/antre.", GameConfig.MaxPlayers or 8, player.Name)
    end
end

function GameService:_onPlayerRemoving(player: Player)
    local userId = player.UserId
    local plotId = self._playerPlots[userId]

    -- Bersihkan gerobak & antrean pelanggan pada plot sebelum membuka slot untuk pemain baru
    local cartService = self._cartService or self:_getService("CartService")
    if cartService and cartService.DespawnPlayerCart then
        cartService:DespawnPlayerCart(player)
    end

    if plotId then
        local custService = self:_getService("CustomerService")
        if custService and custService.ClearPlotCustomers then
            custService:ClearPlotCustomers(plotId)
        end

        if self._plotOwners[plotId] == userId then
            self._plotOwners[plotId] = nil
        end
        if not table.find(self._availablePlots, plotId) then
            table.insert(self._availablePlots, plotId)
            table.sort(self._availablePlots)
        end
        self._playerPlots[userId] = nil
        log:Info("Plot gerobak #%d dikembalikan ke daftar plot tersedia dari pemain %s", plotId, player.Name)
    end
end

function GameService:GetPlayerPlot(player: Player): number?
    return self._playerPlots[player.UserId]
end

function GameService:GetPlotOwner(plotId: number): number?
    return self._plotOwners[plotId]
end

function GameService:RequestSpecificPlot(player: Player, plotId: number): { Success: boolean, Error: string? }
    if typeof(plotId) ~= "number" or plotId < 1 or plotId > (GameConfig.MaxPlayers or 8) or math.floor(plotId) ~= plotId then
        return { Success = false, Error = "Nomor plot tidak valid (1–8)!" }
    end

    local currentOwner = self._plotOwners[plotId]
    if currentOwner and currentOwner ~= player.UserId then
        return { Success = false, Error = string.format("Konflik kepemilikan: Plot #%d sudah ditempati pemain lain!", plotId) }
    end

    return { Success = true }
end

function GameService:_runDayCycleLoop()
    -- Siklus waktu 24 jam penuh (12 menit = 720s) beserta pencahayaan & event dikelola oleh TimeService
    log:Info("Koordinasi waktu diserahkan ke TimeService.")
end

return GameService
