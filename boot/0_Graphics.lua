-- Graphics Library --
gl = {}

local gpu, gpuGetBackground, gpuSetBackground, gpuGetForeground, gpuSetForeground, gpuMaxResolution, gpuGetResolution, gpuSetResolution, gpuGet, gpuSet, gpuCopy, gpuFill

local mathFloor, mathCeil, mathAbs, mathMin, mathMax = math.floor, math.ceil, math.abs, math.min, math.max
local tableInsert, tableConcat = table.insert, table.concat

gl.controls = {
	frame = { -- <frame pos(req), size(req), color[0xFFFFFF], text[""], textcolor[0xFFFFFF]/>
		draw = function(f)
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
gl.bindGPU = bindGPU

gl.getGPU = function() return gpu end

local function bindScreen(screena) -- Bind a screen to the currently bound GPU
	gpu.bind(screena)
end
gl.bindScreen = bindScreen

local function getBounds()
	return bufferWidth, bufferHeight
end
gl.getBounds = getBounds

local function rendererSort(name, list)
	local sorted = {}
	
	
	
	
	return sorted
end








local function drawFrame(x, y, w, h, fcol, t, tcol) -- Draw a single frame
	local top1, top2 = "┏┥", "┝"..string.rep("━",w - t:len() - 4).."┓"
	local sides = string.rep("┃",h-2)
	local bottom = "┗"..string.rep("━",w-2).."┛"
	if (gpuGetForeground() ~= fcol) then gpuSetForeground(fcol) end
	gpuSet(x, y, top1)
	gpuSetForeground(tcol)
	gpuSet(x+2, y, t)
	gpuSetForeground(fcol)
	gpuSet(x+2+t:len(), y, top2)
	gpuSet(x, y+1, sides, true)
	gpuSet(x+w-1, y+1, sides, true)
	gpuSet(x, y+h-1, bottom)
end
gl.drawFrame = drawFrame








bindGPU(component.list("gpu")())
bindScreen(component.list("screen")())

