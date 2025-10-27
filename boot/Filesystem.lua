fs = {}
do
    local invoke = component.invoke
    
    local bootAddress = computer.getBootAddress()
    
    local disks = {}
    fs.disks = {}
    fs.disks.__index = disks
    setmetatable(fs.disks, fs.disks)
    
    local function addDisk(address)
        local label = (address == bootAddress) and "main" or invoke(address, "getLabel")
        proxy = proxy or component.proxy(address)
        
        proxy.setLabel = function(newLabel)
            checkArg(1, newLabel, "string")
            invoke(address, "setLabel", newLabel)
            os.log("Updated disk label '"..label.."' to '"..newLabel.."' ("..address..")")
            disks[label] = nil
            disks[newLabel] = proxy
            disks[address] == proxy
            label = newLabel
        end
        
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
    
    
    
    
    
    
    
end