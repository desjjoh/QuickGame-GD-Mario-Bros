-- Controlled RAM placement of an airborne Small Mario and live mushroom.
-- Collection itself runs through the original collision routine; ROM is unchanged.
local output=assert(os.getenv('QUICKGAME_REFERENCE_OUTPUT'))
local f=assert(io.open(output..'/airborne-growth.csv','w'))
f:write('frame,routine,timer,state,size,changing,pose,gfx,x,y,vx,vy\n')
local n=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function()
 if n==340 then
  w(0x754,1);w(0x756,0);w(0x86,40);w(0xce,120);w(0x1d,1);w(0x57,16);w(0x9f,253)
  w(0x14,1);w(0x1b,0x2e);w(0x23,0x80);w(0x73,0);w(0x8c,40);w(0xbb,1);w(0xd4,140);w(0x49f,3);w(0x39,0);w(0x5d,0)
 end
 emu.setInput({start=n==120,a=n>=340,b=false,left=false,right=false,up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 if n>=340 then f:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',n,r(0x0e),r(0x747),r(0x1d),r(0x754),r(0x70b),r(0x70d),r(0x6d5),r(0x86),r(0xce),emu.read(0x57,emu.memType.nesDebug,true),emu.read(0x9f,emu.memType.nesDebug,true))) end
 if n==440 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)

