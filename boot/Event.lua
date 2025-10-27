-- StattenOS Event library --
event = {}

do
	local clockStart = 0
	local clockTime = 0
	local clockavgs = {}
	
	local listeners = {}
	local allListeners = Pool()
    local onceListeners = {}
	
	event.startClock = function() clockStart = os.clock() end
	
	event.endClock = function() 
		clockTime = os.clock() - clockStart
		table.insert(clockavgs, clockTime)
		if (#clockavgs > 15) then table.remove(clockavgs,1) end
	end
	
	event.lastClock = function() return clockTime end
	
	event.avgClock = function()
		local n = 0
		for i=1,#clockavgs do n = n + clockavgs[i] end
		return n/#clockavgs
	end

	event.listen = function(names, callback) -- Register a callback to one or more signals 
		checkArg(1, names, "string", "table")
		checkArg(2, callback, "function")
        if (type(names) == "table") then
            for i=1,#names do
                local name = names[i]
                listeners[name] = listeners[name] or Pool()
                listeners[name]:add(callback)
            end
        else
            listeners[names] = listeners[names] or Pool()
            listeners[names]:add(callback)
        end
        return true
	end
    
	event.listenOnce = function(signal, callback) -- Register a callback to a signal which will only be executed once
		checkArg(1, names, "string", "table")
		checkArg(2, callback, "function")
        onceListeners[signal] = onceListeners[signal] or {}
        onceListeners[signal]:add(callback)
        return true
	end
	
	event.listenAll = function(callback) -- Register an event listener for all signals
		checkArg(1, callback, "function")
		allListeners:add(callback)
	end
	
	event.ignore = function(names, callback) -- Remove a previously registered callback
		checkArg(1, names, "string", "table")
		checkArg(1, callback, "function")
        if (type(names) == "table") then
            local ret = false
            for i=1,#names do
                local name = names[i]
                if (listeners[name]) then
                    ret = listeners[name]:remove(callback) or ret
                end
            end
            return ret
        elseif (listeners[names]) then
            return listeners[names]:remove(callback)
        else
            return false
        end
	end
	
    local function dispatchErrorHandler(err)
        if (event._onError) then
            event._onError(err, debug.traceback())
        end
    end
    
	event.dispatch = function(signal, ...) -- Dispatch a signal to event listeners
		local timeBefore = os.clock()
        for i=#allListeners,1,-1 do
            local f = allListeners[i]
            local r = xpcall(f, dispatchErrorHandler, signal, ...)
            if (not r) then allListeners:remove(f) end
        end
        local signalListeners = listeners[signal]
        if (signalListeners) then
            for i=#signalListeners,1,-1 do
                local f = signalListeners[i]
                local r = xpcall(f, dispatchErrorHandler, signal, ...)
                if (not r) then signalListeners:remove(f) end
            end
        end
        local signalListenersOnce = onceListeners[signal]
        if (signalListenersOnce) then
            for i=1,#signalListenersOnce do
                xpcall(signalListenersOnce[i], dispatchErrorHandler, signal, ...)
            end
            onceListeners[signal] = nil
        end
		event.lastRun = os.clock() - timeBefore
	end
    
    --[[
	
	event.pull = function(filter, timeout) -- Pull an event.  Caller should call event.stopClock() after it finishes doing work in order to accurately track CPU usage (BLOCKS ALL THREADS, USE 'thread.pullEvent()' INSIDE THREADS)
		checkArg(1,filter,"string","number","boolean","nil")
		checkArg(2,timeout,"number","nil")
		if (not timeout and type(filter) == "number") then timeout = filter filter = nil end
		timeout = timeout or 0
		local stoptime = computer.uptime() + timeout
		repeat
			event.startClock()
			local signal = table.pack(computer.pullSignal(math.max(0, stoptime - computer.uptime())))
			local name = tostring(signal[1])
			if (signal.n > 0) then
				dispatch(table.unpack(signal, 1, signal.n))
			end
			if (filter ~= false and (not filter or (filter and name:find(filter)))) then return table.unpack(signal, 1, signal.n) else event.endClock() end
		until (stoptime < computer.uptime())
		-- It's up to the caller to end the clock after event.pull() returns
	end
	
	event.sleep = function(timeout) -- Sleep for specified number of seconds (BLOCKS ALL THREADS, USE 'thread.sleep()' INSIDE THREADS)
		local stoptime = computer.uptime() + timeout
		repeat
			event.pull(false, math.max(0, stoptime - computer.uptime()))
			event.endClock()
		until computer.uptime() >= stoptime
	end
	os.sleep = event.sleep
	
	
	--]]
	
end