StringEnumerator = {}
do
    function StringEnumerator:len() return #self._str end
    function StringEnumerator:remaining() return (#self._str) - (self._idx - 1) end
    function StringEnumerator:hasNext() return self._idx <= #self._str end

    function StringEnumerator:next(len, inc)
        local idx = self._idx;
        if (idx > #self) then return nil end
        local len = len or 1
        local inc = type(inc) == "nil" and true or inc
        if (type(len) ~= "number") then error("Argument 1: Expected number, got "..type(len), 2) end
        if (len > self:remaining() or len <= 0) then error("Argument 1: out of range", 2) end 
        if (inc) then self._idx = idx + 1 end
        return self._str:sub(idx, idx + (len - 1))
    end

    function StringEnumerator:peek(len) return self:next(len, false) end

    function StringEnumerator:inc(len) self._idx = math.min(self._idx + (len or 1), #self + 1) end

    local _meta = {
        __index = StringEnumerator,
        __len = function(e) return e:len() end
    }

    StringEnumerator.new = function(str)
        if (type(str) ~= "string") then error("Argument 1: Expected string, got "..type(str)) end
        local e = setmetatable({ _str = str, _idx = 1 }, _meta)
        return e
    end
end