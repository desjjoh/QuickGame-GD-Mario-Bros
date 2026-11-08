# Run after the two capture scripts. Outputs ignored comparison images, not assets.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $repoRoot
try {
@"
import csv
from pathlib import Path
clocks=[220,224,228,232,236,240,244,248,252,256,260,264,268,272,274,278]
with Path('.godot/validation/transformation-samples.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['case','clock','mesen_png','x','y','godot_png'])
 for case in ['growth_run','growth_jump','damage_run','damage_jump']:
  nes={}; previous=-1; wrap=0
  for r in csv.DictReader(Path('.godot/validation/'+case+'.csv').open()):
   raw=int(r['clock'])
   if raw<previous: wrap+=256
   nes[raw+wrap]=r;previous=raw
  gd={int(r['clock']):r for r in csv.DictReader(Path('.godot/validation/godot-'+case+'.csv').open())}
  for c in clocks:
   n=nes[c];g=gd[c]
   w.writerow([case,c,case+'-'+str(int(n['frame'])+2)+'.png',n['x'],int(n['y'])+1,'godot-'+case+'-'+g['relative']+'.png'])
"@ | python -
if($LASTEXITCODE -ne 0){throw 'Sample alignment failed'}
Add-Type -AssemblyName System.Drawing
$rows=Import-Csv .godot/validation/transformation-samples.csv
foreach($kind in @('growth','damage')) {
 $bmp=[System.Drawing.Bitmap]::new(1376,700)
 $g=[System.Drawing.Graphics]::FromImage($bmp)
 $g.Clear([System.Drawing.Color]::FromArgb(36,38,45))
 $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
 $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
 $font=[System.Drawing.Font]::new('Consolas',9)
 for($ci=0;$ci -lt 2;$ci++){
  $case=$kind+'_'+@('run','jump')[$ci];$y0=$ci*350
  $g.DrawString(($case+' - Mesen above / Godot below'),$font,[System.Drawing.Brushes]::White,8,$y0+4)
  $samples=@($rows | Where-Object {$_.case -eq $case})
  for($i=0;$i -lt $samples.Count;$i++){
   $r=$samples[$i];$x0=8+$i*85
   $g.DrawString(('C'+$r.clock),$font,[System.Drawing.Brushes]::White,$x0,$y0+22)
   $nes=[System.Drawing.Bitmap]::new((Join-Path $repoRoot ('.godot/validation/'+$r.mesen_png)))
   $g.DrawImage($nes,[System.Drawing.Rectangle]::new($x0,$y0+40,64,128),[System.Drawing.Rectangle]::new([int]$r.x,[int]$r.y,16,32),[System.Drawing.GraphicsUnit]::Pixel)
   $nes.Dispose()
   $gd=[System.Drawing.Bitmap]::new((Join-Path $repoRoot ('.godot/validation/'+$r.godot_png)))
   $g.DrawImage($gd,[System.Drawing.Rectangle]::new($x0,$y0+190,64,128),[System.Drawing.Rectangle]::new(0,0,16,32),[System.Drawing.GraphicsUnit]::Pixel)
   $gd.Dispose()
  }
 }
 $bmp.Save((Join-Path $repoRoot ('.godot/validation/'+$kind+'-comparison.png')))
 $font.Dispose();$g.Dispose();$bmp.Dispose()
}
} finally {Pop-Location}
