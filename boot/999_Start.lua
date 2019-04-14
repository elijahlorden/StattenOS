local gpu = graphics.getGPU()
--[[ EVENTS TEST

local callback 
callback = function(e, a, c, code, plr)
	gpu.set(1,11,e..", "..c..", "..code..", "..plr)
	event.ignore("key_up", callback)
end

local reg = event.listen("key", callback)

event.listen("component", function(e)
	gpu.set(1,12,e)
end)

if (reg) then gpu.set(1,9, "registered event") end

while (true) do
	local e, a, c, code, plr = event.pull("key_up", 0.1)
	if (e) then
		gpu.set(1,10,e..", "..c..", "..code..", "..plr)
	end
	gpu.set(1,20,tostring((computer.totalMemory() - computer.freeMemory())/1024))
end
--]]


local resX, resY = gpu.getResolution()

local start = computer.uptime()

local docfile = boot:load("pages/test.sml")
local doc, reason = sml.parse(docfile)
if (not doc) then error(reason) end
local dom = controls.initDOM(doc)

local calls = controls.getCalls(dom, {1,1})
gl.doDrawCalls(calls)

--gpu.set(1,19,tostring(computer.uptime() - start))

local tid = thread.new(1, function()
	local times = 0
	while true do
		--gl.getGPU().set(60,2,tostring(times))
		local t, e, a, b, c, d = thread.pullEvent("key_down", math.huge)
		--gl.getGPU().set(60,3,tostring(e))
		times = times + 1
	end
end)
thread.resume(tid)

local threadTick = thread.threadTick
while(true) do
	threadTick()
	--gpu.set(1,20,tostring((computer.totalMemory() - computer.freeMemory())/1024))
	--desktop.drawhf(true)
end




