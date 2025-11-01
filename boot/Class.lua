Class = {}

do
	local function ins_isA(s, o) return Class.isA(s, o) end
    function Class.tableAddress(tbl)
        local s = tostring(tbl)
        return s:sub(s:find(' ') + 1)
    end
    
    local function buildClass(_, callback, baseClass)
        local members = { isA = ins_isA }
        local getters = {}
        local setters = {}
        local init = nil
        local len = nil
        local tostring_mt = nil
        local baseProxy = nil
        
        if (baseClass) then
            baseProxy = { getters = baseClass.getters, setters = baseClass.setters }
            for i,p in pairs(baseClass.members) do members[i] = p baseProxy[i] = p end
            for i,p in pairs(baseClass.getters) do getters[i] = p end
            for i,p in pairs(baseClass.setters) do setters[i] = p end
            if (baseClass.proxy.len) then
                baseProxy.len = baseClass.proxy.len
                len = baseClass.len
            end
            if (baseClass.proxy.tostring_mt) then
                baseProxy.tostring = baseClass.proxy.tostring_mt
                tostring_mt = baseClass.tostring_mt
            end
            if (baseClass.init) then
                setmetatable(baseProxy, { __call = function(_, ...) baseClass.init(...) end, __index = baseClass.members })
            end
        end
        
        callback(setmetatable({}, {
            __index = function(_, propName)
                return setmetatable({}, {
                    __index = function() return nil end,
                    __newindex = function(_, funcName, v)
                        if (funcName == "get") then
                            getters[propName] = v
                        elseif (funcName == "set") then
                            setters[propName] = v
                        else
                            error("Invalid property method "..funcName, 2)
                        end
                    end
                })
            end,
            __newindex = function(_, memberName, v)
                if (memberName == "init") then
                    init = v
                elseif (memberName == "len") then
                    len = v
                elseif (memberName == "gc") then
                    gc = v
                elseif (memberName == "tostring") then
                    tostring_mt = v
                else
                    members[memberName] = v
                end
            end
        }), baseProxy);
        
        local proxymt = {
            __index = function(t, k)
                if (getters[k]) then return getters[k](t) end
                if (members[k] ~= nil) then return members[k] end
                return t._ins[k]
            end,
            __newindex = function(t, k, v)
                if (setters[k]) then return setters[k](t, v) end
                if (getters[k] or members[k]) then error("Attempted to set read-only member "..k, 2) end
                t._ins[k] = v
            end,
            len = len,
            tostring_mt = tostring_mt,
            __len = function(t) return len and len(t._ins) or #t._ins end,
        }
        
        if (tostring_mt) then proxymt.__tostring = function(t) return tostring_mt(t._ins) end end
        
        local classObj = { members = members, getters = getters, setters = setters, init = init, proxy = proxymt, base = baseClass, extend = function(s, cb) return buildClass(Class, cb, s) end, isA = ins_isA }
        classObj._cls = classObj
        
        return setmetatable(classObj, {
            __call = function(_, ...)
                local ins = {}
                local obj = setmetatable({ _ins = ins, _cls = classObj }, proxymt)
                if (init) then init(obj, ...) end
                return obj
            end
        });
    end
    
    Class.isA = function(obj, obj2)
        if (type(obj) ~= "table" or type(obj2) ~= "table") then return false end
        local objClass = obj._cls
        if (obj2 == objClass) then return true end
        local obj2Class = obj2._cls
        if (not objClass or not obj2Class) then return false end
        while (objClass) do
            if (objClass == obj2Class) then return true end
            objClass = objClass.base
        end
        return false
    end
	
	setmetatable(Class, {
        __call = buildClass
    })
	
end