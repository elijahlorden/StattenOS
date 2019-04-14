-- StattenOS Desktop Module --
desktop = {}

do
	local mode = 0 -- 0 = Page has control, 1 = Menu has control, 2 = Popup has control
	-- Header/Footer stuff --
	local hthread
	local hfbCol, hffCol = 0x979a9e, 0xd5dfef
	local function drawhf(redraw) -- Draw the header and footer
		if (not gl.available()) then return end
		local gpu = gl.getGPU()
		local resX, resY = gpu.getResolution()
		if (gpu.getBackground() ~= hfbCol) then gpu.setBackground(hfbCol) end
		if (gpu.getForeground() ~= hffCol) then gpu.setForeground(hffCol) end
		-- Header (OS name, version)
		local ostxt = (os.name or "StattenOS").." v"..(os.version or "?.?.?")
		local filltxt = string.rep(" ", resX-(ostxt:len()))
		local htxt = ostxt..filltxt
		gpu.set(1,1,htxt)
		-- Footer (Memory/CPU/Network usage)
		local freeMem, totalMem = math.ceil(computer.freeMemory()/1024), math.ceil(computer.totalMemory()/1024)
		local usedMem = totalMem - freeMem
		local memtxt = "Memory: "..text.padLeft(tostring(usedMem),4," ").."k/"..tostring(totalMem).."k ("..tostring(math.ceil((usedMem/totalMem)*100)).."%)"
		local cputxt = ("CPU: "..text.padLeft(tostring(math.ceil(event.avgClock()*1000)),4," ").."ms/5000ms"):sub(1,20)
		local rtxt = " | "..cputxt..string.rep(" ", 16 - cputxt:len()).." | "..memtxt..string.rep(" ", 25 - memtxt:len())
		local ltxt = ""
		local mfill = string.rep(" ", resX - ltxt:len() - rtxt:len())
		gpu.set(1, resY, ltxt..mfill..rtxt)
	end
	desktop.drawhf = drawhf
	
	hthread = thread.new(0, function()
		while true do
			drawhf()
			thread.sleep(1)
		end
	end)
	thread.resume(hthread)
	
	-- Event Listeners --
	event.listen("touch", function(_, screena, x, y, button, plr)
		
	end)
	
	
	
	
	
	
	
	
end




