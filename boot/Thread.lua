do
    local activeThreads = Pool()
    local sleepingThreads = Pool()
    local pullingThreads = Pool()
    local signalPools = {}
    local dirtyThreads = Pool()
    
    -- ================================= Thread Class ================================= --
    
    local Thread = Class(function(Thread)

        function Thread.state:get() return self._state end -- States: suspended, sleeping, pulling, active, dead
        
        function Thread:init(f)
            self._state = "suspended"
            self._coroutine = coroutine.create(f)
        end
        
        function Thread:kill()
            if (self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "dead"
        end
        
        function Thread:resume()
            if (self._state == "active" || self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "active"
        end
        
        function Thread:suspend()
            if (self._state == "suspended" || self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "suspended"
            if (_G.Thread._current == self) then self._yieldedAt = computer.uptime() return coroutine.yield() end
        end
        
        function Thread:sleep(t)
            if (self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "sleeping"
            self._resumeAt = computer.uptime() + t
            if (_G.Thread._current == self) then self._yieldedAt = computer.uptime() return coroutine.yield() end
        end
        
        function Thread:pullEvent(signals, timeout)
            if (self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "pulling"
            self._pullSignals = type(signals) == "table" and signals or { signals }
            self._resumeAt = computer.uptime() + (timeout or math.huge)
            if (_G.Thread._current == self) then self._yieldedAt = computer.uptime() return coroutine.yield() end
        end
        
    end)
    
    -- ================================= Current Thread Functions ================================= --
    
    function Thread.yield()
        if (not Thread._current) then error("Attemped to call Thread.suspend() from the main thread", 2) end
        if (Thread._current._state ~= "active") then Thread._current:resume() end
        return coroutine.yield()
    end
    
    function Thread.suspend()
        if (not Thread._current) then error("Attemped to call Thread.suspend() from the main thread", 2) end
        Thread._current:suspend()
    end
    
    function Thread.sleep(t)
        if (not Thread._current) then error("Attemped to call Thread.sleep() from the main thread", 2) end
        Thread._current:sleep(t)
    end
    
    function Thread.pull(signals, timeout)
        if (not Thread._current) then error("Attemped to call Thread.pull() from the main thread", 2) end
        Thread._current:pullEvent()
    end
    
    -- ================================= Internal Functions ================================= --
    
    Thread._current = nil
    Thread.maxTime = 5 -- Default yield timeout
    
    local function processDirtyThreads()
        while (#dirtyThreads > 0) do
            local dirtyThread = dirtyThread[#dirtyThreads]
            -- Remove from old pool
            if (dirtyThread._state ~= "active") then activeThreads:remove(dirtyThread) end
            if (dirtyThread._state ~= "sleeping") then sleepingThreads:remove(dirtyThread) end
            if (dirtyThread._state ~= "pulling" and pullingThreads:contains(dirtyThread)) then
                pullingThreads:remove(dirtyThread)
                local dirtySignals = dirtyThread._pullSignals
                for i=1,#dirtySignals do
                    local pool = signalPools[dirtySignals[i]]
                    if (pool) then pool:remove(dirtyThread) end
                end
            end
            -- Add to new pool
            if (dirtyThread._state == "active") then activeThreads:add(dirtyThread) end
            if (dirtyThread._state == "sleeping") then
                sleepingThreads:add(dirtyThread)
                Thread.minResumeTime = math.min(Thread.minResumeTime, dirtyThread.resumeAt)
            end
            if (dirtyThread._state == "pulling" and not pullingThreads:contains(dirtyThread)) then
                pullingThreads:add(dirtyThread)
                Thread.minResumeTime = math.min(Thread.minResumeTime, dirtyThread.resumeAt)
                local dirtySignals = dirtyThread._pullSignals
                for i=1,#dirtySignals do
                    local pool = signalPools[dirtySignals[i]]
                    if (pool) then pool:add(dirtyThread) end
                end
            end
            dirtyThreads:remove(dirtyThread)
        end
    end
    
    local function resumeThread(thread, ...)
        local co = thread._coroutine
        if (coroutine.status(co) == "dead") then
            if (thread._state ~= "dead") then thread:kill() end
            return
        else if (thread._state ~= "active") then
            thread:resume()
        end
        local timeSinceYield = thread._yieldedAt and (thread.yieldedAt - computer.uptime()) or 0
        Thread._current = thread
        local ok, err = coroutine.resume(co, timeSinceYield, ...)
        Thread._current = nil
        if (not ok and Thread._onError) then Thread._onError(thread, err, debug.traceback(co)) end
        if (coroutine.status(co) == "dead") then
            thread:kill()
        end
        if (Thread._state == "sleeping" or Thread._state == "pulling") then Thread.minResumeTime = math.min(Thread.minResumeTime, thread.resumeAt) end
    end
    
    Event.listenAll(function(signal, ...)
        local pool = signalPools[signal]
        if (not pool or #pool == 0) then return end
        for i=1,#pool do
            resumeThread(pool[i], signal, ...)
        end
        processDirtyThreads()
    end)
    
    function Thread._update()
        local signal = table.pack(computer.pullSignal(math.max(0, Thread.minResumeTime - computer.uptime())))
        local startTime = os.clock()
        local resumedThreads = {}
        Thread.minResumeTime = math.huge
        
        local signalThreads = signalPools[signal[1]]
        if (signalThreads) then
            (function(...)
                for i=1,#signalThreads do
                    local thread = signalThreads[i]
                    resumeThread(thread, ...)
                    resumedThreads[thread] = true
                end
            end)(table.unpack(signal)) -- IIFE to avoid unpacking for every thread
        end
        
        for i=1,#pullingThreads do
            local thread = pullingThreads[i]
            if (not resumedThreads[thread}) then
                if (startTime > thread._resumeAt) then
                    resumeThread(thread)
                else
                    Thread.minResumeTime = math.min(Thread.minResumeTime, thread.resumeAt)
                end
            end
        end
        
        for i=1,#sleepingThreads do
            local thread = sleepingThreads[i]
            if (startTime > thread._resumeAt) then
                resumeThread(thread)
            else
                Thread.minResumeTime = math.min(Thread.minResumeTime, thread.resumeAt)
            end
        end
        
        processDirtyThreads()
        
        Thread.lastTime = os.clock() - startTime
        Thread.usage = Thread.lastTime / Thread.maxTime
    end
    
    function Thread._autoUpdate()
        Thread.minResumeTime = 0
        while true do
            Thread.update()
        end
    end
    
    _G.Thread = Thread
end





























-- StattenOS Thread API --
local thread = {
	current = 0, -- current thread (Id 0 is the thread scheduler itself)
	lastRun = 0, -- The amount of time the thread executor took to complete the last cycle
	
	running = 0, -- Currently being executed
	waiting = 1, -- Waiting in the thread queue to be executed
	suspended = 2, -- Suspended, will not be executed
	sleeping = 3, -- Waiting for a timeout to resume execution
	pulling = 4, -- Pulling an event using thread.pullEvent()
	dead = 5 -- The thread is dead, it can no longer be executed
}
_G.thread = {} -- Proxy table for readonly access
setmetatable(_G.thread, {__index = thread, __newindex = function() error("Access to the thread API table is read-only",2) end})
local threads = {}
local pullingThreads = {}
local tid = 1

local function wrapThreadFunc(f)
	return function(...)
		local r = table.pack(xpcall(f, function(s) return tostring(s).."\n"..debug.traceback() end))
		if (not r[1]) then return false, r[2] end
		return true, table.unpack(r, 2, r.n)
	end
end

function thread.new(priority, f)
	local newThread = {
		id = tid,
		state = thread.suspsnded,
		resumeAt = 0,
		pulling = nil,
		lastRun = 0,
		yieldedAt = computer.uptime(),
		priority = priority or 0, -- Threads with a higher priority value will be executed before threads with a lower priority value
		routine = coroutine.create(wrapThreadFunc(f))
	}
	threads[tid] = newThread
	tid = tid + 1
	return newThread.id --The thread id is it's position in the threads table
end

function thread.resume(id) -- Start/resume execution of a thread, if the thread is sleeping this will cause it to resume immediately
	if (not threads[id]) then return false end
	local t = threads[id]
	if (t.state ~= thread.waiting) then
		t.pulledSignal = nil
		t.state = thread.waiting
		computer.pushSignal("thread_resumed") -- This will break the thread executor's event.pull()
	end
	return true
end

function thread.suspend(id, t) -- Suspend the thread, if a timeout is provided this will act like thread.sleep()
	if (not threads[id]) then return false end
	if (t) then
		threads[id].state = thread.sleeping
		threads[id].resumeAt = computer.uptime() + t
	else
		threads[id].state = thread.suspended
	end
	return true
end

function thread.kill(id) -- Kill the thread
	if (not threads[id]) then return false end
	threads[id].state = thread.dead
	if (thread.current == id) then coroutine.yield() else threads[id] = nil end -- Let the executor kill the thread if it is currently running
	return true
end

function thread.state(id) return (threads[id]) and threads[id].state or thread.dead end -- Get the state of a thread, assume the thread is dead if not found
function thread.lastTime(id) return (threads[id]) and threads[id].lastRun or -1 end -- Get amount of time execution of the thread took on the last run

function thread.sleep(t) -- Yield and suspend execution of the current thread for the specified number of seconds
	if (thread.current == 0) then
		
	else
		if (t) then
			threads[thread.current].resumeAt = computer.uptime() + t
			threads[thread.current].state = thread.sleeping
		else
			threads[thread.current].state = thread.waiting -- Resume the thread asap if no time is given
		end
		return coroutine.yield()
	end
end

function thread.pullEvent(filter, timeout)
	if (not timeout and type(filter) == "number") then timeout = filter filter = nil end
	checkArg(1,filter,"string","number","nil")
	checkArg(2,timeout,"number","nil")
	timeout = timeout or 0
	if (thread.current == 0) then 
		return event.pull(filter, timeout)
	else
		local ct = threads[thread.current]
		if (not ct) then error("Attempt to pull event on thread "..thread.current..", which does not exist") end
		ct.state = thread.pulling
		ct.resumeAt = computer.uptime() + timeout
		ct.pulling = filter
		ct.yieldedAt = computer.uptime()
		table.insert(pullingThreads, ct)
		return coroutine.yield()
	end
end

----------- Helper functions -----------

local function getNearest() -- Get how long before the next thread needs to be executed
	local l = math.huge
	for i,p in pairs(threads) do
		if (p.state == thread.waiting) then -- If a thread is waiting for execution, resume asap
			return 0
		elseif (p.state == thread.sleeping or p.state == thread.pulling) then
			l = math.min(l, p.resumeAt)
		end
	end
	return l
end

local function getQueue() -- Create a queue of threads to execute, respecting priority and ignoring sleeping/suspended threads
	local queue = {}
	for i,p in pairs(threads) do
		if ((p.state == thread.sleeping or p.state == thread.pulling) and computer.uptime() >= p.resumeAt) then
			p.state = thread.waiting
			p.pulledSignal = nil
			queue[p.priority] = queue[p.priority] or {}
			table.insert(queue[p.priority], p)
			gl.getGPU().get(50,2,"w")
		elseif (p.state == thread.waiting) then
			queue[p.priority] = queue[p.priority] or {}
			table.insert(queue[p.priority], p)
		end
	end
	local normalizedQueue = {}
	for i,p in pairs(queue) do table.insert(normalizedQueue, p) end
	return normalizedQueue
end

----------- End helper functions -----------
event.listenAll(function(signal, ...)
	if (signal == "thread_resumed") then return end
	for i,p in pairs(pullingThreads) do
		if (p.state == thread.pulling and (not p.pulling or signal:find(p.pulling))) then
			pullingThreads[i] = nil
			local oc = thread.current
			thread.current = p.id
			p.state = thread.running
			local beforeExec = os.clock()
			local timeSince = computer.uptime() - p.yieldedAt
			local s,r = coroutine.resume(p.routine, timeSince, signal, ...) -- Pass the time since yielding and the event
			thread.current = 0
			if (s and p.state ~= thread.dead and coroutine.status(p.routine) ~= "dead") then -- Kill the thread if it errored or was manually killed during execution
				if (p.state == thread.runnning) then p.state = thread.waiting end
				p.yieldedAt = computer.uptime()
				p.lastRun = os.clock() - beforeExec
			else
				p.state = thread.dead
				threads[p.id] = nil
				error(r)
			end
		elseif (p.state ~= thread.pulling) then
			pullingThreads[i] = nil
		end
	end
end)



local runtimes = {}
local debugReplace = function() return "" end
function thread.threadTick() -- DO NOT USE INSIDE THREADS, THIS WILL BREAK THINGS
	thread.current = 0
	local e = event.pull("thread_resumed", getNearest() - computer.uptime())
	local timeBefore = os.clock()
	local queue = getQueue()
	if (#queue > 0) then
		for i=#queue,1,-1 do --Execute from highest priority to lowest
			for _,t in pairs(queue[i]) do
				local beforeExec = os.clock()
				thread.current = t.id
				t.state = thread.running
				local timeSince = computer.uptime() - t.yieldedAt
				local r1,r2,r3 = coroutine.resume(t.routine, timeSince) -- Pass the time since the thread yielded
				thread.current = 0
				if (r1 and (r2 ~= false) and t.state ~= thread.dead and coroutine.status(t.routine) ~= "dead") then -- Kill the thread if it errored or was manually killed during execution
					if (t.state == thread.runnning) then t.state = thread.waiting end
					t.yieldedAt = computer.uptime()
					t.lastRun = os.clock() - beforeExec
				elseif (t.state ~= thread.dead or coroutine.status(t.routine) == "dead") then
					t.state = thread.dead
					threads[t.id] = nil
				else
					t.state = thread.dead
					threads[t.id] = nil
					local otb = debug.traceback
					debug.traceback = debugReplace
					error(tostring(r1).." "..tostring(r2).." "..tostring(r3)) -- TODO: Generate an event rather than erroring, let the unwritten Process module handle the error
					debug.traceback = otb
				end
			end
		end
	end
	thread.lastRun = os.clock() - timeBefore
	event.endClock()
end









