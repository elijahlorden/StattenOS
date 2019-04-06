local gpu = graphics.getGPU()

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

