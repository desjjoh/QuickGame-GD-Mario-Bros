# Run capture scripts first. Compare visible sprite shapes at matched clock/timer phases.
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $repoRoot
try {
@"
import csv
from pathlib import Path
with Path('.godot/validation/verify-transform-pixels.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['case','clock','nes','x','y','godot'])
 for case in ['growth_run','growth_jump','damage_run','damage_jump']:
  ns={int(r['frame'])-123:r for r in csv.DictReader(Path('docs/archive/reference/transformation-mesen-'+case+'.csv').open())}
  for r in csv.DictReader(Path('.godot/validation/godot-'+case+'.csv').open()):
   c=int(r['clock']);end=273 if case.startswith('damage') else 277
   if c>end or (case.startswith('damage') and c%2):continue
   n=ns[c];w.writerow([case,c,case+'-'+str(int(n['frame'])+2)+'.png',n['x'],int(n['y'])+1,'godot-'+case+'-'+r['relative']+'.png'])
"@ | python -
if($LASTEXITCODE -ne 0){throw 'Frame selection failed'}
Add-Type -AssemblyName System.Drawing
function PaletteIndex($color,$source){
 if(-not $source -and $color.A -eq 0){return 0}
 if($color.R -eq 181 -and $color.G -eq 49){return 1}
 if($color.R -eq 107 -and $color.G -eq 109){return 2}
 if(($color.R -eq 234 -and $color.G -eq 158)-or($color.R -eq 230 -and $color.G -eq 156)){return 3}
 return 0
}
$results=@()
foreach($row in (Import-Csv .godot/validation/verify-transform-pixels.csv)){
 $nes=[System.Drawing.Bitmap]::new((Join-Path $repoRoot ('.godot/validation/'+$row.nes)))
 $godot=[System.Drawing.Bitmap]::new((Join-Path $repoRoot ('.godot/validation/'+$row.godot)))
 $wrong=0
 for($y=0;$y -lt 32;$y++){for($x=0;$x -lt 16;$x++){
  if((PaletteIndex ($nes.GetPixel([int]$row.x+$x,[int]$row.y+$y)) $true) -ne (PaletteIndex ($godot.GetPixel($x,$y)) $false)){$wrong++}
 }}
 $nes.Dispose();$godot.Dispose()
 $results+=[pscustomobject]@{case=$row.case;clock=$row.clock;differences=$wrong}
}
$results | Export-Csv .godot/validation/transform-pixel-results.csv -NoTypeInformation
$bad=@($results | Where-Object {$_.differences -gt 0})
if($results.Count -ne 174 -or $bad.Count -gt 0){$bad | Format-Table;throw 'Transformation capture mismatch'}
Write-Output 'PASS: 174/174 visible sprite shapes match the controlled Mesen captures after palette normalization.'
} finally {Pop-Location}
