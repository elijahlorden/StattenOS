-- Graphics Library --
gl = {}
graphics = gl

local logf = "graphics"

local screenAddress, gpu, gpuGetBackground, gpuSetBackground, gpuGetForeground, gpuSetForeground, gpuMaxResolution, gpuGetResolution, gpuSetResolution, gpuGet, gpuSet, gpuCopy, gpuFill

local mathfloor, mathceil, mathabs, mathmin, mathmax = math.floor, math.ceil, math.abs, math.min, math.max
local tableinsert, tableconcat = table.insert, table.concat
local sub, len = unicode.sub, unicode.len

gl.controls = {
	frame = {
		draw = function(f, drawContent)
			if (not gl.available()) then return end
			local fcol, tcol, x, y, w, h, t = f.color or 0xFFFFFF, f.textcolor or 0xFFFFFF, f.x, f.y, f.w, f.h, f.text or ""
			local sides = string.rep("┃",f.h-2)
			local bottom = "┗"..string.rep("━",w-2).."┛"
			local top = (f.text ~= nil) and "┏┥"..string.rep(" ",t:len()).."┝"..string.rep("━",w - t:len() - 4).."┓" or "┏"..string.rep("━",w - 2).."┓"
			if (gpuGetForeground() ~= fcol) then gpuSetForeground(fcol) end
			gpuSet(x, y, top)
			gpuSet(x, y+1, sides, true)
			gpuSet(x+w-1, y+1, sides, true)
			gpuSet(x, y+h-1, bottom)
			if (f.text) then
				if (gpuGetForeground() ~= tcol) then gpuSetForeground(tcol) end
				gpuSet(x+2, y, t)
			end
		end;
	};
	
	
	
	
}

local function bindGPU(gpua) -- Get a GPU proxy and bind it's methods to local fields
	gpu = component.proxy(gpua)
	if (gpu) then
		gpuGetBackground = gpu.getBackground
		gpuSetBackground = gpu.setBackground
		gpuGetForeground = gpu.getForeground
		gpuSetForeground = gpu.setForeground
		gpuMaxResolution = gpu.maxResolution
		gpuGetResolution = gpu.getResolution
		gpuSetResolution = gpu.setResolution
		gpuGet = gpu.get
		gpuSet = gpu.set
		gpuCopy = gpu.copy
		gpuFill = gpu.fill
	end
end
gl.bindGPU = bindGPU

gl.getGPU = function() return gpu end
gl.getGPUTier = function()
	if (not gpu) then return 0 end
	local depth = gpu.maxDepth()
	return (depth == 1) and 1 or ((depth == 4) and 2 or ((depth == 8) and 3 or 4))
end
gl.getScreen = function() return screen end

local function bindScreen(screena) -- Bind a screen to the currently bound GPU
	gpu.bind(screena)
	screenAddress = screena
end
gl.bindScreen = bindScreen

local function available()
	return (gpu ~= nil) and (screenAddress ~= nil)
end
gl.available = available

local function getBounds()
	return bufferWidth, bufferHeight
end
gl.getBounds = getBounds

local function truncateCall(call, vx, vy, vmx, vmy) -- Truncate a call to a viewport, returns nil if the call is not within the viewport at all
	local callName, cx, cy = call[1], call[2], call[3]
	if (callName == "seth") then
		local ctxt = call[6]
		local cw = len(ctxt)
		if (cx > vmx or cy > vmy or cx+cw < vx or cy < vy) then return nil end
		if (vx > cx) then ctxt = sub(ctxt,vx-cx) cx = vx cw = len(ctxt) end
		if (cx+cw > vmx) then ctxt = sub(ctxt,1,vmx-(cx+cw)) end
		call[2], call[6] = cx, ctxt
		return call
	elseif (callName == "setv") then
		local ctxt = call[6]
		local ch = len(ctxt)
		if (cx > vmx or cy > vmy or cy+ch < vy or cx < vx) then return nil end
		if (vy > cy) then ctxt = sub(ctxt,vy-cy) cy = vy ch = len(ctxt) end
		if (cy+ch > vmy) then ctxt = sub(ctxt,1,vmy-(cy+ch)) end
		call[3], call[6] = cy, ctxt
		return call
	elseif (callName == "fill") then
		cx, cy = mathmax(cx, vx), mathmax(cy, vy)
		local cmx, cmy = mathmin(vmx, cx+call[4]), mathmin(vmy, cy+call[5])
		if (cx > cmx or cy > cmy) then return nil end
		local cw, ch = cmx-cx, cmy-cy
		if (cw <= 0 or ch <= 0) then return nil end
		call[1], call[2], call[3], call[4] = cx, cy, cw, ch
	end
end
gl.truncateCall = truncateCall

local function doDrawCalls(calls, report) -- Perform a list of draw calls.  Call Format: {callName, x, y[,w, h], bcol, fcol, txt} If report is true, a summary of the calls will be appended to log/graphics.log
	if (report) then os.log(logf, "Starting new draw cycle") end
	local timebefore = os.clock()
	local sethcalls, setvcalls, fillcalls, setfcalls, setbcalls = 0,0,0,0,0
	for _,call in pairs(calls) do
		local bcol = (call[1] == "fill") and call[6] or call[4]
		local fcol = (call[1] == "fill") and call[7] or call[5]
		if (gpuGetBackground() ~= bcol) then gpuSetBackground(bcol) setbcalls = setbcalls + 1 end
		if (gpuGetForeground() ~= fcol) then gpuSetForeground(fcol) setfcalls = setfcalls + 1 end
		if (call[1] == "seth") then
			sethcalls = sethcalls + 1
			gpuSet(call[2], call[3], call[6])
		elseif (call[1] == "setv") then
			setvcalls = setvcalls + 1
			gpuSet(call[2], call[3], call[6], true)
		elseif (call[1] == "fill") then
			fillcalls = fillcalls + 1
			gpuFill(call[2], call[3], call[4], call[5], call[7])
		else
			if (report) then os.log(logf, "Unknown draw call '"..call[1].."'") end
		end
	end
	if (report) then
		os.log(logf, tostring(setfcalls).." foreground set calls")
		os.log(logf, tostring(setbcalls).." background set calls")
		os.log(logf, tostring(sethcalls).." horizontal set calls")
		os.log(logf, tostring(setvcalls).." vertical set calls")
		os.log(logf, tostring(fillcalls).." fill calls")
		os.log(logf, "Drawing took "..tostring(os.clock() - timebefore).." seconds")
	end
end
gl.doDrawCalls = doDrawCalls






bindGPU(component.list("gpu")())
bindScreen(component.list("screen")())

