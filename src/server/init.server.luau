--!strict
--[[
    init.server.luau
    Titik masuk utama (Bootstrap) untuk seluruh sistem Server.
    Menggunakan ServiceRunner untuk inisialisasi deterministik seluruh Service.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tunggu Shared folder siap di ReplicatedStorage
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LoggerModule = Shared:WaitForChild("Utility"):WaitForChild("Logger")
local ServiceRunnerModule = Shared:WaitForChild("Utility"):WaitForChild("ServiceRunner")

local Logger = require(LoggerModule)
local ServiceRunner = require(ServiceRunnerModule)

local log = Logger.new("ServerBootstrap")

log:Info("Memulai server bootloader 'Gorengan 24 Jam: Awas Satpol!'...")

-- Registrasi seluruh modul di folder Services
local servicesFolder = script:WaitForChild("Services")
ServiceRunner.RegisterFolder(servicesFolder)

-- Jalankan fase InitAll() untuk seluruh Service terdaftar
ServiceRunner.InitAll()

-- Jalankan fase StartAll() secara asinkron
ServiceRunner.StartAll()

log:Info("Server bootloader berhasil diselesaikan. Server siap melayani pemain.")
