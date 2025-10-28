fs = {}
do
    local invoke = component.invoke
    
    -- =================== [Disk management] =================== --
    -- Attached filesystem components should always be re-labeled using fs.disks["label|address"].setLabel() to maintain disk mappings
    
    local bootAddress = computer.getBootAddress()
    
    local disks = {}
    fs.disks = {
        __call = function() -- Allows iterating disks like: for disk in fs.disks() do ... end
            return coroutine.wrap(function()
                for i,p in pairs(disks) do
                    if (type(p) == "table" and p.address == i) then coroutine.yield(p) end
                end
            end)
        end
    }
    fs.disks.__index = disks
    setmetatable(fs.disks, fs.disks)
    
    local function addDisk(address)
        local label = (address == bootAddress) and "main" or invoke(address, "getLabel") or address
        local proxy = component.proxy(address)
        
        proxy.setLabel = function(newLabel)
            checkArg(1, newLabel, "string")
            invoke(address, "setLabel", newLabel)
            if (address ~= bootAddress) then
                os.log("Updated disk label '"..label.."' to '"..newLabel.."' ("..address..")")
                disks[label] = nil
                disks[newLabel] = proxy
                label = newLabel
            end
        end
        
        disks[address] = proxy
        disks[label] = proxy
        computer.pushSignal("disk_added", address, label)
        os.log("Mounted disk '"..label.."' ("..address..")")
    end
    
    component.setPrimary("filesystem", bootAddress)
    for address,_ in component.list("filesystem", true) do
        addDisk(address, (address == bootAddress) and component.filesystem or nil)
    end
    
    event.listen("component_added", function(_, address, componentType)
        if (componentType ~= "filesystem") then return end
        if (address == bootAddress and component.filesystem and component.filesystem.address ~= address) then component.setPrimary("filesystem", componentType) end
        addDisk(addDisk)
    end)
    
    event.listen("component_removed", function(_, address, componentType)
        if (componentType ~= "filesystem") then return end
        local existing = disks[address]
        if (existing) then
            local label = existing.getLabel()
            disks[address] = nil
            disks[label] = nil
            computer.pushSignal("disk_removed", address, label)
            os.log("Removed disk '"..label.."' ("..address..")")
        end
    end)
    
    local function concatPath(...) -- Concatenate multiple path parts
        local tArgs = {...}
        local concat = {}
        local prevTrailingSlash = true
        for i=1,#tArgs do
            local p = tArgs[i]
            if (type(p) == "string" and #p > 0) then
                local leadingSlash = (p:sub(1,1) == "/")
                if (not prevTrailingSlash and not leadingSlash) then
                    table.insert(concat, "/")
                elseif (prevTrailingSlash and leadingSlash) then
                    p = p:sub(2)
                end
                table.insert(concat, p)
                prevTrailingSlash = (p:sub(#p, #p) == "/")
            end
        end
        return table.concat(concat)
    end
    fs.concat = concatPath
    
    local function toRelative(path) -- Return the disk proxy and disk-relative path of an absolute path
        checkArg(1, path, "string")
        local labelIdx = path:find(":")
        if (not labelIdx or labelIdx == 1) then return nil, "Path must be absolute" end
        local label = path:sub(1, labelIdx - 1)
        local relPath = path:sub(labelIdx + 2)
        local disk = disks[label]
        if (not disk) then return nil, "Disk '"..label.."' not found" end
        return disk, relPath
    end
    fs.toRelative = toRelative
    
    local function toAbsolute(disk, relPath) -- Return the absolute path for a disk proxy/address/label + disk-relative path
        checkArg(1, disk, "string", "table")
        checkArg(2, relPath, "string")
        if (type(disk) == "table") then
            if (not disk.address) then return nil, "Invalid disk" end
            disk = disks[disk.address]
        else
            disk = disks[disk]
        end
        if (not disk) then return nil, "Disk not found" end
        local address = disk.address
        local label = ((address == bootAddress) and "main" or disk.getLabel()) or address
        return concatPath({ label, ":/", relPath })
    end
    fs.toAbsolute = toAbsolute
    
    local function resolvePathArgs(arg0, arg1, arg2)
        if (arg0 == fs) then return arg1, arg2 else arg2 = arg1; arg1 = arg0 end -- Skip check for internal use
        if (type(arg2) == "string") then
            if (type(arg1) == "table") then
                if (not arg1.address) then return nil, "Invalid disk" end
                arg1 = disks[arg1.address]
            else
                arg1 = disks[arg1]
            end
            if (not arg1) then return nil, "Invalid disk" end
            return arg1, arg2
        elseif (type(arg1) == "string") then
            return toRelative(arg1)
        end
        return nil, "Invalid arguments"
    end
    
    fs.exists = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return false end
        if (#path == 0) then return true end
        return disk.exists(path)
    end
    
    fs.isDirectory = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return false end
        if (#path == 0) then return true end
        return disk.isDirectory(path)
    end
    
end