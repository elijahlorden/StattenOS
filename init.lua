boot = {}

local saddr, gpuaddr = component.list("screen")(), component.list("gpu")()
if (saddr and gpuaddr) then
	boot.gpu = component.proxy(gpuaddr)
	boot.gpu.bind(saddr)
	boot.row = 1
	boot.col = 1
end
boot.fproxy = component.proxy(computer.getBootAddress())
function boot:open(p, m) return self.fproxy.open(p,m) end
function boot:close(h) return self.fproxy.close(h) end
function boot:read(h, n) return self.fproxy.read(h,n) end
function boot:write(h, s) return self.fproxy.write(h,s) end
function boot:list(p) return self.fproxy.list(p) end
function boot:isDirectory(p) return self.fproxy.isDirectory(p) end
function boot:makeDirectory(p) return self.fproxy.makeDirectory(p) end
function boot:exists(p) return self.fproxy.exists(p) end

function boot:load(p)
	local h,r = self:open(p)
	if (not h) then return nil,r end
	local d
	local s = ""
	repeat
		d = self:read(h,math.huge)
		s = s..(d or "")
	until not d
	return s
end

function boot:dofile(p)
	local s,r = self:load(p)
	if (not s) then return false, r end
	local p,r = load(s, "="..p)
	if (not p) then return false, r end
	r = table.pack(xpcall(p, function(s) return tostring(s).."\n"..debug.traceback() end))
	if (not r[1]) then return false, r[2] end
	return true, table.unpack(r, 2, r.n)
end



if (not boot:exists("boot") or not boot:isDirectory("boot")) then error("/boot directory missing") end

for i,p in pairs(boot:list("boot")) do
	if (i ~= "n" and p:find(".lua$")) then
		local s,r = boot:dofile("/boot/"..p)
		if (not s) then error("Error loading /boot/"..p..":\n"..r) end
	end
end

boot = nil -- This is no longer needed


