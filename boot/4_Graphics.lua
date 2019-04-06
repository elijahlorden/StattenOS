-- Graphics Library --
gl = {}
graphics = gl

local screenAddress, gpu, gpuGetBackground, gpuSetBackground, gpuGetForeground, gpuSetForeground, gpuMaxResolution, gpuGetResolution, gpuSetResolution, gpuGet, gpuSet, gpuCopy, gpuFill

local mathFloor, mathCeil, mathAbs, mathMin, mathMax = math.floor, math.ceil, math.abs, math.min, math.max
local tableInsert, tableConcat = table.insert, table.concat

gl.controls = {
	frame = { --  required {pos:'auto' or range(int), size: ange(int or percentage)} optional {color:int [0xFFFFFF], text:string [""], textcolor:int [0xFFFFFF]}
		draw = function(f)
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
gl.getScreen = function() return screen end

local function bindScreen(screena) -- Bind a screen to the currently bound GPU
	gpu.bind(screena)
	screenAddress = screena
end
gl.bindScreen = bindScreen

local function available()
	return (gpu ~= nil) and (screen ~= nil)
end
gl.available = available

local function getBounds()
	return bufferWidth, bufferHeight
end
gl.getBounds = getBounds

local function rendererSort(name, list)
	local sorted = {}
	
	
	
	
	return sorted
end

gl.drawFooter = function()
	if (not available()) then return end
	local usedMem = math.ceil(((computer.totalMemory() - computer.freeMemory())/computer.totalMemory())*100)
	if (gpuGetBackground() ~= 0xCCCCCC) then gpuSetBackground(0xCCCCCC) end
	if (gpuGetForeground() ~= 0xFFFFFF) then gpuSetForeground(0xFFFFFF) end
	local resX, resY = gpuGetResolution()
	local col = resX
	local footer = "Memory: "
end







bindGPU(component.list("gpu")())
bindScreen(component.list("screen")())

