local f=assert(io.open(os.getenv('QUICKGAME_REFERENCE_OUTPUT')..'/down-direction.csv','w'))
f:write('case,frame,size,state,raw,lr,ud,crouch,vx,frac,x\n')
local n=0
local cases={{'small_down_right',1,true,true,false},{'super_down_right',0,true,true,false},{'small_down',1,true,false,false},{'super_down',0,true,false,false},{'super_air_down_right',0,true,true,true},{'super_crouched_air_right',0,true,true,true,true}}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function()
 local k=math.floor((n-340)/32)+1
 local c=cases[k]
 if c and (n-340)%32==0 then
  w(0x754,c[2]);w(0x756,c[2]==1 and 0 or 1);w(0x86,56);w(0xce,c[5] and 130 or 176);w(0x1d,c[5] and 1 or 0);w(0x57,10);w(0x700,0);w(0x45,1);w(0x33,1);w(0x70c,10);w(0x714,c[6] and 4 or 0);w(0x9f,0);w(0x416,0)
 end
 emu.setInput({start=n==120,down=c and c[3] or false,right=c and c[4] or false,a=false,b=false,left=false,up=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 local k=math.floor((n-341)/32)+1
 local c=cases[k]
 if c and (n-341)%32<4 then f:write(string.format('%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',c[1],n,r(0x754),r(0x1d),r(0x6fc),r(0xc),r(0xb),r(0x714),r(0x57),r(0x700),r(0x86))) end
 if n==532 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)
