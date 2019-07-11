Class = {}
Classes = {}

do
	local classes = {}
	
	local emptynewindex = function(t, i, v) end
	
	setmetatable(Classes, {
		__metatable = "This metatable is locked";
		__newindex = emptynewindex;
		__index = function(t, i) return classes[i] end
	})
	
	local newclasstblmeta = {
		__call = function(t, body)
			if (not t) then error(2, "Missing class header") end
			if (not body or type(body) ~= "table") then error(2, "Missing class body") end
			if (not t.name) then error(2, "Missing class attributes") end
			if (classes[t.name]) then error(2, "Cannot override existing definition for class '"..name.."' (Nice try!)") end
			classes[t.name] = {} -- Proxy
			local initf = (body.init and type(body.init) == "function") and body.init
			body.init = nil
			
			local classmeta = {
				__index = body;
			}
			
			setmetatable(classes[t.name], {
				__call = function(...)
					local instance = {}
					setmetatable(instance, classmeta)
					if (initf) then initf(instance, ...) end
					return instance
				end;
				__newindex = emptynewindex;
				__index = {
					isInstance = function(ins)
						return (getmetatable(ins) == classmeta)
					end;
				};
			})
			
			
		end;
	}
	
	Class.new = function(name) 
		if (classes[name]) then error(2, "Cannot override existing definition for class '"..name.."'") end
		local rt = {name = name}
		setmetatable(rt, newclasstblmeta)
		return rt
	end
	
	
	
	
	
end