--[[ EVENTS TEST

local callback 
callback = function(e, a, c, code, plr)
	gpu.set(1,11,e..", "..c..", "..code..", "..plr)
	event.ignore("key_up", callback)
end

local reg = event.listen("key", callback)

event.listen("component", function(e)
	gpu.set(1,12,e)
end)

if (reg) then gpu.set(1,9, "registered event") end

while (true) do
	local e, a, c, code, plr = event.pull("key_up", 0.1)
	if (e) then
		gpu.set(1,10,e..", "..c..", "..code..", "..plr)
	end
	gpu.set(1,20,tostring((computer.totalMemory() - computer.freeMemory())/1024))
end
--]]


os.log("Start!")

function formatMemory(n)
    return string.format("%.1fkB", n/1024)
end

os.log(formatMemory(computer.totalMemory() - computer.freeMemory()).." / "..formatMemory(computer.totalMemory()))



--[[
local Class1 = Class(function(Class1)

    function Class1.prop:get()
        return self._prop
    end
    
    function Class1.prop:set(v)
       self._prop = v
    end
    
    function Class1:method(txt)
        return txt.." "..tostring(self.prop)
    end
    
    function Class1:init(p)
        os.log("class1 init")
        self.prop = p
    end
    
end)

local Class2 = Class1:extend(function(Class2, base)
    
    function Class2:method(txt)
        return txt.." override "..(base.method(self, txt))
    end
    
    function Class2.prop:set(v)
        base.setters.prop(self, "#"..v)
    end
    
    function Class2:init(...)
        base(self, ...)
        self.prop = "super"
    end
    
end)

local ins1 = Class1("abcdef")
os.log(ins1:isA(Class2))


local doc = Markup.Document()

local tag1 = Markup.Tag()
tag1.id = "tag1"
local tag2 = Markup.Tag()
tag2.id = "tag2"
local tag3 = Markup.Tag()
tag3.id = "tag3"

tag1.parent = doc
tag2.parent = tag1
os.log(doc:findById("tag2").ordered)
os.log(doc.ordered)
--]]

--[[

local tokenizer = Markup.tokenizer([==[abc "def" 123 -123 [ ] [] [456 789] [a b]c ["c" "d"]"e"[ ["f"] [g] "]==])
while (tokenizer.hasNext()) do 
    local success, tkn = tokenizer.next()
    if (success and tkn ~= nil) then os.log(tkn.type..": "..tostring(tkn.value)) end
    if (not success) then os.log("Err: "..tkn) end
end
os.log("eof")

local doc = Markup.Document.new()

local t1 = Markup.Tag.new():setId("tag2")
t1:append(Markup.Tag.new():setId("tag3"):append(Markup.Tag.new():setId("tag4")))
doc:append(t1)

os.log(doc:findById("tag4"))
t1:getParent():remove(t1)
os.log(doc:findById("tag4"))
t1:appendTo(doc)
os.log(doc:findById("tag3"):isDescendantOf(doc:findById("tag4")))

--]]

local start = computer.uptime()

event.listen("key_up", function(e, a, x, y, b, p)
    os.log("Key up event")
end)

--gpu.set(1,19,tostring(computer.uptime() - start))

--os.log(fs.exists("main:/boot/Class.lua"))

local f = File("main:/test.txt")
--f:open("w")
--for i=1,1000 do f:write("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") end
--f:close()
local success, reason = f:move("main:/test2.txt")
os.log(success)
os.log(reason)


--[[
Thread(function()
    local deltaTime, signal, addr, keyChar, keyCode, player = Thread.pull("key_down")
    os.log("Key down: "..keyChar)
    while true do
        deltaTime, signal, addr, keyChar, keyCode, player = Thread.pull("key_up")
        os.log("Key up: "..keyChar)
    end
end, "test"):resume()
--]]

Thread(function()
    while true do
        Thread.sleep(30)
        os.log(formatMemory(computer.totalMemory() - computer.freeMemory()).." / "..formatMemory(computer.totalMemory()))
    end
end):resume()

Thread._autoUpdate()