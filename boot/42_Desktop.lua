-- StattenOS Desktop and Window Modules --
desktop = {}
window = {}
do
	local gpu = gl.getGPU()
	local resX, resY = 0,0
	if (gpu) then
		resX, resY = gpu.getResolution()
	end
	local tableinsert, stringsub, stringlen = table.insert, unicode.sub, unicode.len
	local windows = {}
	local nextwid = 1
	local vwindows = {} -- A buffer array for drawing windows
	local taskbuttons = {} -- A list of the x-axis positions and widths of the tastlist
	--[[
		{
			"name of window",
			id,
			{Window event listeners},
			{Page DOM},
			
		}
	--]]
	local focused = 0 -- The currenlty focused window (0 = no focused window)
	local scroll = 1 -- How far right the taskbar is scrolled (1-indexed)
	local canScroll = false
	local mode = 0 -- 0 = Window has control, 1 = Menu has control, 2 = Popup has control
	-- Header/Footer stuff --
	local hthread
	local fbCol, ffCol, menufcol, tlwbcol, tlfwfcol, tlwfcol =
	gl.gpick(0x000000, 0x777777, 0x979a9e), -- Footer main background color
	gl.gpick(0xFFFFFF, 0xFFFFFF, 0xd5dfef), -- Footer main foreground color
	gl.gpick(0xFFFFFF, 0xAAAAFF, 0x3677ed),	-- Menu button foreground color
	gl.gpick(0x000000, 0xAAAAAA, 0xadb2ba),	-- Tasklist background color
	gl.gpick(0xFFFFFF, 0xFFFF00, 0xc1d7ff),	-- Tasklist focused window foreground color
	gl.gpick(0xFFFFFF, 0xEEEEEE, 0xeeeeee)	-- Tasklist window foreground color
	
	local dynfPos = 1000
	local function drawFooter() -- Draw the live portion of the footer
		if (not gl.available()) then return end
		if (gpu.getBackground() ~= fbCol) then gpu.setBackground(fbCol) end
		if (gpu.getForeground() ~= ffCol) then gpu.setForeground(ffCol) end
		local freeMem, totalMem = math.ceil(computer.freeMemory()/1024), math.ceil(computer.totalMemory()/1024)
		local usedMem = totalMem - freeMem
		local memtxt = "Mem: "..text.padLeft(tostring(math.ceil((usedMem/totalMem)*100)), 3, " ").."%"
		local cputxt = "CPU: "..text.padLeft(tostring(math.ceil((event.avgClock()*1000)/5000)),3," ").."%"
		local ftxt = "|"..memtxt.."|"..cputxt.."|"
		local rdtl = (resX-stringlen(ftxt)+1 ~= dynfPos)
		dynfPos = resX-stringlen(ftxt)+1
		gpu.set(dynfPos, resY, ftxt)
		if (rdtl) then desktop.drawTasklist() end
	end
	desktop.drawFooter = drawFooter
	
	local function normalizevwindows()
		if (#vwindows <= 0) then return {} end
		local nvwindows = {}
		for i,p in pairs(vwindows) do
			if (p) then
				tableinsert(nvwindows, p)
			end
		end
		return nvwindows
	end
	
	local touchedWindow
	local dragging = false
	local menutxt = "☰☰☰"
	local scrllbtns = "◄── ──►" -- If not 7 characters long, change the magic numbers below (good luck)
	local maxNameLen = gl.gpick(8, 20, 25)
	local function drawTasklist() -- Draw the list of open vwindows
		touchedWindow = nil
		if (not gl.available()) then return end
		::RETRY::
		local wtext, ftext, fpos = "", "", -1 -- wtext is all non-focused vwindows, ftext is the focused window
		taskbuttons = {}
		if (#vwindows > 0) then
			local list = normalizevwindows()
			scroll = math.max(1, math.min(#list, scroll)) -- Constrain scroll value
			local x = stringlen(menutxt) + 3
			for i=scroll,#list do
				local w = list[i]
				local wname = (#w[1] <= maxNameLen) and w[1] or stringsub(w[1], 1, maxNameLen-1).."…"
				if (x + 2 + stringlen(wname) <= dynfPos - stringlen(menutxt) - stringlen(scrllbtns) - 4) then
					if (w[2] == focused) then
						ftext = "["..wname.."]"
						fpos = x + 1
						wtext = wtext..string.rep(" ", stringlen(wname)+3)
					else
						wtext = wtext.." ["..wname.."]"
					end
					tableinsert(taskbuttons, {w[2], x + 2, x + 3 + #wname})
					x = x + 3 + #wname
					if (i == #list and scroll == 1) then canScroll = false end -- If the entire list is drawn, disable scrolling
				else
					canScroll = true -- If the list is cut off, enable scrolling
					break
				end
			end
			wtext = wtext.." "
		end
		if (#wtext <= 2) then -- If nothing was drawn, either reset the scroll value or decrement it and retry the draw
			if (#vwindows > 0 and scroll > 1) then
				scroll = scroll - 1 -- Decrement the scroll value and try again
				goto RETRY
			else
				scroll = 1
			end
		end
		-- Draw the task list
		if (gpu.getBackground() ~= fbCol) then gpu.setBackground(fbCol) end
		-- Draw the menu and scroll buttons
		if (gpu.getForeground() ~= menufcol) then gpu.setForeground(menufcol) end
		gpu.set(1,resY," "..menutxt.." ")
		if (canScroll) then
			if (gpu.getForeground() ~= tlwfcol) then gpu.setForeground(tlwfcol) end
			gpu.set(dynfPos-9,resY, " "..scrllbtns.." ")
		end
		-- Draw the window list
		if (gpu.getBackground() ~= tlwbcol) then gpu.setBackground(tlwbcol) end
		if (gpu.getForeground() ~= tlwfcol) then gpu.setForeground(tlwfcol) end
		gpu.set(stringlen(menutxt) + 3, resY, string.rep(" ", (canScroll) and (dynfPos - stringlen(menutxt) - stringlen(scrllbtns) - 5) or (dynfPos - stringlen(menutxt) - 3)))
		gpu.set(stringlen(menutxt) + 3, resY , wtext)
		if (ftext) then
			gpu.setForeground(tlfwfcol)
			gpu.set(fpos, resY, ftext)
		end

	end
	desktop.drawTasklist = drawTasklist
	
	local function fireEvent(wid, ...)
		
	end
	
	local function listen(wid, callback)
		
	end
	
	local function focusWindow(wid) -- Change focus to the specified window
		if (wid == focused) then return true end
		if (not windows[wid]) then return false end
		fireEvent(focus, "unfocused")
		focused = wid
		fireEvent(wid, "focused")
		drawTasklist()
		return true
	end
	desktop.focusWindow = focusWindow
	
	local wlisten = function(e, callback)
		
	end
	desktop.listen = wlisten
	
	local function newWindow(name)
		local wid = nextwid
		nextwid = nextwid + 1
		windows[wid] = {
			name,
			wid,
			nil,
			nil
		}
		tableinsert(vwindows, windows[wid])
		drawTasklist()
		return wid
	end
	desktop.newWindow = newWindow
	
	local function closeWindow(wid)
		local w = windows[wid]
		if (not w) then return true end
		windows[wid] = nil
		for i,p in pairs(vwindows) do if (p and p[2] == wid) then vwindows[i] = nil drawTasklist() break end end
		return true
	end
	desktop.closeWindow = closeWindow
	
	hthread = thread.new(0, function()
		while true do
			drawFooter()
			thread.sleep(1.5)
		end
	end)
	thread.resume(hthread)
	
	-- Event Listeners --
	local scrollTouch, rclick = false
	event.listen("touch", function(_, screena, x, y, button, plr)
		scrollTouch = 0
		dragging = false
		rclick = (button == 1)
		if (y ~= resY) then return end
		if (canScroll and not rclick) then
			local scrllpos = dynfPos - stringlen(scrllbtns) - 1
			if (x >= scrllpos and x <= scrllpos + 2) then scrollTouch = -1 return elseif (x >= scrllpos + 4 and x <= scrllpos + 6) then scrollTouch = 1 return end
		end
		for i=1,#taskbuttons do
			local w = taskbuttons[i]
			if (w[2] <= x and w[3] >= x) then touchedWindow = w break end
		end
	end)
	
	event.listen("drag", function(_, screena, x, y, button, plr)
		if (not touchedWindow or rclick) then return end
		if (touchedWindow[2] <= x and touchedWindow[3] >= x) then return end -- Still dragging within the current window
		dragging = true
		local swapWindow
		for i=1,#taskbuttons do
			local w = taskbuttons[i]
			if (w[2] <= x and w[3] >= x) then swapWindow = w break end
		end
		if (swapWindow and swapWindow ~= touchedWindow) then
			local i1,i2
			for i=1,#vwindows do
				if (vwindows[i][2] == swapWindow[1]) then i1 = i end
				if (vwindows[i][2] == touchedWindow[1]) then i2 = i end
				if (i1 and i2) then break end
			end
			if (i1 and i2) then
				local w1 = vwindows[i1]
				vwindows[i1] = vwindows[i2]
				vwindows[i2] = w1
				local neww
				drawTasklist()
				for i=1,#taskbuttons do
				local w = taskbuttons[i]
					if (w[2] <= x and w[3] >= x) then neww = w break end
				end
				touchedWindow = neww
			end
		end
	end)
	
	event.listen("drop", function(_, screena, x, y, button, plr)
		if (dragging and touchedWindow) then
			dragging = false
		elseif (rclick and touchedWindow) then
			closeWindow(touchedWindow[1])
		elseif (scrollTouch ~= 0) then
			scroll = scroll + scrollTouch
			drawTasklist()
		elseif (touchedWindow) then
			focusWindow(touchedWindow[1])
			dragging = false
		end
		touchedWindow = nil
	end)
	
	event.listen("scroll", function(_, screena, x, y, dir, plr)
		if (not canScroll or y ~= resY or x > dynfPos - stringlen(scrllbtns) - 2) then return end
		scroll = scroll + ((dir > 0) and 1 or -1)
		drawTasklist()
	end)
	
	local twthread = thread.new(0, function()
		thread.sleep(1)
		local wid = newWindow("Test")
		
	end)
	thread.resume(twthread)
	
	drawFooter()
	drawTasklist()
end



