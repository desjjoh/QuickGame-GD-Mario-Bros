-- Controlled RAM fixtures; never modifies ROM bytes. Requires Lua IO enabled in a temporary runner.
local output = os.getenv("QUICKGAME_REFERENCE_OUTPUT") or "."
local f=assert(io.open(output .. "/mesen-super-trace.csv","w"))
f:write("frame,routine,state,crouch,x,y,vx,vy,size,box,lefttile,righttile\n")
local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local original=0
emu.addEventCallback(function()
 local input={a=false,b=false,up=false,down=false,left=false,right=false,select=false,start=(frame==120)}
 if frame==340 then w(0x754,0);w(0x756,1) end
 if frame>=350 and frame<365 then input.down=true end
 if frame==355 then input.a=true end
 if frame>=380 and frame<390 then input.down=true;input.right=true end
 if frame==430 then w(0x86,56);w(0xce,176);w(0x1d,0);w(0x57,0);w(0x9f,0);original=r(0x594);w(0x594,r(0x5b4)) end
 if frame>=430 and frame<435 then input.down=true end
 if frame==500 then w(0x86,40);w(0xce,176);w(0x1d,0);w(0x57,0);w(0x9f,0);w(0x592,r(0x5b2)) end
 if frame>=500 and frame<505 then input.down=true end
 if frame==530 then w(0x592,0) end
 if frame==550 then w(0x86,56);w(0xce,176);w(0x1d,0);w(0x57,0);w(0x9f,0);w(0x593,r(0x5b3));w(0x594,r(0x5b4)) end
 if frame>=550 and frame<555 then input.down=true end
 if frame==600 then w(0x593,0);w(0x594,0) end
 if frame==620 then w(0x86,56);w(0xce,176);w(0x1d,0);w(0x57,0);w(0x9f,0);w(0x5b3,0x10);w(0x5b4,0x11) end
 if frame>=620 and frame<630 then input.down=true end
 if frame==900 then w(0x86,184);w(0xce,176);w(0x1d,0);w(0x57,0);w(0x9f,0);w(0x785,0) end
 if frame>=900 then input.right=true end
 if frame==460 then w(0x594,original) end
 emu.setInput(input,0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==850 then
 local image=assert(io.open(output .. "/mesen-underground.png","wb"));image:write(emu.takeScreenshot());image:close()
 local tiles=assert(io.open(output .. "/mesen-underground-tiles.txt","w"))
 for row=0,12 do for col=0,15 do tiles:write(string.format("%02x ",r(0x500+row*16+col))) end tiles:write("\n") end tiles:close()
 end
 if frame>=340 then
 f:write(string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",frame,r(0x0e),r(0x1d),r(0x714),r(0x86),r(0xce),emu.read(0x57,emu.memType.nesDebug,true),emu.read(0x9f,emu.memType.nesDebug,true),r(0x754),r(0x499),r(0x594),r(0x5b4)));f:flush()
 end
 if frame>=1240 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)
