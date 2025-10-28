do
    local primaries = {}
    setmetatable(component, { __index = function(_, idx) return component.getPrimary(idx) end })
    
    component.get = function(partial, ctype)
        checkArg(1, partial, "string")
        checkArg(2, ctype, "string", "nil")
        for c in component.list(ctype, true) do if (s:sub(1, partial:len()) == partial) then return s end end
        return nil, "component not found"
    end
    
    -- =================== [Primary Component Stuff] =================== --
    
    event.listen("component_added", function(_, address, componentType)
        if (not primaries[componentType]) then primaries[componentType] = component.proxy(address) end
    end)
    
    event.listen("component_removed", function(_, address, componentType)
        if (primaries[componentType] and primaries[componentType].address == address) then
            primaries[componentType] = nil
            component.setPrimary(componentType, component.list(componentType, true)())
        end
    end)
    
    component.setPrimary = function(componentType, address)
        checkArg(1, componentType, "string")
        checkArg(2, address, "string", "nil")
        local current = primaries[componentType]
        if (current and current.address == address) then return current end
        local proxy, err = component.proxy(address)
        if (not proxy) then return nil, err end
        primaries[componentType] = proxy
        return proxy
    end
    
    component.getPrimary = function(componentType)
        checkArg(1, componentType, "string")
        if (not primaries[componentType]) then
            component.setPrimary(componentType, component.list(componentType, true)())
        end
        return primaries[componentType]
    end
    
    component.isPrimary = function(address)
        checkArg(1, address, "string")
        local componentType = component.type(address)
        return componentType ~= nil and primaries[componentType] ~= nil
    end
    
end





