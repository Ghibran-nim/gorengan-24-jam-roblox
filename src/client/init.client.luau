--!strict
--[[
    init.client.luau
    Titik masuk utama (Bootstrap) untuk seluruh sistem Client.
    Menggunakan ServiceRunner untuk inisialisasi deterministik seluruh Controller.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tunggu Shared folder siap di ReplicatedStorage
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LoggerModule = Shared:WaitForChild("Utility"):WaitForChild("Logger")
local ServiceRunnerModule = Shared:WaitForChild("Utility"):WaitForChild("ServiceRunner")

local Logger = require(LoggerModule)
local ServiceRunner = require(ServiceRunnerModule)

local log = Logger.new("ClientBootstrap")

log:Info("Memulai client bootloader 'Gorengan 24 Jam: Awas Satpol!'...")

-- Registrasi seluruh modul di folder Controllers
local controllersFolder = script:WaitForChild("Controllers")
ServiceRunner.RegisterFolder(controllersFolder)

-- Jalankan fase InitAll() untuk seluruh Controller terdaftar
ServiceRunner.InitAll()

-- Jalankan fase StartAll() secara asinkron
ServiceRunner.StartAll()

log:Info("Client bootloader berhasil diselesaikan. UI dan Controller siap berinteraksi.")
