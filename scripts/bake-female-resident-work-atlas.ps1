param([string]$Source,[string]$Output)
Add-Type -AssemblyName System.Drawing
$sourceAtlas=[Drawing.Bitmap]::new($Source)
$atlas=[Drawing.Bitmap]::new(384,4080)
for($y=0;$y -lt $atlas.Height;$y++){
  for($x=0;$x -lt $atlas.Width;$x++){
    $p=$sourceAtlas.GetPixel($x,$y)
    if($p.A -eq 0){continue}
    $localY=$y%120
    if($p.R -gt 114 -and $p.G -gt 82 -and $p.R-$p.G -gt 10 -and $p.R-$p.B -gt 24 -and ($localY -lt 47 -or $localY -gt 83)){
      $p=[Drawing.Color]::FromArgb($p.A,[Math]::Min(255,$p.R+11),[Math]::Min(255,$p.G+3),[Math]::Max(0,$p.B-4))
    }
    $atlas.SetPixel($x,$y,$p)
  }
}
$sourceAtlas.Dispose()
$art=[Drawing.Graphics]::FromImage($atlas)
$art.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
function Color($hex){[Drawing.ColorTranslator]::FromHtml($hex)}
function Pen($hex,$width){[Drawing.Pen]::new((Color $hex),$width)}
function Brush($hex){[Drawing.SolidBrush]::new((Color $hex))}
$shaft=Pen '#58391e' 4
$shine=Pen '#b48149' 1.5
$edge=Pen '#3d3531' 1.4
$blade=Brush '#918e7e'
$light=Pen '#c2b9a1' 1.2
$basket=Brush '#90602d'
$basketEdge=Pen '#55351d' 1.6
$basketWeave=Pen '#c39859' 1.4
$log=Brush '#775133'
$logEnd=Brush '#c19558'
$stone=Brush '#88867d'
$grain=Brush '#dfaa36'
$hand=Brush '#aa7856'
function Point($x,$y){[Drawing.PointF]::new($x,$y)}
$hands=@(
  @(@(47,47),@(48,17),@(47,47),@(47,66)),
  @(@(19,43),@(39,18),@(19,43),@(34,64)),
  @(@(47,47),@(47,17),@(47,47),@(47,67)),
  @(@(76,43),@(57,18),@(76,43),@(59,64))
)
for($dir=0;$dir -lt 4;$dir++){
  for($row=8;$row -lt 34;$row++){
    $art.ResetTransform()
    $art.TranslateTransform([single](96*$dir),[single](120*$row))
    if($row -lt 16){
      $frame=($row-8)%4
      $x,$y=$hands[$dir][$frame]
      $dx=if($dir -eq 1){-1}elseif($dir -eq 3){1}else{if($dir -eq 2){-0.42}else{0.42}}
      $rise=@(7,15,7,-14)[$frame]
      $ex=$x+13*$dx
      $ey=$y-$rise
      $art.DrawLine($shaft,[single]($x-4*$dx),[single]($y+3),[single]$ex,[single]$ey)
      $art.DrawLine($shine,[single]$x,[single]($y-1),[single]$ex,[single]($ey-1))
      if($row -lt 12){
        $points=[Drawing.PointF[]]@((Point ($ex-3) ($ey-4)),(Point ($ex+4) ($ey-5)),(Point ($ex+6) ($ey+4)),(Point ($ex-1) ($ey+4)))
      }else{
        $points=[Drawing.PointF[]]@((Point ($ex-8) ($ey+2)),(Point ($ex-3) ($ey-5)),(Point ($ex+3) ($ey-5)),(Point ($ex+8) ($ey+1)),(Point ($ex+1) ($ey-1)),(Point ($ex-3) ($ey-1)))
      }
      $art.FillPolygon($blade,$points)
      $art.DrawPolygon($edge,$points)
      $art.DrawLine($light,$points[1],$points[2])
      if($dir -ne 2){$art.FillEllipse($hand,[single]($x-2.6),[single]($y-2.4),[single]5.2,[single]4.8)}
      continue
    }
    $offset=@(-17,5,0,-5)[$dir]
    $x=48+$offset
    $y=55+@(0,1,2,1,0,1)[($row-16)%6]
    if($row -lt 22){
      for($i=0;$i -lt 3;$i++){
        $top=$y+$i*6-7
        $art.FillRectangle($log,[single]($x-10),[single]$top,[single]21,[single]7)
        $art.FillEllipse($logEnd,[single]($x+7),[single]$top,[single]8,[single]7)
      }
      $art.DrawLine($basketWeave,[single]($x-5),[single]($y-8),[single]($x-5),[single]($y+12))
      $art.DrawLine($basketWeave,[single]($x+2),[single]($y-8),[single]($x+2),[single]($y+12))
    }else{
      $points=[Drawing.PointF[]]@((Point ($x-12) ($y-3)),(Point ($x+12) ($y-3)),(Point ($x+8) ($y+14)),(Point ($x-8) ($y+14)))
      $art.FillPolygon($basket,$points)
      $art.DrawPolygon($basketEdge,$points)
      $fill=if($row -lt 28){$stone}else{$grain}
      for($i=0;$i -lt 3;$i++){$art.FillEllipse($fill,[single]($x-10+$i*6),[single]($y-9+($i%2)*2),[single]9,[single]7)}
      $art.DrawArc($basketWeave,[single]($x-12),[single]($y-8),[single]24,[single]10,[single]0,[single]180)
      $art.DrawArc($basketWeave,[single]($x-10),[single]$y,[single]20,[single]10,[single]0,[single]180)
    }
  }
}
$art.Dispose()
$atlas.Save($Output,[Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
