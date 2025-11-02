Markup = {}

do
    -- ======================= [ Markup parser ] ======================= --
    
    local function tokenizer(str)
        local line = 1
        local enum = StringEnumerator.new(str)
        local tknQueue = Queue.new()
        
        local nextTokenFunc = function(skipQueue) -- Returns success, token type or nil, token value or nil
            if (not skipQueue and #tknQueue > 0) then return table.unpack(tknQueue:remove()) end
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
            idx = idx or 1
            while (idx > #tknQueue) do
                local success, tknType, tkn = nextTokenFunc(true)
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
    
    local function parseArray(filename, tokens)
        
    end
    
    local function parseAttribute(filename, tokens) -- Match symbol: "value", symbol: 123, symbol: [1, 2, 3, ...]
        local success, tkn1, tkn2
        success, tkn1 = tokens.peek()
        if (not success) then error(tkn1) end
        success, tkn2 = tokens.peek(2)
        if (not success) then error(tkn2) end
        if (not tkn1 or not tkn2) then return nil end
        if (tkn1.type ~= "symbol") then return nil end
        os.log(tkn1.type)
        local key = tkn1.value
        if (key:sub(#key, #key) ~= ":") then return nil end
        tokens.next()
        key = key:sub(1,#key-1)
        if (tkn2.type == "string" or tkn2.type == "number") then tokens.next() return key, tkn2.value end
        local arr = parseArray(filename, tokens)
        if (arr) then return key, arr end
        error("Line "..tkn2.line..": Unexpected token '"..(tostring(tkn2.value)).."'")
    end
    
    local function parseTag(filename, tokens, tagTypes) -- Match [TagType attr1: val attr2: "val" attr3: [...] [TagType ...]]
        local success, tkn1, tkn2
        local stack = {}
        local parent = nil
        
        while (tokens.hasNext()) do
            success, tkn1 = tokens.peek()
            if (not success) then error(tkn1) end
            os.log("Next: "..tostring(tkn1.value))
            if (tkn1.type == "string" or tkn1.type == "number") then -- String literals
                tokens.next()
                if (not parent) then return tkn1.value end
                table.insert(parent, tkn1.value) -- Add string/number to parent
            elseif (tkn1.type == "close") then -- Close tag
                tokens.next()
                if (parent) then
                    if (#stack > 0) then -- CLosing a tested tag, pop the parent from the stack
                        local newParent = stack[#stack]
                        table.remove(stack)
                        parent.line = nil
                        table.insert(newParent, parent)
                        parent = newParent
                    else
                        return parent -- CLosing the top tag, return it
                    end
                else
                    error("Line "..tkn1.line..": Unexpected token '"..(tkn1.value).."'")
                end
            elseif (tkn1.type == "open") then -- Open tag
                os.log("Open tag")
                tokens.next()
                success, tkn2 = tokens.next()
                if (not success) then error(tkn2) end
                if (tkn2.type ~= "symbol") then error("Line "..tkn2.line..": Unexpected token '"..(tkn2.value).."'") end
                local tagType = tkn2.value
                local newTag
                if (tagTypes) then
                    local tagClass = tagTypes[tagType]
                    if (not tagClass) then error("Line "..tkn2.line..": Unknown tag type '"..(tkn2.value).."'") end
                    newTag = tagClass()
                else
                    newTag = { tag = tagType }
                end
                if (parent) then table.insert(stack, parent) end
                parent = newTag
                parent._line = tkn1.line
            else -- Try parsing an attribute
                if (not parent) then error("Line "..tkn1.line..": Unexpected token '"..(tkn1.value).."'") end
                local k, v = parseAttribute(filename, tokens)
                if (not k) then error("Line "..tkn1.line..": Unexpected token '"..(tkn1.value).."'") end
                os.log("Attribute: "..k)
                local class = parent._cls
                if (parent._cls) then
                    local setter = parent._cls.setters[k]
                    if (setter) then setter(parent, v) end
                else
                    parent[k] = v
                end
            end
        end
        
        if (#stack > 0) then
            local top = stack[#stack]
            error("Expected ']' to close tag on line "..top.line)
        end
        
        return parent
    end
    
    Markup.parse = function(str, filename, tagTypes)
        filename = filename or "Markup"
        local tokens = tokenizer(str)
        
        local tags = {}
        
        while (tokens.hasNext()) do
            table.insert(tags, parseTag(filename, tokens, tagTypes))
        end
        
        return tags
    end
    
    -- ======================= [ Markup serializer ] ======================= --
    
    local function writeIndented(s, callback, indent, pretty)
        if (pretty) then
            callback("\n")
            callback(string.rep("    ", indent))
        else
            callback(" ")
        end
        callback(s)
    end
    
    local function writeTag(tag, callback, indent, pretty)
        if (type(tag) == "string") then
            writeIndented('"', callback, indent, pretty)
            callback(tag)
            callback('"')
        elseif (type(tag) == "number") then
            writeIndented(tonumber(tag), callback, indent, pretty)
        else
            writeIndented("[", callback, indent, pretty)
            callback(tag.tag or "Tag")
            if (tag._cls) then
            
            else
                for i,p in pairs(tag) do -- Write attribute
                    if (type(i) == "string" and i ~= "tag" and i ~= "_line") then
                        writeIndented(i, callback, indent + 1, pretty)
                        callback(": ")
                        if (type(p) == "string") then
                            callback('"')
                            callback(p)
                            callback('"')
                        elseif (type(p) == "number") then
                            callback(tostring(p))
                        end
                    end
                end
            end
            for i=1,#tag do -- Write child tags
                writeTag(tag[i], callback, indent + 1, pretty)
            end
            writeIndented("]", callback, indent, pretty)
        end
    end
    
    
    
    
    Markup.serialize = function(root, pretty)
        checkArg(1, root, "table")
        checkArg(2, pretty, "nil", "boolean")
        local parts = {}
        local first = true
        
        local function callback(s)
            if (first) then
                table.insert(parts, text.trimStart(s))
                first = false
            else
                table.insert(parts, s)
            end
            if (#parts > 256) then parts = { table.concat(parts) } end
        end
        
        for i=1,#root do
            writeTag(root[i], callback, 0, pretty)
            if (pretty and i ~= #root) then callback("\n") end
        end
        
        return table.concat(parts)
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