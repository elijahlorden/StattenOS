local thread = {
	current = 0, -- current thread (Id 0 is the thread scheduler itself)
	lastRun = 0, -- The amount of time the thread executor took to complete the last cycle
	
	running = 0, -- Currently being executed
	waiting = 1, -- Waiting in the thread queue to be executed
	suspended = 2, -- Suspended, will not be executed
	sleeping = 3, -- Waiting for a timeout to resume execution
	dead = 4 -- The thread is dead, it can no longer be executed
}
_G.thread = {} -- Proxy table for readonly access
setmetatable(_G.thread, {__index = thread, __newindex = function() error("Access to the thread API table is read-only",2) end})
local threads = {}
local tid = 1
function thread.new(priority, f)
	local newThread = {
		id = tid,
		state = thread.suspsnded,
		resumeAt = 0,
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
	threads[id].state = thread.waiting
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
function thread.lastRun(id) return (threads[id]) and threads[id].lastRun or -1 end -- Get amount of time execution of the thread took on the last run

function thread.sleep(t) -- Yield and suspend execution of the current thread for the specified number of seconds
	if (t) then
		threads[current].resumeAt = computer.uptime() + t
		threads[current].state = thread.sleeping
	else
		threads[current].state = thread.waiting -- Resume the thread asap if no time is given
	end
	coroutine.yield()
end

----------- Helper functions -----------

local function getNearest() -- Get how long before the next thread needs to be executed
	local l = math.huge
	for i,p in pairs(threads) do
		if (p.state == thread.waiting) then -- If a thread is waiting for execution, resume asap
			return 0
		elseif (p.state == thread.sleeping) then
			l = math.min(l, p.resumeAt)
		end
	end
	return l
end

local function getQueue() -- Create a queue of threads to execute, respecting priority and ignoring sleeping/suspended threads
	local queue = {}
	for i,p in pairs(threads) do
		if (p.state == thread.sleeping and computer.uptime() >= p.resumeAt) then
			p.state = thread.waiting
			queue[p.priority] = queue[p.priority] or {}
			table.insert(queue[p.priority], p)
		elseif (p.state == thread.waiting) then
			queue[p.priority] = queue[p.priority] or {}
			table.insert(queue[p.priority], p)
		end
	end
	local normalizedQueue = {}
	for i,p in pairs(queue) do table.insert(normalizedQueue, p) end
	return queue
end

----------- End helper functions -----------

function beginThreadExecution()
	beginThreadExecution = nil
	while (true) do
		local timeBefore = computer.uptime()
		thread.current = 0
		computer.pullSignal(getNearest()) -- TODO: Dispatch this to the Events module once that is written
		local queue = getQueue()
		
		for i=#queue,1,-1 do --Execute from highest priority to lowest
			for _,t in pairs(queue[i]) do
				local beforeExec = computer.uptime()
				thread.current = t.id
				t.state = thread.running
				local timeSince = computer.uptime() - t.yieldedAt
				local s = pcall(coroutine.resume, t.routine, timeSince) -- Pass the time since the thread yielded
				thread.current = 0
				if (s and thread.state ~= thread.dead) then -- Kill the thread if it errored or was manually killed during execution
					if (t.state == thread.runnning) then t.state = thread.waiting end
					t.yieldedAt = computer.uptime()
					t.lastRun = computer.uptime() - beforeExec
				else
					t.state = thread.dead
					threads[t.id] = nil
				end
			end
		end
		
		thread.lastRun = computer.uptime() - timeBefore
	end
end









