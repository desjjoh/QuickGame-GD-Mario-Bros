-- Read-only observations plus controller input only. No RAM/ROM/state writes.
local out=assert(os.getenv('QUICKGAME_REFERENCE_OUTPUT'))
local direction=tonumber(os.getenv('BRICK_TRACE_DIRECTION')) or 1
local takeoff=tonumber(os.getenv('BRICK_TRACE_TAKEOFF')) or 310
local label=(direction==1 and 'right-' or 'left-')..takeoff
local f=assert(io.open(out..'/running-'..label..'-frames.csv','w'))
f:write('frame,phase,routine,state,form,x,y,vy,vfrac,yfrac,vx,block0,block1,mode,mode_task\n')
local first_break=nil
local events=assert(io.open(out..'/running-'..label..'-events.csv','w'))
events:write('frame,slot,brick_x,player_x,head_x,origin_y,vfrac,yfrac\n')
local n=0
local phase='approach'
local jumped=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function signed(v)return v>=128 and v-256 or v end
local writes=assert(io.open(out..'/running-'..label..'-writes.csv','w'))
writes:write('frame,address,value,y,vy,vfrac,yfrac,pc\n')
local dumped=false
local function observe(address,value)
 if phase=='break' then
  local state=emu.getState()
  local pc=state['cpu.pc'] or state['nes.cpu.pc'] or 0
  if address==0x9f and value==0xfe and pc==0xbe13 then
   if first_break==nil then first_break=n+1 end
   local slot=r(0x3ee)
   local bx=r(0x76+slot)*256+r(0x8f+slot)
   local px=r(0x6d)*256+r(0x86)
   events:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d\n',n+1,slot,bx,px,px+8,r(0xce),r(0x433),r(0x416)))
  end
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
  if r(0x754)==0 and r(0x756)>0 and phase~='break' and phase~='runup' then phase='super' end
  if phase=='super' then
   local staging=direction==1 and 336 or 432
   steer(staging)
   if math.abs(x-staging)<=2 and math.abs(signed(r(0x57)))<=3 and r(0x1d)==0 and r(0xce)==176 then phase='runup' end
  end
  if phase=='runup' then
   input.b=true;input.left=direction==-1;input.right=direction==1
   if (direction==1 and x>=takeoff)or(direction==-1 and x<=takeoff)then phase='break';jumped=n end
  end
  if phase=='break' then
   input.a=n-jumped<30;input.b=true;input.left=direction==-1;input.right=direction==1
  end
 end
 emu.setInput(input,0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 n=n+1
 if first_break~=nil and n>=first_break and n<=first_break+12 then
  local shot=assert(io.open(out..'/running-'..label..'-'..(n-first_break)..'.png','wb'))
  shot:write(emu.takeScreenshot());shot:close()
 end
 if n>=340 then
  f:write(string.format('%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',n,phase,r(0xe),r(0x1d),r(0x754),r(0x6d)*256+r(0x86),r(0xce),signed(r(0x9f)),r(0x433),r(0x416),signed(r(0x57)),r(0x26),r(0x27),r(0x770),r(0x772)))
 end
 if n>=2200 or (first_break~=nil and n>=first_break+24) or (phase=='break' and n-jumped>100)then f:close();writes:close();events:close();emu.stop(0)end
end,emu.eventType.endFrame)
