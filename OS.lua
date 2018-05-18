OS = {}
OS.Name = "StattenOS"
OS.Version = "0.0.1"
OS.modules = {}
OS.allowedRootFiles = {"drivers/", "miniapps/", "modules/", "tmp/", "config", "CoreLibs.lua", "init.lua", "Keyboard.lua", "OS.lua"}

function OS.sleep(timeout)
	checkArg(1, timeout, "number", "nil")
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		event.pull(deadline - computer.uptime())
	until computer.uptime() >= deadline
end

function loadfile(file, mode, env)
  local handle, reason = filesystem.open(file)
  if not handle then
    error(reason, 2)
  end
  local buffer = ""
  repeat
    local data, reason = filesystem.read(handle)
    if not data and reason then
      error(reason)
    end
    buffer = buffer .. (data or "")
  until not data
  filesystem.close(handle)
  if mode == nil then mode = "bt" end
  if env == nil then env = _G end
  return load(buffer, "=" .. file)
end

function dofile(file)
  local program, reason = loadfile(file)
  if program then
    local result = table.pack(pcall(program))
    if result[1] then
      return table.unpack(result, 2, result.n)
    else
      error(result[2])
    end
  else
    error(reason)
  end
end

-- core libraries

event = event_code()
component_code()
text = text_code()
filesystem = fs_code()
fs = filesystem
keyboard = dofile("/Keyboard.lua")
term = terminal_code()

event_code, component_code, text_code, fs_code, terminal_code = nil, nil, nil, nil, nil

-- bind GPU

if term.isAvailable() then
  component.gpu.bind(component.screen.address)
  component.gpu.setResolution(component.gpu.getResolution())
  component.gpu.setBackground(0x000000)
  component.gpu.setForeground(0xFFFFFF)
  term.setCursorBlink(false)
  term.clear()
end

print("Starting "..OS.Name.." "..OS.Version)

function kernelError()
	printErr("\nPress any key to try again.")
	term.readKey()
end

local function interrupt(data)
	if data[2] == "RUN" then miniOS.runfile(data[3], table.unpack(data[4])) end
end

local function runfile(file, ...)
	local program, reason = loadfile(file)
	if program then
		local result = table.pack(pcall(program, ...))
			if result[1] then
				return table.unpack(result, 2, result.n)
			else
				if type(result[2]) == "table" then if result[2][1] then if result[2][1] == "INTERRUPT" then interrupt(result[2]) return end end end
				error(result[2], 3)
			end
	else
		error(reason, 3)
	end
end

function newResponse()
	local tbl = {}
	tbl.contents = {}
	tbl.print = function(text)
		table.insert(tbl.contents, {Type = "print", text = text})
	end
	tbl.printPaged = function(text)
		table.insert(tbl.contents, {Type = "printPaged", text = text})
	end
	tbl.getResponse = function() return tbl.contents end
	return tbl
end

function mapToKeyPair(tbl)
	local nt = {}
	local n = 1
	for i,p in pairs(tbl) do
		nt[n] = p
		n = n + 1
	end
	return nt
end

OS.runfile = runfile

loadModules = function(path)
	print("Loading modules in "..path)
	local files = fs.list(path) -- get list of files in the directory 'path'
	for f in files do -- use a FOR loop to iterate over the list of files
		print("Loading module "..path..f)
		retModule = dofile(path..f) -- get the module table that results from executing the file
		_G[f] = retModule -- assign the table to the global namespace
		OS.modules[f] = retModule -- add the module to OS.modules so it can be referenced
	end
end

print()
filesystem.remove("/tmp")
filesystem.makeDirectory("/tmp")
print("Cleared /tmp")

-- Load modules
print()
print("== Load Modules ==")
print()

loadModules("/modules/")

initDrive = fs.drive.getcurrent()

function doInit() -- Initalize modules
	print()
	print("== Initalize Modules ==")
	print()
	
	for i,p in pairs(OS.modules) do
		if (p.init ~= nil) then
			p.init()
		end
	end

	for i,p in pairs(OS.modules) do
		if (p.step ~= nil) then
			event.timer(p.stepInterval or 1, p.step, math.huge)
		end
	end
	print()
end

print()
print("All modules loaded into Memory")
print()
print("Memory: "..tostring(math.floor((computer.totalMemory() - computer.freeMemory())/1024)).."KB used / "..tostring(math.floor(computer.totalMemory()/1024)).."KB total")
print()



OS.memoryMsgStr = function()
	--return "Memory: "..tostring(math.floor((computer.totalMemory() - computer.freeMemory())/1024)).."KB used / "..tostring(math.floor(computer.totalMemory()/1024)).."KB total"
	return "Memory: "..tostring(math.floor((computer.totalMemory() - OS.averageMem())/1024)).."KB used / "..tostring(math.floor(computer.totalMemory()/1024)).."KB total"
end

OS.powerMsgStr = function()
	return "Energy: "..tostring(math.floor(computer.energy())).."/"..tostring(math.floor(computer.maxEnergy()))
end

OS.cleanNils = function(t)
	local ans = {}
	for _,v in pairs(t) do
		ans[ #ans+1 ] = v
	end
	return ans
end

--[[local lf = function(_, localNetworkCard, remoteAddress, port, distance, payload)
	print("Received data '" .. tostring(payload) .. "' from address " .. remoteAddress .." on network card " .. localNetworkCard .. " on port " .. port .. ".")
end

network.registerNetworkListener(lf)
--]]

OS.memAverages = {}

OS.averageMem = function()
	local t = 0
	for _,n in pairs(OS.memAverages) do
		t = t + n
	end
	t = t/#OS.memAverages
	return t
end

OS.doesTableContainString = function(tbl, str, caseSensitive)
	if (caseSensitive == nil) then caseSensitive = true end
	for i,p in pairs(tbl) do
		if (caseSensitive) then
			if (i == str) or (p == str) then return true end
		else
			if (i:lower() == str:lower()) or (p:lower() == str:lower()) then return true end
		end
	end
	return false
end

print("== Cleaning Root Directory ==")
for f in filesystem.list("/") do -- remove unwanted files from root
	if (not OS.doesTableContainString(OS.allowedRootFiles, f, true)) then
		if (f:sub(f:len(), f:len()) == "/") then f = f:sub(0,f:len()-1) end -- remove '/' postfixed to directories
		filesystem.remove(f)
		print("Removed /"..f)
	end
end
print()

doInit() -- Initalize modules

local sec = 0
local memSec = 0
while true do
	OS.sleep(0.01)
	sec = sec + 0.01
	memSec = memSec + 0.01
	if (sec > 1) then sec = 0 end
	if (memSec > 1) then
		table.insert(OS.memAverages, computer.freeMemory())
		if (#OS.memAverages > 20) then table.remove(OS.memAverages, 1) end
	end
end









