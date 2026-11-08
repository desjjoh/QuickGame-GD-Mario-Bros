local out=os.getenv('QUICKGAME_REFERENCE_OUTPUT')
local f=assert(io.open(out..'/landing-rejump-reference.csv','w'))
f:write('form,travel,case,step,state,y,vx,jump\n')
local cases={}
for _,size in ipairs({1,0})do for _,dir in ipairs({1,-1})do
 for _,c in ipairs({{'fast_immediate',40,0,1},{'threshold_delayed_tap',27,1,1},{'threshold_delayed_hold',27,1,20},{'contact_press',24,0,0},{'contact_hold',24,0,0}})do
  table.insert(cases,{size=size,dir=dir,name=c[1],speed=c[2],delay=c[3],hold=c[4]})
 end
end end
local n=0
local grounded=0
local startJump=nil
local jump=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local k=math.floor((n-340)/48)+1;local c=cases[k];local step=(n-340)%48
 jump=false
 if c then
  for i=0,5 do w(0x0f+i,0) end
  -- Keep the comparison court flat despite renderer/parser history between cases.
  for a=0x500,0x69f do w(a,0) end
  for col=0,15 do w(0x5b0+col,0x54);w(0x5c0+col,0x54);w(0x680+col,0x54);w(0x690+col,0x54) end
 end
 if c and step==0 then
  w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x755,120)

  grounded=0;startJump=nil
  w(0x490,3);w(0x70b,0);w(0x747,0);w(0xe,8)
  w(0x754,c.size);w(0x756,c.size==1 and 0 or 1);w(0x6d,0);w(0x86,120);w(0xce,174);w(0xb5,1);w(0x1d,2)
  w(0x57,(c.speed*c.dir)%256);w(0x700,c.speed);w(0x705,0);w(0x400,0);w(0x45,c.dir==1 and 1 or 2);w(0x33,c.dir==1 and 1 or 2)
  w(0x703,c.speed>=28 and 40 or 0);w(0x783,0);w(0x9f,2);w(0x433,0);w(0x416,0);w(0xd,0);w(0x785,0);w(0x70a,0x70);w(0x714,0)
 end
 if c then
  if r(0x1d)==0 then grounded=grounded+1 end
  if c.hold>0 and startJump==nil and r(0x1d)==0 and grounded>c.delay then startJump=step end
  if startJump~=nil then jump=step-startJump<c.hold end
  if c.name=='contact_press' then jump=step==0 end
  if c.name=='contact_hold' then jump=step<=2 end
 end
 emu.setInput({start=n==120,left=c and c.dir==1 or false,right=c and c.dir==-1 or false,a=jump,b=c~=nil,up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1;local k=math.floor((n-341)/48)+1;local c=cases[k]
 if c then
  local vx=r(0x57);if vx>=128 then vx=vx-256 end
  f:write(string.format('%s,%d,%s,%d,%d,%d,%.6f,%d\n',c.size==1 and 'small' or 'super',c.dir,c.name,(n-341)%48+1,r(0x1d),r(0xce)+32,(vx+r(0x705)/256)*3.75,jump and 1 or 0))
 end
 if n==1300 then f:close();emu.stop(0)end
end,emu.eventType.endFrame)

