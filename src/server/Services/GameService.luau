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
    _availablePlots = { 1, 2, 3, 4, 5, 6, 7, 8 } :: { number },
    _serverStartTime = 0,
}

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

    -- Berikan slot plot gerobak yang tersedia
    if #self._availablePlots > 0 then
        local plotId = table.remove(self._availablePlots, 1) :: number
        self._playerPlots[userId] = plotId
        log:Info("Plot gerobak #%d dialokasikan untuk pemain %s", plotId, player.Name)

        if self._cartService then
            self._cartService:SpawnPlayerCart(player, plotId)
        end
    else
        log:Warn("Seluruh plot gerobak penuh! Pemain %s dalam mode penonton/antre.", player.Name)
    end
end

function GameService:_onPlayerRemoving(player: Player)
    local userId = player.UserId
    local plotId = self._playerPlots[userId]

    if plotId then
        table.insert(self._availablePlots, plotId)
        table.sort(self._availablePlots)
        self._playerPlots[userId] = nil
        log:Info("Plot gerobak #%d dikembalikan ke daftar plot tersedia dari pemain %s", plotId, player.Name)
    end
end

function GameService:GetPlayerPlot(player: Player): number?
    return self._playerPlots[player.UserId]
end

function GameService:_runDayCycleLoop()
    while true do
        task.wait(10)
        local elapsed = os.clock() - self._serverStartTime
        local cycleProgress = (elapsed % GameConfig.DayCycleDurationSeconds) / GameConfig.DayCycleDurationSeconds
        local inGameHour = math.floor(cycleProgress * 24)
        log:Debug("Siklus Waktu: Jam %02d:00 in-game (Progress: %.1f%%)", inGameHour, cycleProgress * 100)
    end
end

return GameService
