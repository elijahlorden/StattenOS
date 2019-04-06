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
	local listeners = {}
	local allListeners = {}
	
	-- Registered signal names
	local signalNames = " component_added component_removed component_available component_unavailable screen_resize touch drag drop scroll walk key_down key_up clipboard redstone_changed modem_message motion "

	for i,s in pairs(event.signals) do
		signalNames = signalNames..s.." "
		signals[i] = nil
	end
	
	setmetatable(event.signals, {__newindex = function(i,k) signalNames = signalNames..k.." " end, __call = function() return signalNames:gmatch("%s+%w+%s+") end})

	event.resolveSignal = function(s,t) -- Resolve a partial signal name to a list of registered signals
		--checkArg(1, s, "string")
		--checkArg(2, t, "table", "nil")
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
	end
	
	event.pull = function(filter, timeout) -- Pull an event (BLOCKS ALL THREADS, USE 'thread.pullEvent()' INSIDE THREADS
		local stoptime = computer.uptime() + timeout
		while (stoptime > computer.uptime()) do
			local signal = table.pack(computer.pullSignal(timeout))
			local name = tostring(signal[1])
			if (signal.n > 0) then
				dispatch(table.unpack(signal, 1, signal.n))
			end
			if (name:find(filter)) then return table.unpack(signal, 1, signal.n) end
		end
	end
	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end



