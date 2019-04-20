-- StattenOS Controls Library --
controls = {}

controls.propParsers = {
	coordinate = function(s) -- "x,y"
		if (type(s) ~= "string") then return nil end
		local x,y = s:match("([%d-]+)%s-,%s-([%d-]+)")
		x,y = tonumber(x), tonumber(y)
		if (x and y) then return {x,y} end
		return nil
	end;
	
	color = function(s) -- "RRGGBB"
		if (type(s) == "string") then
			return tonumber("0x"..s)
		end
		return nil
	end;
	
	text = function(s)
		return tostring(s)
	end;
	
	number = function(s)
		return tonumber(s)
	end;
}

controls.props = { -- {type, defaultfunc}
	pos 				= {"coordinate", function() return {1,1} end}, 							-- The position of the control
	size 				= {"coordinate", function() return {1,1} end}, 							-- The size of the control
	tier				= {"number", 3}, 														-- (Page tag only) The tier of graphics card this page supports, defaults to 3
	contentOffset 		= {"coordinate", function() return {0,0} end}, 							-- The offset to child controls within the container's content viewport
	bcolor 				= {"color", 0x000000}, 													-- The background color for the control
	fcolor 				= {"color", 0xFFFFFF}, 													-- The foreground color for the control
	textcolor 			= {"color", 0xFFFFFF},													-- The text color for the control
}

controls.types = { -- Control schemas
	frame = {
		isContainer = true;
		interactable = false;
		-- {propname = required}
		props = {pos = true, size = true, bcolor = false, fcolor = false, textcolor = false};
		
		init = function(this) -- Called during DOM init.  For containers, the content viewport should be constrained here. (For example, frames need to set the content viewport to be inside of it's border)
			local size = this:get("size")
			this.contentViewport = {2,2,size[1]-2,size[2]-2} -- Set the content viewport to be inside of the frame border
		end;
		
		interact = function(this, e, a, x, y, t, playerName) -- Called with touch/drag/drop/scroll event parameters, coordinates are transformed to be relative to the control
			
		end;
		
		drawCalls = function(this, x, y) -- Return the (relative) draw calls required to render this control
			local bcol, fcol, tcol = this:get("bcolor"), this:get("fcolor"), this:get("textcolor")
			local size = this:get("size")
			local text = this:get("text") or this.innerText
			local sides = string.rep("┃",size[2]-2)
			local bottom = "┗"..string.rep("━",size[1]-2).."┛"
			local top = (text ~= nil) and "┏┥"..string.rep(" ",text:len()).."┝"..string.rep("━",size[1] - text:len() - 4).."┓" or "┏"..string.rep("━",size[1] - 2).."┓"
			local calls = {
				{"seth", x, y, bcol, fcol, top},
				{"setv", x, y+1, bcol, fcol, sides},
				{"setv", x+size[1]-1, y+1, bcol, fcol, sides},
				{"seth", x, y+size[2]-1, bcol, fcol, bottom},
			}
			if (text) then
				table.insert(calls, {"seth", x+2, y, bcol, tcol, text})
			end
			return calls
		end
	};
	
}






do
	local logf = "Controls"
	
	local function parseProp(k, rv) -- Parse a raw property value, returns the property default if rv is nil
		local template = controls.props[k]
		if (template) then
			if (controls.propParsers[template[1]]) then
				local pv = controls.propParsers[template[1]](rv)
				if (not pv) then
					if (type(template[2]) == "function") then
						return template[2]()
					else
						return template[2]
					end
				end
				return pv
			else
				if (type(template[2]) == "function") then
					return template[2]()
				else
					return template[2]
				end
			end
		end
		return rv
	end
	
	local function recursiveInit(control, ids, starttime)
		if (os.clock() - starttime > 4.5) then event.sleep(0) starttime = os.clock() end
		local id = control:get("id")
		if (id) then
			if (ids[id]) then os.log(logf, "(WARNING) Duplicate id '"..id.."' found on line "..tostring(control.ln)..", only one control will be assigned to this id") end
			ids[id] = control
		end
		local schema = controls.types[control.name]
		if (schema) then
			control.isControl = true
			control.interactable = schema.interactable
			for i,p in pairs(schema.props) do
				local rawVal = control:get(i)
				control:set(i, parseProp(i, rawVal))
				if (not rawVal and p) then os.log(logf, "(WARNING) Control schema violation: "..control.name.." at line "..tostring(control.ln).." is missing required attribute '"..i.."', using default value of ") end
			end
			if (schema.isContainer) then
				control.isContainer = true
				local size = control:get("size")
				control.contentViewport = {1,1, size[1], size[2]} -- By default, the content viewport covers the entire control
			end
			if (schema.init) then schema.init(control) end
		end
		for i=1,#control.children do 
			recursiveInit(control.children[i], ids, starttime)
			if (os.clock() - starttime > 4.5) then event.sleep(0) starttime = os.clock() end
		end
		return starttime
	end
	
	local function initPageDOM(dom) -- Initalize a loaded Page DOM (resolve attributes to the correct types, validate controls)
		local nameTag = dom:getFirstChild("documentname")
		if (nameTag) then
			os.log(logf, "Initalizing DOM for document '"..tostring(nameTag.innerText or nameTag:get("name")).."'")
		else
			os.log(logf, "Initalizing DOM")
		end
		local domroot
		local gpuTier = gl.getGPUTier()
		local gresX, gresY = gl.getGPU().maxResolution()
		for i,p in pairs(dom:getChildren("page")) do -- Pick the page with the resolution closest to the gpu's without going over
			local tierRaw = p:get("tier")
			local tier = tonumber(tierRaw) or 0
			p:set("tier", tier)
			if (not domroot) then domroot = p end
			if (domroot:get("tier") > gpuTier and tier <= gpuTier) then domroot = p end
		end
		if (not domroot) then return nil, "root element 'page' missing" end
		domroot.contentViewport = {1,2,gresX-1,gresY-2} -- The viewport is within the header and footer
		domroot:set("pos", {1,1})
		domroot:set("contentoffset", {1,1})
		domroot.isContainer = true
		domroot.isControl = true
		local idtbl = {}
		recursiveInit(domroot, idtbl, os.clock())
		domroot.ids = idtbl
		os.log(logf, "DOM Initialized")
		return domroot
	end
	controls.initPageDOM = initPageDOM
	
	local defaultPos = {1,1}
	local defaultOffset = {0,0}
	local defaultViewport = {1, 1, math.huge, math.huge}
	
	local function getCalls(control, parentPos) -- Recursively get draw calls for the control, starting at the provided position
		if (not control.isControl) then return {} end
		parentPos = parentPos or defaultPos
		local schema = controls.types[control.name]
		local pos = control:get("pos") or defaultPos
		local x, y = pos[1] + parentPos[1] - 1, pos[2] + parentPos[2] - 1
		local offset = control:get("contentoffset") or defaultOffset
		local calls = schema and (schema.drawCalls(control, x, y)) or {}
		if (control.isContainer) then
			local vx, vy = x + control.contentViewport[1] - 1, y + control.contentViewport[2] - 1
			local vmx, vmy = vx + control.contentViewport[3] - 1, vy + control.contentViewport[4] - 1
			local nextPos = {x+offset[1]+control.contentViewport[1] - 1, y+offset[2]+control.contentViewport[2] - 1}
			for i=1,#control.children do
				local childCalls = getCalls(control.children[i], nextPos)
				for ci=1,#childCalls do -- Truncate the calls to fit inside the viewport, or discard the call if it's completely outside the viewport
					local truncatedCall = gl.truncateCall(childCalls[ci], vx, vy, vmx, vmy)
					if (truncatedCall) then table.insert(calls, truncatedCall) end
				end
			end
		end
		return calls
	end
	controls.getCalls = getCalls
	
	local function getControlRecurse(control, ex, ey, px, py, vx, vy, vmx, vmy)
		if (not control.isControl) then return nil end
		local pos = control:get("pos") or defaultPos
		local size = control:get("size") or defaultPos
		local cx, cy = pos[1] + px - 1, pos[2] + py - 1
		local cmx, cmy = cx + size[1] - 1, cy + size[2] - 1
		if (cx > vmx or cy > vmy or cx+size[1]-1 < vx or cy+size[2]-1 < vy) then return nil end -- If the control is not within the parent viewport at all, it is not visible at the top level
		cx, cy, cmx, cmy = math.max(vx, math.min(vmx, cx)), math.max(vy, math.min(vmy, cy)), math.max(vx, math.min(vmx, cmx)), math.max(vy, math.min(vmy, cmy)) -- Constrain the control dimensions to the parent viewport
		if (cx > cmx or cy > cmy or cmx - cx <= 0 or cmy - cy <= 0) then return nil end
		if (ex >= cx and ex <= cmx and ey >= cy and ey <= cmy) then -- If the search coordiates are within the control
			if (control.isContainer) then -- If the control is a container, check if the search coordiates are within the viewport
				local cvx, cvy = cx + control.contentViewport[1] - 1, cy + control.contentViewport[2] - 1
				local cvmx, cvmy = cvx + control.contentViewport[3] - 1, cvy + control.contentViewport[4] - 1
				cvx, cvy, cvmx, cvmy = math.max(cx, math.min(cmx, cvx)), math.max(cy, math.min(cmy, cvy)), math.max(cx, math.min(cmx, cvmx)), math.max(cy, math.min(cmy, cvmy)) -- Constrain the content viewport to the control dimensions
				if (cvx > cvmx or cvy > cvmy or cvmx - cvx <= 0 or cvmy - cvy <= 0) then return control end -- If the constrained viewport is invalid, return the control
				if (ex >= cvx and ex <= cvmx and ey >= cvy and ey <= cvmy and #control.children > 0) then -- If the search coordinates are within the content viewport
					local offset = control:get("contentoffset") or defaultOffset
					local nx, ny = px + pos[1] + control.contentViewport[1] + offset[1] - 2, py + pos[2] + control.contentViewport[2] + offset[2] - 2
					for i,c in pairs(control.children) do
						local cres = getControlRecurse(c, ex, ey, nx, ny, cvx, cvy, cvmx, cvmy)
						if (cres) then return cres end
					end
					return control
				else
					return control
				end
			else
				return control
			end
		end
		return nil
	end
	
	local function getControlAt(dom, ex, ey) -- Recursively find a control at the provided position
		local pos = dom:get("pos") or defaultPos
		local viewport = dom.contentViewport or defaultViewport
		local offset = dom:get("contentoffset")
		local x, y = pos[1], pos[2]
		local vx, vy = x + viewport[1] - 1, y + viewport[2] - 1
		local vmx, vmy = vx + viewport[3] - 1, vy + viewport[4] - 1
		local nx, ny = vx + offset[1], vy + offset[2]
		for i,c in pairs(dom.children) do
			local cres = getControlRecurse(c, ex, ey, nx, ny, vx, vy, vmx, vmy)
			if (cres) then return cres end
		end
		return nil
	end
	controls.getControlAt = getControlAt
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end


