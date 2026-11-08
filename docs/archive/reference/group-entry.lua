local out=os.getenv('QUICKGAME_REFERENCE_OUTPUT')
local f=assert(io.open(out..'/group-entry.csv','w'))
f:write('frame,slot,x,y,left,right,oam_x,oam_y\n')
local n=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=n==120,right=false,left=false,up=false,down=false,a=false,b=false,select=false},0)
 if n==340 then
  w(0x6d,2);w(0x86,129);w(0xce,176);w(0x57,0);w(0x71a,2);w(0x71c,49);w(0x71b,3);w(0x71d,48)
 end
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 if n>=340 and n<=365 then
 for i=0,4 do
  if r(0xf+i)~=0 then
   local o=r(0x6e5+i)
   f:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d\n',n,i,r(0x6e+i)*256+r(0x87+i),r(0xcf+i),r(0x71a)*256+r(0x71c),r(0x71b)*256+r(0x71d),r(0x203+o),r(0x200+o)))
  end
 end
 end
 if n==342 then
  local o=r(0x6e5)
  for j=0,5 do emu.log('ROW '..j..' y='..r(0x200+o+4*j)..' tile='..r(0x201+o+4*j)..' x='..r(0x203+o+4*j)) end
  local dump=assert(io.open(out..'/group-oam.txt','w'))
  for j=0,5 do dump:write(string.format('%d,%d,%d,%d\n',j,r(0x200+o+4*j),r(0x201+o+4*j),r(0x203+o+4*j))) end
  dump:close()
 end
 if n==365 then f:close();emu.stop(0) end
end,emu.eventType.endFrame)
