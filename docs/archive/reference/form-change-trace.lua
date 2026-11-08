-- Controlled routine-entry fixtures, not an input-only collection/damage playthrough.
local output=assert(os.getenv("QUICKGAME_REFERENCE_OUTPUT"))
local f=assert(io.open(output.."/mesen-form-change.csv","w"))
f:write("frame,routine,timer,size,status,changing,pose,gfx,injury,x,y\n")
local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function()
 if frame==340 then w(0x756,1);w(0x0e,9);w(0x1d,0);w(0x747,255) end
 if frame==460 then w(0x756,0);w(0x79e,8);w(0x0e,10);w(0x1d,1);w(0x747,255) end
 emu.setInput({start=frame==120,a=false,b=false,left=false,right=false,up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=340 then f:write(string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",frame,r(0x0e),r(0x747),r(0x754),r(0x756),r(0x70b),r(0x70d),r(0x6d5),r(0x79e),r(0x86),r(0xce))) end
 if frame==760 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)
