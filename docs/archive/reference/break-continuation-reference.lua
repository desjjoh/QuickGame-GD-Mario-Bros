local out=os.getenv('QUICKGAME_REFERENCE_OUTPUT')
local f=assert(io.open(out..'/break-continuation-reference.csv','w'))
f:write('case,step,x,feet,vx,vy,head_inside,upper_inside,material,left_tile,center_tile,right_tile,bounce_timer\n')
local cases={}
for _,row in ipairs({false,true})do for _,dir in ipairs({1,-1})do
 table.insert(cases,{dir=dir,feet=172,tile=0x51,row=row})
end end
local n=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function solid(x,y)return x>=128 and x<144 and y>=128 and y<144 end
emu.addEventCallback(function()
 local k=math.floor((n-340)/24)+1;local c=cases[k];local step=(n-340)%24
 if c then
  for a=0x500,0x69f do if (a<0x567 or a>0x569) or step==0 then w(a,0)end end
  if step==0 then w(0x568,c.tile);if c.row then w(0x567,c.tile);w(0x569,c.tile)end;w(0x26,0);w(0x27,0);w(0x784,0)end
  for i=0,5 do w(0x0f+i,0)end
 end
 if c and step==0 then
  w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x755,120)
  w(0x490,3);w(0x70b,0);w(0x747,0);w(0xe,8)
  w(0x754,0);w(0x756,1);w(0x6d,0);w(0x86,c.dir==1 and 118 or 138);w(0xce,c.feet-32);w(0xb5,1);w(0x1d,1)
  w(0x57,40*c.dir);w(0x700,40);w(0x705,0);w(0x400,0);w(0x45,c.dir==1 and 1 or 2);w(0x33,c.dir==1 and 1 or 2)
  w(0x703,40);w(0x783,0);w(0x9f,-1);w(0x433,0);w(0x416,0);w(0xd,0x80);w(0x785,0);w(0x709,0x20);w(0x70a,0x90);w(0x707,1);w(0x708,176);w(0x714,0)
 end
 emu.setInput({start=n==120,left=c and c.dir==-1 or false,right=c and c.dir==1 or false,a=c~=nil,b=c~=nil,up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1;local k=math.floor((n-341)/24)+1;local c=cases[k]
 if c then
  local x=r(0x86)+8;local feet=r(0xce)+32;local vx=r(0x57);if vx>=128 then vx=vx-256 end;local vy=r(0x9f);if vy>=128 then vy=vy-256 end
  f:write(string.format('%d,%d,%d,%d,%.6f,%d,%s,%s,%02x,%02x,%02x,%02x,%d\n',k,(n-341)%24+1,x,feet,(vx+r(0x705)/256)*3.75,vy,tostring(solid(x,feet-28)),tostring(solid(x-6,feet-24)or solid(x+5,feet-24)),c.tile,r(0x567),r(0x568),r(0x569),r(0x784)))
 end
 if n>=436 then f:close();emu.stop(0)end
end,emu.eventType.endFrame)
