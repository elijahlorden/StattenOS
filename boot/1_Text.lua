-- Text Library --
text = {}
do
	text.split = function(s, d)
		local r = {}
		for m in (s..d):gmatch("(.-)"..d) do
			table.insert(r, m)
		end
		return r
	end
	
	local function detabpad(s)
		return s..string.rep(" ", s:len()%8)
	end

	text.detab = function(s)
		checkArg(1, s, "string")
		checkArg(2, w, "number", "nil")
		if (not s:find("\t")) then return s end
		return string.gsub(s, "([^\n]-)\t", detabpad)
	end

end
