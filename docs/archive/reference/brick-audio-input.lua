-- Read-only observations plus controller input only. No RAM/ROM/state writes.
local out=assert(os.getenv('QUICKGAME_REFERENCE_OUTPUT'))
local n=0
local phase='approach'
local jumped=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function signed(v)return v>=128 and v-256 or v end
local audio=assert(io.open(out..'/brick-audio-registers.csv','w'))
audio:write('frame,address,value,cycle\n')
emu.addMemoryCallback(function(address,value)
 if n>=930 and n<=969 then
  local state=emu.getState()
  audio:write(string.format('%d,%04x,%02x,%s\n',n+1,address,value,tostring(state['cpu.cycleCount'] or state['cpu.cycle'] or 'unknown')))
 end
end,emu.callbackType.write,0x4000,0x400f)
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
 if n>=970 then audio:close();emu.stop(0) end
end,emu.eventType.endFrame)
