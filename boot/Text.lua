-- Text Library --
text = {}
do
	local lowerchars = "0123456789abcdefghijklmnopqrstuvwxyz"
	text.lowerchars = lowerchars
	
    local function split(s, d)
		local r = {}
		for m in (s..d):gmatch("(.-)"..d) do
			table.insert(r, m)
		end
		return r
	end
	text.split = split
	
	local function detabpad(s)
		return s..string.rep(" ", s:len()%8)
	end

	text.detab = function(s)
		checkArg(1, s, "string")
		checkArg(2, w, "number", "nil")
		if (not s:find("\t")) then return s end
		return string.gsub(s, "([^\n]-)\t", detabpad)
	end
    
    local function trim(s)
        return s:match("^%s*(.-)%s*$")
    end
    text.trim = trim
    
    local function trimStart(s)
        s = s:gsub("^%s+", "")
        return s
    end
    text.trimStart = trimStart
    
    local function wrappedLines(str, width, skipNewlineCheck)
        if (not skipNewlineCheck and str:find("\n")) then
            local l = split(str, "\n")
            local r = {}
            for i=1,#l do
                local rl = {wrappedLines(l[i], width, true)}
                for o = 1,#rl do table.insert(r, rl[o]) end
                table.insert(r, "\n")
            end
            return table.unpack(r)
        end
        str = trim(str)
        if (#str <= width) then return str end
        local idx = str:find(" ", -1, true)
        if (not idx) then idx = width end
        local before = str:sub(1, idx)
        local after = str:sub(idx + 1)
        return before, "\n", wrappedLines(after, width)
    end
    text.wrappedLines = wrappedLines
    
    text.wrap = function(str, width)
        return table.concat({wrappedLines(str, width)})
    end
	
	text.padLeft = function(s,n,c)
		return string.rep(c,n-s:len())..s
	end
	
	text.padRight = function(s,n,c)
		return s..string.rep(c,n-s:len())
	end
	
	local uuidformat = "########-####-####-####-############"
	local function uuidchar()
		local i = math.random(1, #lowerchars)
		return lowerchars:sub(i,i)
	end
	text.uuid = function()
		return string.gsub(uuidformat, "#", uuidchar)
	end
	
	-- Split text into runs. Commands are placed inside braces, (ex. {command:value command2:value2}) braces may be escaped by doubling them.  Two braces enclosing an integer (ex. {1}) will be replaced by the corresponding argument (ex. '{{') Example string: "{b:0xCCCCCC f:0x0000FF} blue on grey {b:0x000000 f:0xFFFFFF} white on black {0}"
	text.formattedRuns = function(str, ...) 
		local vars = {...}
		--str = text.detab(str)
		local runs = {}
		local currBackground = -1
		local currForeground = -1
		local currentRun = {text = ""}
		str = str:gsub("{{", "&ob;"):gsub("}}", "&cb;") -- Sub out escaped braces
		for txt, commands in str:gmatch("([^{}]-){([^{}]+)}") do
			txt = txt:gsub("&ob;", "{"):gsub("&cb;", "}") -- Replace subbed braces
			local bracevar = commands:match("^%d+$")
			if (bracevar) then -- Replace the placeholder and continue
				txt = txt..tostring(vars[tonumber(bracevar)] or "")
				currentRun.text = currentRun.text..txt
			else -- add the text to the current run and start a new run
				currentRun.text = currentRun.text..txt
				table.insert(runs, currentRun)
				currentRun = {text = ""}
				for command,value in commands:gmatch("([^:%s]+):([^:%s]+)") do
					currentRun[command] = value
				end
			end
		end
		local endOfStr = str:match("}?([^{}]+)$")
		if (endOfStr) then currentRun.text = currentRun.text..(endOfStr:gsub("&ob;", "{"):gsub("&cb;", "}")) end
		table.insert(runs, currentRun)
		return runs
	end
	
	
	
	

end
