-- StattenOS Event library --
event = {}

event.signals = {}
--[[ DOCUMENTATION
	
	event.signals: table
		Any values added to this table are appended to the signal lookup string
		implements __call to return an iterator for the signal lookup string
		
	event.resolveSignal(partial: string[, matchTable: table]): table
		Resolve a partial signal name to a list of complete signal names using the signal lookup string
		If matchTable is not nil, resolved names will be added to the matchTable instead of being added to a new table
		
		Returns a new table containing resolved signal names, or matchTable
		
	event.listen(names: string|table, callback: function[, exact:boolean]): boolean
		Register an event listener with one or more signals
		If exact is true, the signal names will not be resolved with event.resolveSignal()
		
		Returns true if the callback was registered to at least one signal
		
	event.listenAll(callback: function)
		Register an event listener to all signals)
	
	event.ignore(names: string|table, callback: function[, exact:boolean]): boolean
		Remove an event listener from one or more signals
		If exact is true, the signal names will not be resolved with event.resolveSignal()
		
		Returns true if the callback was removed from at least one signal
	
	
	
	
	
	
	
--]]
do
	local clockStart = 0
	local clockTime = 0
	local clockavgs = {}
	
	local listeners = {}
	local allListeners = {}
	
	-- Registered signal names
	local signalNames = " component_added component_removed component_available component_unavailable screen_resize touch drag drop scroll walk key_down key_up clipboard redstone_changed modem_message motion "

	for i,s in pairs(event.signals) do
		signalNames = signalNames..s.." "
		signals[i] = nil
	end
	
	setmetatable(event.signals, {__newindex = function(i,k) signalNames = signalNames..k.." " end, __call = function() return signalNames:gmatch("%s+%w+%s+") end})
	
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
	
	event.resolveSignal = function(s,t) -- Resolve a partial signal name to a list of registered signals
		checkArg(1, s, "string")
		checkArg(2, t, "table", "nil")
		local matches = t or {}
		for m in signalNames:gmatch("%s-("..s.."[^%s]-)%s+") do
			table.insert(matches, m)
		end
		return matches
	end
	
	local function getSignals(names, exact)
		checkArg(1, names, "string", "table")
		local signals
		if (exact) then -- Use exact signal names
			if (type(names) == "table") then
				signals = names
			else
				signals = {names}
			end
		else
			if (type(names) == "table") then
				signals = {}
				for _,s in pairs(names) do event.resolveSignal(s, signals) end
			else
				signals = event.resolveSignal(names)
			end
		end
		return signals
	end

	event.listen = function(names, callback, exact) -- Register a callback to one or more signals 
		checkArg(1, names, "string", "table")
		checkArg(2, callback, "function")
		signals = getSignals(names, exact)
		if (#signals > 0) then
			for _,s in pairs(signals) do
				listeners[s] = listeners[s] or {}
				table.insert(listeners[s], callback)
			end
			return true
		end
		return false
	end
	
	event.listenAll = function(callback) -- Register an event listener for all signals
		checkArg(1, callback, "function")
		table.insert(allListeners, callback)
	end
	
	event.ignore = function(names, callback, exact) -- Remove a previously registered callback
		checkArg(1, names, "string", "table")
		checkArg(1, callback, "function")
		signals = getSignals(names, exact)
		local removed = false
		if (#signals > 0) then
			for _,s in pairs(signals) do
				local list = listeners[s]
				if (list) then
					for i,p in pairs(list) do
						if (p == callback) then list[i] = nil removed = true end
					end
				end
			end
			return removed
		end
		return false
	end
	
	local function dispatch(signal, ...) -- Dispatch a signal
		local timeBefore = os.clock()
		for i,f in pairs(allListeners) do
			local r,m = pcall(f, signal, ...)
			if (not r) then
				allListeners[i] = nil
				-- TODO: Call to debug.writeLine() once implemented
				-- TODO: Generate error popup once popups are implemented
				error(m)
			end
		end
		local signalListeners = listeners[signal]
		if (not signalListeners) then return end
		for i,f in pairs(signalListeners) do
			local r,m = pcall(f, signal, ...)
			if (not r) then
				signalListeners[i] = nil
				-- TODO: Call to debug.writeLine() once implemented
				-- TODO: Generate error popup once popups are implemented
				error(m)
			end
		end
		event.lastRun = os.clock() - timeBefore
	end
	
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
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end



