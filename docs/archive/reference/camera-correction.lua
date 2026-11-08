local output=os.getenv('QUICKGAME_REFERENCE_OUTPUT')
local f=assert(io.open(output..'/camera-correction.csv','w'))
f:write('frame,player_x,left,scroll_step,side_timer\n')
local frame=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addEventCallback(function()
 emu.setInput({start=frame==120,a=false,b=false,left=false,right=false,up=false,down=false,select=false},0)
 if frame==340 then w(0x6d,1);w(0x86,192);w(0x71a,1);w(0x71c,0);w(0x71b,1);w(0x71d,255);w(0x57,0);w(0x700,0);w(0x723,0);w(0x785,0)end
 if frame==350 then w(0x86,r(0x86)+4)end
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=348 then f:write(string.format('%d,%d,%d,%d,%d\n',frame,r(0x6d)*256+r(0x86),r(0x71a)*256+r(0x71c),r(0x6ff),r(0x785)))end
 if frame==355 then f:close();emu.stop(0)end
end,emu.eventType.endFrame)
