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
function thread.new(priority, f)
	local newThread = {
		id = tid,
		state = thread.suspsnded,
		resumeAt = 0,
		pulling = nil,
		lastRun = 0,
		yieldedAt = computer.uptime(),
		priority = priority or 0, -- Threads with a higher priority value will be executed before threads with a lower priority value
		routine = coroutine.create(f)
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
				local s,r = coroutine.resume(t.routine, timeSince) -- Pass the time since the thread yielded
				thread.current = 0
				if (s and t.state ~= thread.dead and coroutine.status(t.routine) ~= "dead") then -- Kill the thread if it errored or was manually killed during execution
					if (t.state == thread.runnning) then t.state = thread.waiting end
					t.yieldedAt = computer.uptime()
					t.lastRun = os.clock() - beforeExec
				else
					t.state = thread.dead
					threads[t.id] = nil
					error(r)
				end
			end
		end
	end
	thread.lastRun = os.clock() - timeBefore
	event.endClock()
end









