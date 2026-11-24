--!strict
--[[
    ServiceRunner.luau
    Lifecycle orchestrator terpadu untuk inisialisasi Server Services dan Client Controllers.
    Mencegah race-condition dan menjamin fase Init() selesai sebelum fase Start() dijalankan.
]]

local LoggerModule = script.Parent:WaitForChild("Logger")
local Logger = require(LoggerModule)
local log = Logger.new("ServiceRunner")

local ServiceRunner = {}
local registeredModules: { any } = {}
local isInitialized = false
local isStarted = false

function ServiceRunner.Register(mod: any)
    assert(type(mod) == "table", "Service/Controller must be a table")
    assert(type(mod.Name) == "string", "Service/Controller must have a valid string .Name property")
    table.insert(registeredModules, mod)
    log:Debug("Registered: %s", mod.Name)
end

function ServiceRunner.RegisterFolder(folder: Instance)
    for _, child in folder:GetChildren() do
        if child:IsA("ModuleScript") then
            local success, result = pcall(require, child)
            if success and type(result) == "table" and type(result.Name) == "string" then
                ServiceRunner.Register(result)
            elseif not success then
                log:Error("Failed to require module %s: %s", child.Name, tostring(result))
            end
        end
    end
end

function ServiceRunner.InitAll()
    if isInitialized then
        log:Warn("InitAll() already called; skipping.")
        return
    end
    isInitialized = true
    log:Info("Initializing %d registered modules...", #registeredModules)

    for _, mod in registeredModules do
        if type(mod.Init) == "function" then
            local startTime = os.clock()
            local success, err = pcall(function()
                mod:Init()
            end)
            if success then
                local elapsed = (os.clock() - startTime) * 1000
                log:Debug("Initialized %s in %.2f ms", mod.Name, elapsed)
            else
                log:Error("CRITICAL: Failed to initialize %s: %s", mod.Name, tostring(err))
            end
        end
    end
    log:Info("All modules successfully initialized.")
end

function ServiceRunner.StartAll()
    if isStarted then
        log:Warn("StartAll() already called; skipping.")
        return
    end
    isStarted = true
    log:Info("Starting %d registered modules...", #registeredModules)

    for _, mod in registeredModules do
        if type(mod.Start) == "function" then
            task.spawn(function()
                local success, err = pcall(function()
                    mod:Start()
                end)
                if not success then
                    log:Error("Error in Start() for %s: %s", mod.Name, tostring(err))
                end
            end)
        end
    end
    log:Info("All modules started.")
end

return ServiceRunner
