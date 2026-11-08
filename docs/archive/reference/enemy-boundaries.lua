local f=assert(io.open(os.getenv('QUICKGAME_REFERENCE_OUTPUT')..'/enemy-boundaries.csv','w'))
f:write('frame,event,slot,id,enemy_x,left,right,from_left,from_right\n')
local n=0
local prior={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function pos(p,x) return r(p)*256+r(x) end
emu.addEventCallback(function()
 emu.setInput({start=n==120,right=n>=340,a=false,b=n>=340,left=false,up=false,down=false,select=false},0)
 if n>=340 then emu.write(0x79e,255,emu.memType.nesDebug) end
 for i=0,4 do prior[i]={r(0xf+i),r(0x16+i),pos(0x6e+i,0x87+i),pos(0x71a,0x71c),pos(0x71b,0x71d)} end
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 for i=0,4 do
  local p=prior[i]
  if p then
   local live=r(0xf+i)~=0
   if live and p[1]==0 then
    local x=pos(0x6e+i,0x87+i);local l=pos(0x71a,0x71c);local rr=pos(0x71b,0x71d)
    f:write(string.format('%d,spawn,%d,%d,%d,%d,%d,%d,%d\n',n,i,r(0x16+i),x,l,rr,x-l,x-rr))
   elseif not live and p[1]~=0 then
    f:write(string.format('%d,removed,%d,%d,%d,%d,%d,%d,%d\n',n,i,p[2],p[3],p[4],p[5],p[3]-p[4],p[3]-p[5]))
   end
  end
 end
 if n==1200 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)
