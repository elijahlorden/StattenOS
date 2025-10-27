do
    local activeThreads = Pool()
    local sleepingThreads = Pool()
    local pullingThreads = Pool()
    local signalPools = {}
    local dirtyThreads = Pool()
    
    -- ================================= Thread Class ================================= --
    
    local Thread = Class(function(Thread)

        function Thread.state:get() return self._state end -- States: suspended, sleeping, pulling, active, dead
        function Thread.name:get() return self._name or Class.tableAddress(self) end
        
        function Thread:init(f, name)
            checkArg(1, f, "function")
            self._name = name
            self._coroutine = coroutine.create(f)
            self._state = "suspended"
        end
        
        function Thread:kill()
            if (self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "dead"
        end
        
        function Thread:resume()
            if (self._state == "active" or self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "active"
        end
        
        function Thread:suspend()
            if (self._state == "suspended" or self._state == "dead") then return end
            dirtyThreads:add(self)
            self._state = "suspended"
            if (_G.Thread._current == self) then self._yieldedAt = computer.uptime() return coroutine.yield() end
        end
        
        function Thread:sleep(t)
            if (self._state == "dead") then return end
            if (self._state ~= "sleeping") then dirtyThreads:add(self) end
            self._state = "sleeping"
            self._resumeAt = computer.uptime() + t
            if (_G.Thread._current == self) then self._yieldedAt = computer.uptime() return coroutine.yield() end
        end
        
    end)
    
    Thread._onError = function(thread, err, trace)
        os.log("Erron in thread '"..thread.name.."': "..err.."\n"..trace)
    end
    
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
        checkArg(1, t, "number")
        if (not Thread._current) then error("Attemped to call Thread.sleep() from the main thread", 2) end
        Thread._current:sleep(t)
    end
    
    function Thread.pull(signal, timeout)
        checkArg(1, signal, "string")
        checkArg(2, timeout, "nil", "string")
        local thread = Thread._current
        if (not thread) then error("Attemped to call Thread.pull() from the main thread", 2) end
        os.log("Thread "..thread.name.." pulling "..signal)
        if (thread._state == "pulling") then
            if (thread._pullSignal ~= signal) then -- Remove this thread from the original singal pool and add it to the new one, no need to mark dirty
                local pool = signalPools[thread._pullSignal]
                if (pool) then pool:remove(thread) end
                pool = signalPools[signal]
                if (not pool) then
                    pool = Pool()
                    signalPools[signal] = pool
                end
                pool:add(thread)
            end
        else
            dirtyThreads:add(thread)
            thread._state = "pulling"
        end
        thread._pullSignal = signal
        thread._resumeAt = computer.uptime() + (timeout or math.huge)
        return coroutine.yield()
    end
    
    -- ================================= Internal Functions ================================= --
    
    Thread._current = nil
    Thread.maxTime = 5 -- Default yield timeout
    
    local function processDirtyThreads()
        while (#dirtyThreads > 0) do
            local dirtyThread = dirtyThreads[#dirtyThreads]
            dirtyThreads:remove(dirtyThread)
            os.log("Processing dirty thread "..dirtyThread.name)
            -- Remove from old pools
            if (dirtyThread._state ~= "active") then activeThreads:remove(dirtyThread) end
            if (dirtyThread._state ~= "sleeping") then sleepingThreads:remove(dirtyThread) end
            if (dirtyThread._state ~= "pulling" and pullingThreads:contains(dirtyThread)) then
                pullingThreads:remove(dirtyThread)
                local dirtySignal = dirtyThread._pullSignal
                local pool = signalPools[dirtySignal]
                if (pool) then pool:remove(dirtyThread) end
            end
            -- Add to new pool
            if (dirtyThread._state == "active") then activeThreads:add(dirtyThread) Thread.minResumeTime = 0 end
            if (dirtyThread._state == "sleeping") then
                sleepingThreads:add(dirtyThread)
                Thread.minResumeTime = math.min(Thread.minResumeTime, dirtyThread._resumeAt)
            end
            if (dirtyThread._state == "pulling" and not pullingThreads:contains(dirtyThread)) then
                pullingThreads:add(dirtyThread)
                Thread.minResumeTime = math.min(Thread.minResumeTime, dirtyThread._resumeAt)
                local dirtySignal = dirtyThread._pullSignal
                local pool = signalPools[dirtySignals]
                if (not pool) then
                    pool = Pool()
                    signalPools[dirtySignal] = pool
                end
                pool:add(dirtyThread)
                os.log("Added thread"..dirtyThread.name.." to signal pool "..dirtySignal)
            end
        end
    end
    
    local function resumeThread(thread, ...)
        local co = thread._coroutine
        if (coroutine.status(co) == "dead") then
            if (thread._state ~= "dead") then thread:kill() end
            return
        end
        --os.log("Resuming thread "..thread.name)
        local timeSinceYield = thread._yieldedAt and (thread.yieldedAt - computer.uptime()) or 0
        Thread._current = thread
        local ok, err = coroutine.resume(co, timeSinceYield, ...)
        Thread._current = nil
        if (not ok and Thread._onError) then Thread._onError(thread, err, debug.traceback(co)) end
        if (coroutine.status(co) == "dead") then
            thread:kill()
        end
        if (thread.state == "active") then
            Thread.minResumeTime = 0
        elseif (Thread._state == "sleeping" or Thread._state == "pulling") then
            Thread.minResumeTime = math.min(Thread.minResumeTime, thread._resumeAt)
        end
    end
    
    function Thread._update()
        local signal = table.pack(computer.pullSignal(math.max(0, Thread.minResumeTime - computer.uptime())))
        --os.log("Update: "..tostring(signal[1]))
        event.dispatch(table.unpack(signal))
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
            if (not resumedThreads[thread]) then
                if (startTime > thread._resumeAt) then
                    resumeThread(thread)
                else
                    Thread.minResumeTime = math.min(Thread.minResumeTime, thread._resumeAt)
                end
            end
        end
        
        for i=1,#sleepingThreads do
            local thread = sleepingThreads[i]
            if (startTime > thread._resumeAt) then
                resumeThread(thread)
            else
                Thread.minResumeTime = math.min(Thread.minResumeTime, thread._resumeAt)
            end
        end
        
        for i=1,#activeThreads do
            resumeThread(activeThreads[i])
        end
        
        processDirtyThreads()
        
        Thread.lastTime = os.clock() - startTime
        Thread.usage = Thread.lastTime / Thread.maxTime
    end
    
    function Thread._autoUpdate()
        Thread.minResumeTime = 0
        while true do
            Thread._update()
        end
    end
    
    _G.Thread = Thread
end