Markup = {}

do
    
    local function tokenizer(str)
        local line = 1
        local enum = StringEnumerator.new(str)
        local tknQueue = Queue.new()
        
        local nextTokenFunc = function() -- Returns success, token type or nil, token value or nil
            if (#tknQueue > 0) then return table.unpack(tknQueue:remove()) end
            while (enum:hasNext() and enum:peek():find("%s")) do
                local c = enum:next()
                if (c == "\n") then line = line + 1 end
            end
            if (not enum:hasNext()) then return true, nil end

            local nextChar = enum:peek()
            local nextChar2 = enum:remaining() > 1 and enum:peek(2) or nil
            
            if (nextChar == "[") then -- Open bracket
                return true, { ["value"] = enum:next(), ["type"] = "open", ["line"] = line }
            elseif (nextChar == "]") then -- Close bracket
                return true, { ["value"] = enum:next(), ["type"] = "close", ["line"] = line }
            elseif (nextChar == "\"" or nextChar == "'") then -- Strings
                local startchar = enum:next()
                if (enum:remaining() == 0) then return false, "Line "..tostring(line)..": Unterminated string literal" end
                local startLine = line
                local tbl = {}
                while true do
                    if (enum:remaining() == 0) then return false, "Line "..tostring(startLine)..": Unterminated string literal" end
                    local c = enum:next()
                    if (c == "\n") then line = line + 1 end
                    if (c == "\\" and enum:remaining() > 0) then
                        local nc = enum:next()
                        if (nc == "n") then table.insert(tbl, "\n")
                        elseif (nc == "t") then table.insert(tbl, "\t")
                        else table.insert(tbl, nc) end
                    elseif (c == startchar) then
                        break
                    else
                        table.insert(tbl, c)
                    end
                end
                return true, { ["value"] = table.concat(tbl), ["type"] = "string", ["line"] = line }
            else -- Numbers and Symbols
                local tbl = {}
                while (enum:remaining() > 0 and not enum:peek():find("%s")) do
                    local c = enum:peek()
                    if (c == "[" or c == "]" or c == "\"" or c == "'") then break end
                    table.insert(tbl, enum:next())
                end
                local sym = table.concat(tbl)
                local num = tonumber(word)
                if (num ~= nil) then return true, { ["value"] = num, ["type"] = "number", ["line"] = line } end
                return true, { ["value"] = sym, ["type"] = "symbol", ["line"] = line }
            end
            return false, "Line "..tostring(line)..": Unknown error"
        end
        
        local peekTokenFunc = function(idx)
            while (idx > #tknQueue) do
                local success, tknType, tkn = nextTokenFunc()
                tknQueue:insert({success, tknType, tkn})
                if (not success) then break end
            end
            return table.unpack(tknQueue:peek(idx))
        end
        
        local hasNextFunc = function()
            if (#tknQueue > 0) then return true end
            local s, t, tt = peekTokenFunc(1)
            return (not s) or (t ~= nil)
        end
        
        return { next = nextTokenFunc, peek = peekTokenFunc, hasNext = hasNextFunc }
    end
    Markup.tokenizer = tokenizer
    
    local function parse(str, filename, tagTypes)
        filename = filename or "Markup"
        local tokens = tokenizer(str)
        
        local document = Document.new()
        
        while (tokens.hasNext()) do
            
        end
        
        return document
    end
    Markup.parse = parse
    
    local function parseTag(filename, tokenizer, tagTypes) -- Match [TagType attr1: val attr2: "val" attr3: [...] [TagType ...]]
        local stack = {}
        
        
        
        
        while true do
            if (#stack == 0) then break end
            
            
            
            
            
        end
        
        

        
        
        
        
        
        
        
        
    end
    
    local function parseOpenTag(filename, tokenizer, tagTypes)
        local success, tkn1, tkn2
        success, tkn1 = tokenizer:peek()
        if (not success) then error(tkn1) end
        success, tkn2 = tokenizer:peek(2)
        
        
        
        
        
        
        
    end
    
    local function parseAttribute(filename, tokenizer) -- Match symbol: "value", symbol: 123, symbol: [1, 2, 3, ...]
        local success, tkn1, tkn2
        success, tkn1 = tokenizer:peek()
        if (not success) then error(tkn1) end
        success, tkn2 = tokenizer:peek(2)
        if (not success) then error(tkn1) end
        if (not tkn1 or not tkn2) then return nil end
        if (tkn1.type ~= "symbol") then return nil end
        local key = tkn1.value
        if (key.sub(-1) ~= ":") then return nil end
        tokenizer:next()
        key = key:sub(1,#key-1)
        if (tkn2.type == "string" or tkn2.type == "number") then tokenizer:next() return key, tkn2.value end
        local arr = parseArray(filename, tokenizer)
        if (arr) then return key, arr end
        error("Line "..tkn2.line..": Unexpected token '"..(tkn2.value).."'")
    end
    
    local function parseArray(filename, tokenizer)
        
    end
    
    -- ======================= [ Tag base class ] ======================= --
    
    local Tag = Class(function(Tag)
        Tag.ordered = false
        
        function Tag.document:get() return self._document end
        
        function Tag.parent:get() return self._parent end
        
        function Tag.parent:set(newParent)
            if (newParent == self._parent) then return end
            local oldParent = self._parent
            self._parent = newParent
            if (oldParent ~= nil) then
                local childIdx = oldParent._childrenMap[child]
                if (not childIdx) then error("Invalid tag configuration, child not contained within parent", 2) end
                if (oldParent.ordered) then -- Slow remove, preserves tag order of old parent
                    table.remove(oldParent, childIdx)
                    oldParent:_reindex(childIdx)
                else -- Fast remove, does not preserve tag order
                    if (childIdx == #oldParent) then
                        table.remove(oldParent)
                    else -- Swap and pop this tag from the old parent
                        oldParent[childIdx] = oldParent[#self]
                        oldParent._childrenMap[oldParent[childIdx]] = childIdx
                        table.remove(oldParent)
                    end
                end
            end
            if (newParent ~= nil) then
                table.insert(newParent, self)
                newParent._childrenMap[self] = #newParent
            end
            local newDocument = newParent ~= nil and newParent.document or nil
            if (self._document ~= newDocument) then self:_setNewDocument(newDocument) end
        end
        
        function Tag:_reindex(startIdx)
            local map = self._childrenMap
            for i=startIdx,#self do
                map[self[i]] = i
            end
        end
        
        function Tag:_setNewDocument(newDocument)
            local oldDocument = self._document
            self._document = newDocument
            if (oldDocument ~= nil and self._id ~= nil) then oldDocument._idMap[self._id] = nil end
            if (newDocument ~= nil and self._id ~= nil) then newDocument._idMap[self._id] = self end
            for i=1,#self do
                self[i]:_setNewDocument(newDocument)
            end
        end
        
        function Tag:append(other) other.parent = self end
        function Tag:appendTo(other) self.parent = other end
        function Tag:remove(other)
            if (other.parent ~= self) then error("Attempted to remove a non-child tag", 3) end
            other.parent = nil
        end
        
        function Tag.id:get() return self._id end
        
        function Tag.id:set(newId)
            local document = self._document
            local oldId = self._id
            self._id = newId
            if (document ~= nil) then
                document._idMap[oldId] = nil
                document._idMap[newId] = self
            end
        end
        
        function Tag:setId(newId) self.id = newId end
        
        function Tag:isDescendantOf(other)
            if (other == self._parent or other == self._document) then return true end
            if (not self._parent or other._document ~= self._document) then return false end
            if (self._parent == self._document) then return false end
            return self._parent:isDescendantOf(other)
        end
        
        function Tag:init()
            self._childrenMap = {}
            self._dirty = false
        end
        
    end)
    Markup.Tag = Tag
    
    -- ======================= [ Document class ] ======================= --
    
    local Document = Tag:extend(function(Document, base)
        Document.ordered = true
        
        function Document.document:get() return self end
        
        function Document.parent:get() return nil end
        function Document.parent:set() error("Attempted to set the parent of a document object", 3) end
        
        function Document:appendTo() error("Attempted append a document object") end
        
        function Document:findById(id)
            return self._idMap[id]
        end
        
        function Document:init(...)
            base(self, ...)
            self._idMap = {}
        end
    end)
    Markup.Document = Document
    
end