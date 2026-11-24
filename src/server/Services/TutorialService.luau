--!strict
--[[
    TutorialService.luau
    Layanan server untuk mengelola alur tutorial pemula (Onboarding Flow).
    Memastikan pemain baru memahami 5 pilar inti gameplay:
    1. Menemukan gerobak di plot yang telah ditentukan
    2. Mengambil persediaan bahan dari peti gerobak
    3. Menggoreng adonan hingga tingkat kematangan Crispy
    4. Melayani pesanan pelanggan yang mengantre
    5. Menginvestasikan uang ke upgrade bengkel atau tabungan ATM
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Utility"):WaitForChild("Logger"))
local NetworkBridge = require(Shared:WaitForChild("Network"):WaitForChild("NetworkBridge"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local GameplayTypes = require(Shared:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type Service = GameplayTypes.Service

local log = Logger.new("TutorialService")

export type TutorialStep = {
    Id: number,
    Title: string,
    Description: string,
}

local TUTORIAL_STEPS: { TutorialStep } = {
    {
        Id = 1,
        Title = "Temukan Gerobakmu",
        Description = "Temukan gerobak gorenganmu di Plot #%d dan dekati area memasak!",
    },
    {
        Id = 2,
        Title = "Ambil Bahan Baku",
        Description = "Buka Peti Bahan di gerobakmu (tekan [E]) untuk mengisi persediaan adonan & sayur!",
    },
    {
        Id = 3,
        Title = "Goreng Bakwan Crispy",
        Description = "Dekati wajan dan mulai menggoreng. Angkat saat meteran berwarna EMAS (Crispy)!",
    },
    {
        Id = 4,
        Title = "Layani Pembeli Pertama",
        Description = "Pelanggan sudah mengantre! Dekati pembeli terdepan dan tekan 'Sajikan Pesanan'!",
    },
    {
        Id = 5,
        Title = "Kembangkan Usahamu",
        Description = "Hebat! Buka menu Bengkel (🔧) untuk membeli upgrade atau amankan kas di ATM (🏧)!",
    },
}

export type PlayerTutorialState = {
    CurrentStep: number,
    IsCompleted: boolean,
    IsSkipped: boolean,
}

local TutorialService = {
    Name = "TutorialService",
    _playerStates = {} :: { [number]: PlayerTutorialState },
    _services = {} :: { [string]: any },
}

function TutorialService:Init()
    log:Info("Menginisialisasi TutorialService...")

    Players.PlayerAdded:Connect(function(player: Player)
        self:_setupPlayerTutorial(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self._playerStates[player.UserId] = nil
    end)

    for _, player in Players:GetPlayers() do
        self:_setupPlayerTutorial(player)
    end

    -- Handler permintaan status tutorial
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestGetTutorialState, function(player: Player)
        local state = self._playerStates[player.UserId]
        if state then
            local stepData = self:GetStepData(player, state.CurrentStep)
            return {
                Success = true,
                CurrentStep = state.CurrentStep,
                TotalSteps = #TUTORIAL_STEPS,
                StepTitle = if stepData then stepData.Title else "Selesai",
                StepDescription = if stepData then stepData.Description else "Tutorial telah diselesaikan!",
                IsCompleted = state.IsCompleted,
                IsSkipped = state.IsSkipped,
            }
        end
        return { Success = false, Error = "Status tutorial tidak ditemukan" }
    end)

    -- Handler lewati tutorial
    NetworkBridge.RegisterServerFunction(Remotes.Functions.RequestSkipTutorial, function(player: Player)
        return self:SkipTutorial(player)
    end)
end

function TutorialService:Start()
    local Server = script.Parent
    self._services.GameService = require(Server:WaitForChild("GameService"))
    self._services.EconomyService = require(Server:WaitForChild("EconomyService"))
    self._services.InventoryService = require(Server:WaitForChild("InventoryService"))

    log:Info("TutorialService aktif.")
end

function TutorialService:_setupPlayerTutorial(player: Player)
    local userId = player.UserId
    if not self._playerStates[userId] then
        self._playerStates[userId] = {
            CurrentStep = 1,
            IsCompleted = false,
            IsSkipped = false,
        }
        task.delay(1.5, function()
            if player.Parent then
                self:SyncTutorialState(player)
            end
        end)
    end
end

function TutorialService:GetStepData(player: Player, stepId: number): TutorialStep?
    local raw = TUTORIAL_STEPS[stepId]
    if not raw then return nil end

    local gameService = self._services.GameService
    local plotId = if gameService then (gameService:GetPlayerPlot(player) or 1) else 1

    return {
        Id = raw.Id,
        Title = raw.Title,
        Description = string.format(raw.Description, plotId),
    }
end

function TutorialService:SyncTutorialState(player: Player)
    local state = self._playerStates[player.UserId]
    if not state then return end

    local stepData = self:GetStepData(player, state.CurrentStep)
    local title = if stepData then stepData.Title else "Selesai"
    local desc = if stepData then stepData.Description else "Tutorial telah diselesaikan!"

    NetworkBridge.FireClient(
        player,
        Remotes.Events.TutorialStepUpdated,
        state.CurrentStep,
        #TUTORIAL_STEPS,
        title,
        desc,
        state.IsCompleted or state.IsSkipped
    )
end

function TutorialService:ProgressStep(player: Player, expectedStep: number): boolean
    local state = self._playerStates[player.UserId]
    if not state or state.IsCompleted or state.IsSkipped then
        return false
    end

    if state.CurrentStep ~= expectedStep then
        return false
    end

    local nextStep = state.CurrentStep + 1
    log:Info("Pemain %s menyelesaikan Langkah Tutorial #%d -> Maju ke #%d", player.Name, expectedStep, nextStep)

    if nextStep > #TUTORIAL_STEPS then
        -- Tutorial Selesai!
        state.IsCompleted = true
        state.CurrentStep = #TUTORIAL_STEPS + 1

        local economyService = self._services.EconomyService
        if economyService then
            economyService:AddCarriedCash(player, 10000, "Hadiah Kelulusan Tutorial")
        end

        NetworkBridge.FireClient(player, Remotes.Events.NotificationFired, "🎉 SELAMAT! Kamu lulus tutorial dan mendapat bonus modal Rp 10.000!", "Crispy")
        self:SyncTutorialState(player)
        return true
    else
        state.CurrentStep = nextStep
        self:SyncTutorialState(player)
        return true
    end
end

function TutorialService:SkipTutorial(player: Player): { Success: boolean }
    local state = self._playerStates[player.UserId]
    if not state then
        return { Success = false }
    end

    state.IsSkipped = true
    state.IsCompleted = true
    state.CurrentStep = #TUTORIAL_STEPS + 1
    self:SyncTutorialState(player)
    NetworkBridge.FireClient(player, Remotes.Events.NotificationFired, "Tutorial dilewati. Selamat berdagang secara mandiri!", "Info")
    return { Success = true }
end

-- ============================================================================
-- INTEGRATION HOOKS DARI SERVICE LAIN
-- ============================================================================

-- Hook Langkah 1: Pemain mendekati gerobak
function TutorialService:OnCartApproached(player: Player)
    local state = self._playerStates[player.UserId]
    if not state then return end

    if state.CurrentStep == 1 then
        self:ProgressStep(player, 1)
    end
end

-- Hook Langkah 2: Pemain mengambil bahan baku
function TutorialService:OnIngredientsTaken(player: Player)
    local state = self._playerStates[player.UserId]
    if not state then return end

    if state.CurrentStep == 1 then
        self:ProgressStep(player, 1)
    elseif state.CurrentStep == 2 then
        self:ProgressStep(player, 2)
    end
end

-- Hook Langkah 3: Pemain selesai menggoreng dan mengangkat makanan
function TutorialService:OnFoodCollected(player: Player, quality: string)
    local state = self._playerStates[player.UserId]
    if not state then return end

    if state.CurrentStep == 3 then
        self:ProgressStep(player, 3)
    end
end

-- Hook Langkah 4: Pemain berhasil menyajikan pesanan ke pembeli
function TutorialService:OnCustomerServed(player: Player)
    local state = self._playerStates[player.UserId]
    if not state then return end

    if state.CurrentStep == 4 then
        self:ProgressStep(player, 4)
    end
end

-- Hook Langkah 5: Pemain membeli upgrade atau menggunakan ATM
function TutorialService:OnUpgradeOrATMUsed(player: Player)
    local state = self._playerStates[player.UserId]
    if not state then return end

    if state.CurrentStep == 5 then
        self:ProgressStep(player, 5)
    end
end

function TutorialService:GetPlayerState(player: Player): PlayerTutorialState?
    return self._playerStates[player.UserId]
end

return TutorialService
