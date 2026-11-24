--!strict
--[[
    Logger.luau
    Sistem logging terstruktur dengan format timestamp, prefix modul, dan penanganan level log.
]]

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

local LogLevelRank: { [LogLevel]: number } = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local CURRENT_LEVEL: LogLevel = "INFO"

local Logger = {}
Logger.__index = Logger

export type Logger = {
    Prefix: string,
    Debug: (self: Logger, message: string, ...any) -> (),
    Info: (self: Logger, message: string, ...any) -> (),
    Warn: (self: Logger, message: string, ...any) -> (),
    Error: (self: Logger, message: string, ...any) -> (),
}

function Logger.new(prefix: string): Logger
    local self = setmetatable({}, Logger)
    self.Prefix = prefix
    return (self :: any) :: Logger
end

function Logger.SetGlobalLevel(level: LogLevel)
    CURRENT_LEVEL = level
end

local function formatMessage(prefix: string, level: LogLevel, message: string, ...: any): string
    local formatted = message
    if select("#", ...) > 0 then
        local success, result = pcall(string.format, message, ...)
        if success then
            formatted = result
        else
            formatted = message .. " " .. table.concat({ ... }, " ")
        end
    end
    local timestamp = os.date("%X")
    return string.format("[%s] [%s] [%s]: %s", timestamp, level, prefix, formatted)
end

function Logger:Debug(message: string, ...: any)
    if LogLevelRank["DEBUG"] >= LogLevelRank[CURRENT_LEVEL] then
        print(formatMessage(self.Prefix, "DEBUG", message, ...))
    end
end

function Logger:Info(message: string, ...: any)
    if LogLevelRank["INFO"] >= LogLevelRank[CURRENT_LEVEL] then
        print(formatMessage(self.Prefix, "INFO", message, ...))
    end
end

function Logger:Warn(message: string, ...: any)
    if LogLevelRank["WARN"] >= LogLevelRank[CURRENT_LEVEL] then
        warn(formatMessage(self.Prefix, "WARN", message, ...))
    end
end

function Logger:Error(message: string, ...: any)
    if LogLevelRank["ERROR"] >= LogLevelRank[CURRENT_LEVEL] then
        local formatted = formatMessage(self.Prefix, "ERROR", message, ...)
        local trace = debug.traceback("", 2)
        warn(formatted .. "\n" .. trace)
    end
end

return Logger
