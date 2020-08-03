-- StattenOS default library extensions --

do -- This is relying on the boot filesystem API, implemented in init.lua (DO NOT USE 'boot' AFTER FILES IN /boot/ HAVE BEEN LOADED)
	-- Read the osmeta file
	if (boot:exists("osmeta")) then
		local s,r = boot:load("osmeta")
		if (not s) then error(r) end
		for p,v in s:gmatch("%s-([^%s]+)::([^;]+);") do
			if (p == "n") then
				os.name = v
			elseif (p == "v") then
				os.version = v
			elseif (p == "d") then
				os.pdev = v
			elseif (p == "c") then
				os.ctbrs = v
			end
		end
	else
		os.name = "StattenOS"
		os.version = "#.#.#"
	end
	
	local bootfs = boot -- TODO: Remove this when the real filesystem library is implemented
	
	local lastLog, lastLogHandle = "", nil
	local mainlog
	os.log = function(f, s)
		if (not bootfs:exists("log/") or not bootfs:isDirectory("log/")) then bootfs:makeDirectory("log/") end
		if (not mainlog) then mainlog = bootfs:open("log/log.log", "a") end
		local path = "log/"..f..".log"
		local h,r
		if (lastLog == f) then
			h = lastLogHandle
		else
			h,r = bootfs:open(path, "a")
			if (lastLogHandle) then boot:close(lastLogHandle) end
			lastLog = f
			lastLogHandle = h
		end
		if (h) then
			bootfs:write(h, s.."\n")
		end
		bootfs:write(mainlog, s.."\n")
	end
	
end

-- Generate a lookup table for quick key-based lookups
function lookuptable(...)
	local tArgs = {...}
	local t = {}
	for i=1,#tArgs do t[tArgs[i]] = true end
	return t
end

-- Create a shallow copy of a table
function shallowCopy(source)
	local dest = {}
	for i,p in pairs(source) do dest[i] = p end
	return dest
end

-- Shallow-compare two tables
local shallowCompare = function(t1, t2)
	if (type(t1) ~= "table" or type(t2) ~= "table") then return false end
	for i,p in pairs(t1) do if (t2[i] ~= p) then return false end end
	for i,p in pairs(t2) do if (t1[i] ~= p) then return false end end
	return true
end







