do
    local primaries = {}
    setmetatable(component, { __index = primaries })
    
    component.get = function(partial, ctype)
        checkArg(1, partial, "string")
        checkArg(2, ctype, "string", "nil")
        for c in component.list(ctype, true) do if (s:sub(1, partial:len()) == partial) then return s end end
        return nil, "component not found"
    end
    
    -- =================== [Primary Component Stuff] =================== -
    
    event.listen("component_added", function(_, address, componentType)
        if (not primaries[componentType]) then primaries[componentType] = component.proxy(address) end
    end)
    
    event.listen("component_removed", function(_, address, componentType)
        if (primaries[componentType] and primaries[componentType].address == address) then
            primaries[componentType] = nil
            component.setPrimary(componentType, component.list(componentType, true))
        end
    end)
    
    component.setPrimary = function(componentType, address)
        
    end
    
    
end





