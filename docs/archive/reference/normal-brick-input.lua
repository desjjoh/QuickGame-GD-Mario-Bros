-- Read-only observations plus controller input only. No RAM/ROM/state writes.
local out=assert(os.getenv('QUICKGAME_REFERENCE_OUTPUT'))
local f=assert(io.open(out..'/normal-brick-input.csv','w'))
f:write('frame,phase,routine,state,form,x,y,vy,vfrac,yfrac,vx,block0,block1,mode,mode_task\n')
local n=0
local phase='approach'
local jumped=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function signed(v)return v>=128 and v-256 or v end
local writes=assert(io.open(out..'/normal-brick-writes.csv','w'))
writes:write('frame,address,value,y,vy,vfrac,yfrac,pc\n')
local dumped=false
local function observe(address,value)
 if n>=931 and n<=938 then
  local state=emu.getState()
  if not dumped then
   local d=assert(io.open(out..'/normal-brick-state-keys.txt','w'))
   for k,v in pairs(state)do d:write(tostring(k)..'='..tostring(v)..'\n')end
   d:close();dumped=true
  end
  local pc=state['cpu.pc'] or state['nes.cpu.pc'] or 0
  writes:write(string.format('%d,%04x,%02x,%d,%d,%d,%d,%s\n',n+1,address,value,r(0xce),signed(r(0x9f)),r(0x433),r(0x416),tostring(pc)))
 end
end
for _,address in ipairs({0x9f,0xce,0x433,0x416})do emu.addMemoryCallback(observe,emu.callbackType.write,address,address)end
emu.addMemoryCallback(function(address,value)
 if value==0x23 or value==0 then observe(address,value)end
end,emu.callbackType.write,0x500,0x69f)
emu.addEventCallback(function()
 local x=r(0x6d)*256+r(0x86)
 local input={start=n>=120 and n<130,a=false,b=n>=340,left=false,right=false,up=false,down=false,select=false}
 local function steer(target)
  local desired=math.max(-24,math.min(24,(target-x)*2))
  local vx=signed(r(0x57))
  input.left=vx>desired+1;input.right=vx<desired-1;input.b=false
 end
 if n>=340 and r(0xe)==8 then
  if phase=='approach' then
   input.right=true
   if x>=280 then phase='jump';jumped=n end
  end
  if phase=='jump' then
   input.a=n-jumped<30;input.right=x<410
   if n-jumped>90 then phase='under' end
  end
  if phase=='under' then
   steer(336)
   if math.abs(x-336)<=2 and math.abs(signed(r(0x57)))<=3 and r(0x1d)==0 and r(0xce)==176 then phase='punch';jumped=n end
  end
  if phase=='punch' then
   input.a=n-jumped<30;input.b=false
   if n-jumped>60 then phase='collect' end
  end
  if phase=='collect' then steer(417) end
  if r(0x754)==0 and r(0x756)>0 and phase~='break' then phase='super' end
  if phase=='super' then
   steer(352)
   if math.abs(x-352)<=2 and math.abs(signed(r(0x57)))<=3 and r(0x1d)==0 and r(0xce)==176 then phase='break';jumped=n end
  end
  if phase=='break' then input.a=n-jumped<30;input.b=false end
 end
 emu.setInput(input,0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 if n>=934 and n<=939 then
  local shot=assert(io.open(out..'/normal-brick-'..n..'.png','wb'))
  shot:write(emu.takeScreenshot());shot:close()
 end
 if n>=340 then
  f:write(string.format('%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',n,phase,r(0xe),r(0x1d),r(0x754),r(0x6d)*256+r(0x86),r(0xce),signed(r(0x9f)),r(0x433),r(0x416),signed(r(0x57)),r(0x26),r(0x27),r(0x770),r(0x772)))
 end
 if n>=970 then f:close();writes:close();local p=assert(io.open(out..'/normal-brick-pilot.png','wb'));p:write(emu.takeScreenshot());p:close();emu.stop(0)end
end,emu.eventType.endFrame)
