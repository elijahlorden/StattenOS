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
        
        proxy.getLabel = function()
            if (address == bootAddress) then return "main" end
            return proxy.getLabel()
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
    
    -- =================== [Path functions] =================== --
    
    local function concatPath(...) -- Concatenate multiple path parts
        local tArgs = {...}
        local concat = {}
        local prevTrailingSlash = true
        for i=1,#tArgs do
            local p = tArgs[i]
            if (type(p) == "string" and #p > 0) then
                local leadingSlash = p:sub(1,1) == "/"
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
        return disk, relPath or ""
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
    
    local function parentDirectory(path)
        if (path == nil or path == "") then return "" end
        if (path:sub(#path, #path) == "/") then path = path:sub(1, #path-1) end
        local idx = path:match("^.*()/")
        if (idx == nil) then return "" end
        return path:sub(1, idx-1)
    end
    
    -- =================== [Filesystem functions] =================== --
    
    local function resolvePathArgs(arg1, arg2, ...)
        if (type(arg2) == "string") then
            if (type(arg1) == "table") then
                if (not arg1.address) then return nil, "Invalid disk" end
                arg1 = disks[arg1.address]
            else
                arg1 = disks[arg1]
            end
            if (not arg1) then return nil, "Invalid disk" end
            return arg1, arg2, ...
        elseif (type(arg1) == "string") then
            local disk, relPath = toRelative(arg1)
            return disk, relPath, arg2, ...
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
    
    fs.size = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return 0 end
        if (#path == 0) then return disk.spaceUsed() end
        return disk.size(path)
    end
    
    fs.list = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return {} end
        return disk.list(path)
    end
    
    fs.lastModified = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return 0 end
        return disk.lastModified(path)
    end
    
    fs.remove = function(...)
        local disk, path = resolvePathArgs(...)
        if (not disk) then return false, path end
        return disk.remove(path)
    end
    
    fs.open = function(...)
        local disk, path, mode = resolvePathArgs(...)
        if (not disk) then return nil, path end
        return disk.open(path, mode)
    end
    
    fs.close = function(arg1, handle)
        local disk = (type(arg1) == "table" and arg1.address) and disks[arg1.address] or (type(arg1) == "string") and disks[arg1] or nil
        if (not disk) then return false end
        return disk.close(handle)
    end
    
    -- =================== [File class] =================== --
    
    local File = Class(function(File)
        
        function File.disk:set(v)
            self:close()
            local disk = (type(v) == "table" and v.address) and disks[v.address] or (type(v) == "string") and disks[v] or nil
            self._disk = disk.address
            self._rel = ""
        end
        
        function File.disk:get() return self._disk and disks[self._disk] or nil end
        
        function File.path:set(path)
            self:close()
            local disk, path = toRelative(path)
            if (disk) then
                self._disk = disk.address
                self._rel = path
            else
                self._disk = nil
                self._rel = nil
            end
        end
        
        function File.path:get() return (self._disk and self._rel and fs.disks[self._disk]) and fs.concat(fs.disks[self._disk].getLabel()..":/", self._rel) or nil end
        
        function File:init(...)
            self:setPath(...)
        end
        
        function File:setPath(...)
            local disk, path = resolvePathArgs(...)
            if (not disk) then return false end
            self:close()
            self._disk = disk.address
            self._rel = path
            return true
        end
        
        function File:exists() return fs.exists(self._disk, self._rel) end
        function File:isDirectory() return fs.isDirectory(self._disk, self._rel) end
        function File:size() return fs.size(self._disk, self._rel) end
        function File:list() return fs.list(self._disk, self._rel) end
        function File:lastModified() return fs.lastModified(self._disk, self._rel) end
        function File:remove() return fs.remove(self._disk, self._rel) end
        function File:getDirectory() return parentDirectory(self._rel) end
        
        function File:open(mode)
            if (not self._disk and self._rel) then return false, "Invalid file" end
            self:close()
            local handle = fs.open(self._disk, self._rel, mode)
            if (not handle) then return false, "Failed to open file" end
            self._h = handle
            return true
        end
        
        function File:close()
            if (self._disk and self._h) then fs.close(self._disk, self._h) end
            self._h = nil
        end
        
        function File:read(n)
            if (not self._h) then return nil end
            local disk = disks[self._disk]
            if (not disk) then return nil end
            return disk.read(self._h, n)
        end
        
        function File:write(s)
            if (not self._h) then return false end
            local disk = disks[self._disk]
            if (not disk) then return false end
            return disk.write(self._h, s)
        end
        
        function File:seek(whence, offset)
            if (not self._h) then return false end
            local disk = disks[self._disk]
            if (not disk) then return false end
            return disk.seek(self._h, whence, offset)
        end
        
        function File:makeParentDirectory()
            if (self:exists() or self._disk and self._rel == "") then return true end
            local parent = parentDirectory(self._rel)
            if (parent == "") then return true end
            return disks[self._disk].makeDirectory(parent)
        end
        
        function File:rename(newName)
            if not (self:exists()) then return false, "File not found" end
            local oldPath = self._rel
            local disk = disks[self._disk]
            local newPath = concatPath(self:getDirectory(), newName)
            if (newPath == oldPath) then return true end
            if not (disk.rename(oldPath, newPath)) then return false, "Rename failed" end
            self._rel = newPath
            return true
        end
        
        function File:copy(...)
            if (not self:exists()) then return false, "Source file not found" end
            if (self:isDirectory()) then return false, "Source file is a directory" end
            local toDisk, toRel = resolvePathArgs(...)
            if (not toDisk) then return false, "Target disk not found" end
            local toFile = _G.File(toDisk, toRel)
            if (toFile:isDirectory()) then return false, "Target file is a directory" end
            if not (toFile:makeParentDirectory()) then return false, "Failed to create target directory" end
            if not (toFile:open("w")) then return false, "Failed to open target file" end
            if not (self:open("r")) then toFile:close() return false, "Failed to open source file" end
            local copySize = self.bytesPerTick or 5000
            while (true) do
                local data = self:read(copySize)
                if (not data) then break end
                if (not toFile:write(data)) then return false, "Failed to write target file" end
                if (Thread._current) then Thread.yield() end
            end
            self:close()
            toFile:close()
            return true, toFile
        end
        
        function File:move(...)
           local success, result = self:copy(...)
           if (not success) then return false, result end
           local success, reason = self:remove()
           if not (success) then return false, reason end
           self._disk = result._disk
           self._rel = result._rel
        end
        

        
    end)
    _G.File = File
    
end