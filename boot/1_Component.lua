local primaries = {}

component.get = function(partial, ctype)
	checkArg(1, partial, "string")
	checkArg(2, ctype, "string", "nil")
	for c in component.list(ctype, true) do if (s:sub(1, partial:len()) == partial) then return s end end
	return nil, "component not found"
end







