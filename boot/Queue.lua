Queue = {}
do
    function Queue:insert(item)
        local idx = self._endIdx + 1
        self._endIdx = idx
        self[idx] = item
    end

    function Queue:remove()
        local startIdx = self._startIdx
        if (startIdx > self._endIdx) then return nil end
        local val = self[startIdx]
        self[startIdx] = nil
        self._startIdx = startIdx + 1
        return val
    end

    function Queue:peek(idx)
        idx = (idx - 1) + self._startIdx
        if (idx > self._endIdx) then return nil end
        return self[idx]
    end

    function Queue:len()
        return (self._endIdx - self._startIdx) + 1
    end

    local _meta = {
        __index = Queue,
        __len = Queue.len
    }

    function Queue.new()
        return setmetatable({ _startIdx = 0, _endIdx = -1 }, _meta)
    end
end