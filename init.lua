function bootcode()
	-- Low level dofile implementation to read the rest of the OS.
	local bootfs = {}
	function bootfs.invoke(method, ...)
		return component.invoke(computer.getBootAddress(), method, ...)
	end
	function bootfs.open(file) return bootfs.invoke("open", file) end
	function bootfs.read(handle) return bootfs.invoke("read", handle, math.huge) end
	function bootfs.close(handle) return bootfs.invoke("close", handle) end
	function bootfs.inits(file) return ipairs(bootfs.invoke("list", "boot")) end
	function bootfs.isDirectory(path) return bootfs.invoke("isDirectory", path) end
	-- low-level dofile implementation
	local function loadfile(file, mode, env)
		local handle, reason = bootfs.open(file)
		if not handle then
			error(reason)
		end
		local buffer = ""
		repeat
			local data, reason = bootfs.read(handle)
			if not data and reason then
				error(reason)
			end
			buffer = buffer .. (data or "")
		until not data
		bootfs.close(handle)
		if mode == nil then mode = "bt" end
		if env == nil then env = _G end
		return load(buffer, "=" .. file)
	end
	_G.loadfile = loadfile
end

bootcode()

function dofile(file)
	local program, reason = loadfile(file)
	if program then
		local result = table.pack(pcall(program))
		if result[1] then
			return table.unpack(result, 2, result.n)
		else
			error(result[2], 3)
		end
	else
		error(reason, 3)
	end
end

dofile("/CoreLibs.lua")
dofile("/OS.lua")

bootcode = nil
loadfile = nil
dofile = nil



