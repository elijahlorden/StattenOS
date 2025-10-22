Class = {}

do
	local function ins_isA(s, o) return Class.isA(s, o) end
    
    local function buildClass(_, callback, baseClass)
        local methods = { isA = ins_isA }
        local getters = {}
        local setters = {}
        local init = nil
        local len = nil
        local baseProxy = nil
        
        if (baseClass) then
            baseProxy = { getters = baseClass.getters, setters = baseClass.setters }
            for i,p in pairs(baseClass.methods) do methods[i] = p baseProxy[i] = p end
            for i,p in pairs(baseClass.getters) do getters[i] = p end
            for i,p in pairs(baseClass.setters) do setters[i] = p end
            if (baseClass.len) then
                baseProxy.len = baseClass.len
                len = baseClass.len
            end
            if (baseClass.init) then
                setmetatable(baseProxy, { __call = function(_, ...) baseClass.init(...) end })
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
            __newindex = function(_, methodName, v)
                if (methodName == "init") then
                    init = v
                elseif (methodName == "len") then
                    len = v
                else
                    methods[methodName] = v
                end
            end
        }), baseProxy);
        
        local proxymt = {
            __index = function(t, k)
                if (getters[k]) then return getters[k](t) end
                return methods[k] or t._ins[k]
            end,
            __newindex = function(t, k, v)
                if (setters[k]) then return setters[k](t, v) end
                if (getters[k]) then error("Attempted to set read-only property "..k, 2) end
                t._ins[k] = v
            end,
            __len = function(t) return len and len(t._ins) or #t._ins end
        }
        
        local classObj = { _src = Class, methods = methods, getters = getters, setters = setters, init = init, len = len, base = baseClass, inheritMap = {}, extend = function(s, cb) return buildClass(Class, cb, s) end, isA = ins_isA }
        if (baseClass) then
            classObj.inheritMap[baseClass] = true
            for i=1,#baseClass.inheritMap do classObj.inheritMap[baseClass.inheritMap[i]] = true end
        end
        
        return setmetatable(classObj, {
            __call = function(_, ...)
                local ins = {}
                local obj = setmetatable({ _src = Class, _ins = ins, _cls = classObj }, proxymt)
                if (init) then init(obj, ...) end
                return obj
            end
        });
    end
    
    Class.isA = function(obj, obj2)
        if (type(obj) ~= "table" or type(obj2) ~= "table") then return false end
        if (obj._src ~= Class or obj2._src ~= Class) then return false end
        local objClass = obj._cls or obj
        if (obj2 == objClass) then return true end
        local obj2Class = obj2._cls or obj2
        return objClass.inheritMap[obj2Class] or false
    end
	
	setmetatable(Class, {
        __call = buildClass
    })
	
end