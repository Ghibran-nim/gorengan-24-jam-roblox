--!strict
--[[
    TimeScheduleConfig.luau
    Konfigurasi siklus 24 jam (12 menit real-time = 720 detik) beserta suasana pencahayaan
    Pagi, Siang, Sore, dan Malam khas jalanan Indonesia.
]]

local GameplayTypes = require(script.Parent.Parent:WaitForChild("Types"):WaitForChild("GameplayTypes"))

type DayPhaseId = GameplayTypes.DayPhaseId

export type DayPhaseProfile = {
    Id: DayPhaseId,
    Name: string,
    Icon: string,
    StartHour: number,
    EndHour: number,
    Ambient: Color3,
    OutdoorAmbient: Color3,
    ColorShiftTop: Color3,
    Brightness: number,
    StreetLampsOn: boolean,
    Description: string,
}

local PHASES: { DayPhaseProfile } = {
    {
        Id = "Pagi",
        Name = "Pagi Cerah",
        Icon = "🌅",
        StartHour = 5,
        EndHour = 11,
        Ambient = Color3.fromRGB(125, 115, 105),
        OutdoorAmbient = Color3.fromRGB(145, 140, 130),
        ColorShiftTop = Color3.fromRGB(255, 225, 185),
        Brightness = 2.05,
        StreetLampsOn = false,
        Description = "Matahari pagi hangat, mahasiswa dan pekerja mulai mencari sarapan gorengan.",
    },
    {
        Id = "Siang",
        Name = "Siang Terik",
        Icon = "☀️",
        StartHour = 11,
        EndHour = 16,
        Ambient = Color3.fromRGB(135, 135, 135),
        OutdoorAmbient = Color3.fromRGB(155, 155, 150),
        ColorShiftTop = Color3.fromRGB(255, 250, 240),
        Brightness = 2.35,
        StreetLampsOn = false,
        Description = "Jalanan ramai dan terik, waspada razia Satpol PP dan copet!",
    },
    {
        Id = "Sore",
        Name = "Sore Jingga",
        Icon = "🌇",
        StartHour = 16,
        EndHour = 19,
        Ambient = Color3.fromRGB(130, 100, 85),
        OutdoorAmbient = Color3.fromRGB(150, 115, 95),
        ColorShiftTop = Color3.fromRGB(255, 175, 105),
        Brightness = 1.65,
        StreetLampsOn = true,
        Description = "Langit jingga jam pulang kerja! Lampu jalan & neon mulai menyala.",
    },
    {
        Id = "Malam",
        Name = "Pasar Malam",
        Icon = "🌙",
        StartHour = 19,
        EndHour = 5,
        Ambient = Color3.fromRGB(48, 54, 78),
        OutdoorAmbient = Color3.fromRGB(70, 80, 115),
        ColorShiftTop = Color3.fromRGB(130, 150, 210),
        Brightness = 1.15,
        StreetLampsOn = true,
        Description = "Suasana malam syahdu! Pelanggan misterius & event khusus malam bermunculan.",
    },
}

local TimeScheduleConfig = {
    CycleDurationSeconds = 720, -- 12 menit real-time = 24 jam in-game
    StartingClockTime = 7.0,    -- Mulai pukul 07:00 pagi
    Phases = PHASES,

    GetPhaseForHour = function(clockTime: number): DayPhaseProfile
        local h = clockTime % 24
        if h >= 5 and h < 11 then
            return PHASES[1] -- Pagi
        elseif h >= 11 and h < 16 then
            return PHASES[2] -- Siang
        elseif h >= 16 and h < 19 then
            return PHASES[3] -- Sore
        else
            return PHASES[4] -- Malam
        end
    end,
}

return table.freeze(TimeScheduleConfig)