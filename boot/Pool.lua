Pool = Class(function(Pool)
    
    function Pool:add(v)
        if (self._map[v]) then return false end
        table.insert(self, v)
        self._map[v] = #self
        return true
    end
    
    function Pool:remove(v)
        local i = self._map[v]
        if (i == nil) then return false end
        return self:removeAt(i)
    end
    
    function Pool:removeAt(i)
        local len = #self
        if (i > len or i < 1) then error("Index out of bounds", 3) end
        self._map[self[i]] = nil
        self[i] = self[len]
        table.remove(self)
        return true
    end
    
    function Pool:indexOf(v)
        return self._map[v]
    end
    
    function Pool:contains(v)
        return self._map[v} ~= nil
    end
    
    function Pool:init()
        os.log("init")
        self._map = {}
    end
    
end)