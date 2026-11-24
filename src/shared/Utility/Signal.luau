--!strict
--[[
    Signal.luau
    Implementasi Observer/Event pattern ringan, cepat, dan aman tanpa BindableEvent.
]]

export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

export type Signal = {
    Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
    Once: (self: Signal, callback: (...any) -> ()) -> Connection,
    Fire: (self: Signal, ...any) -> (),
    Wait: (self: Signal) -> ...any,
    DisconnectAll: (self: Signal) -> (),
    Destroy: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
    local self = setmetatable({
        _listeners = {} :: { (...any) -> () },
    }, Signal)
    return (self :: any) :: Signal
end

function Signal:Connect(callback: (...any) -> ()): Connection
    assert(type(callback) == "function", "Listener callback must be a function")
    table.insert(self._listeners, callback)

    local connection = {
        Connected = true,
        Disconnect = function(conn: any)
            if not conn.Connected then return end
            conn.Connected = false
            local idx = table.find(self._listeners, callback)
            if idx then
                table.remove(self._listeners, idx)
            end
        end,
    }
    return connection
end

function Signal:Once(callback: (...any) -> ()): Connection
    local connection: Connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        callback(...)
    end)
    return connection
end

function Signal:Fire(...: any)
    -- Iterasi pada salinan tabel untuk mencegah error jika listener terputus saat firing
    local listenersCopy = table.clone(self._listeners)
    for _, listener in listenersCopy do
        task.spawn(listener, ...)
    end
end

function Signal:Wait(): ...any
    local thread = coroutine.running()
    local conn: Connection
    conn = self:Connect(function(...)
        conn:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:DisconnectAll()
    table.clear(self._listeners)
end

function Signal:Destroy()
    self:DisconnectAll()
    setmetatable(self, nil)
end

return Signal
