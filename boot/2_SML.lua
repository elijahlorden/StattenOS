-- StattenOS Markup Language Parser --
sml = {
	systemEntities = {
		quot = "\"",
		apos = "'",
		amp = "&",
		gt = ">",
		lt = "<",
		
	}
}
do
	local tagTypeOpen = 0
	local tagTypeSelfTerminate = 1
	local tagTypeClose = 2
	
	local function getCurrentLine(s, ptr)
		local i = 1
		for _ in s:sub(1,ptr):gmatch("\n") do i = i + 1 end
		return i
	end
	
	local function firstChar(s) -- Find the first non-whitespace character
		local i,j,m = s:find("([^%s])")
		return m,j
	end
	
	local function removeComments(s)
		return s:gsub("<!%-%-.->", "")
	end
	
	local function replaceEntities(s, entities)
		
	end
	
	local function parseAttribs(s, doc)
		local tbl = {}
		for k,v in s:gmatch("%s-(%w+)%s-=%s-[\"']([^<>\"']+)[\"']") do
			if (tonumber(v)) then v = tonumber(v) end
			
		end
		return tbl
	end
	
	local function parseTag(s, doc)
		local nc = firstChar(s)
		if (not nc) then return nil, nil, nil end
		if (nc ~= "<") then return nil, nil, "Unexpected token '"..nc.."'" end
		local i, j, name, attribs, terminate = s:find("%s-<(%w+)%s-(.-)(/?)>") -- Try to match open or self-terminating tag
		if (not i) then
			i, j, name = s:find("%s-</%s-(%w+)%s->") -- Try to match close tag
			if (not i) then return nil, nil, "malformed tag" end
			return {name = name}, tagTypeClose, nil
		end
		local attribTbl = parseAttribs(attribs, doc)
		if (not attribTbl) then return nil, nil, "malformed tag attributes" end
		local tagType
		if (terminate:len() > 0 and terminate ~= " ") then tagType = tagTypeSelfTerminate else tagType = tagTypeOpen end
		return {
			name = name,
			attribs = attribTbl,
			children = {}
		}, tagType, nil
	end
	
	local function tryGetInnerText(s, tagname)
		local i, j, t = s:find("([^<>\"']+)</"..tagname..">")
		if (t and (t:gsub("%s", ""):len() > 0)) then return t else return nil end
	end
	
	local function parse(s)
		local doc = {name = "document", children = {}, attribs = {}, entities = {}}
		setmetatable(doc.entities, {__index = sml.systemEntities})
		doc.parent = doc
		local currentTag = doc
		local ptr = 1
		local tag, tagType, reason
		s = removeComments(s)
		while (true) do
			local i,j = s:find(">", ptr)
			local segment
			if (i) then segment = s:sub(ptr, i+1); ptr = j + 1; else segment = s:sub(ptr, s:len()); ptr = s:len(); end
			tag, tagType, reason = parseTag(segment)
			if (not tag and reason) then 
				return nil, reason.." (Line "..getCurrentLine(s,ptr)..")" -- Failed to parse next tag
			elseif (not tag and currentTag ~= doc) then -- Tag was not closed
				return nil, "Missing </"..currentTag.name.."> (Line "..getCurrentLine(s,ptr)..")"
			elseif (not tag and currentTag == doc) then -- End of document
				break
			elseif (tag and tagType == tagTypeOpen) then -- New open tag
				local i,j = s:find(">", ptr)
				local segment, nptr
				if (i) then segment = s:sub(ptr, i+1); nptr = j + 1; else segment = s:sub(ptr, s:len()); nptr = s:len(); end
				local innertxt = tryGetInnerText(segment, tag.name)
				tag.parent = currentTag
				table.insert(currentTag.children, tag)
				if (innertxt) then
					tag.innertext = innertxt
					ptr = nptr
				else
					currentTag = tag
				end
			elseif (tag and tagType == tagTypeSelfTerminate) then -- New self-terminating tag
				tag.parent = currentTag
				table.insert(currentTag.children, tag)
			elseif (tag and tagType == tagTypeClose) then -- Close parent tag
				if (currentTag == doc) then
					return nil, "Floating closing tag (Line "..getCurrentLine(s,ptr)..")"
				elseif (tag.name ~= currentTag.name) then
					return nil, "Expected </"..currentTag.name.."> got </"..tag.name.."> (Line "..getCurrentLine(s,ptr)..")"
				else
					currentTag = currentTag.parent
				end
			else
				return nil, "Unknown error (Line "..getCurrentLine(s,ptr)..")"
			end
		end
		return doc, "Document loaded"
	end
	sml.parse = parse
	
	local doc, reason = parse("<docx><s> </s><s/><s></s><s>some text</s></docx><docf/>")
	local gpu = gl.getGPU()
	gpu.set(1,1,reason)
	if (doc) then
		local col = 1
		for i,p in pairs(doc.children[1].children) do
			gpu.set(col,2,(p.innertext or "notext")..", ")
			col = col + (p.innertext or "notext"):len() + 2
		end
	end
	
	
	
	
	
	
	
	
end