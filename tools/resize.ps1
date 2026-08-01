# metis-photos 写真一括リサイズ
#   inbox/ の元写真を 長辺 $MaxEdge px・JPEG品質 $Quality に変換してリポジトリ直下へ出力する。
#   再エンコードにより EXIF（位置情報・機種名等）は除去される。EXIF回転は反映してから捨てる。
#   -MapCsv（列: 元ファイル名,商品コード）を渡すと出力名を <商品コード>.jpg にリネームする。
param(
  [string]$Source  = (Join-Path $PSScriptRoot '..\inbox'),
  [string]$Dest    = (Join-Path $PSScriptRoot '..'),
  [int]$MaxEdge    = 1200,
  [int]$Quality    = 80,
  [string]$MapCsv  = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $Source)) { throw "入力フォルダがありません: $Source" }
$Source = (Resolve-Path $Source).Path
$Dest   = (Resolve-Path $Dest).Path

# 対応表（元ファイル名→商品コード）。キーは拡張子あり/なし両方・小文字で引けるようにする
$map = @{}
if ($MapCsv) {
  foreach ($row in (Import-Csv $MapCsv)) {
    $name = [string]$row.元ファイル名; $code = [string]$row.商品コード
    if (-not $name -or -not $code) { continue }
    $map[$name.ToLower()] = $code
    $map[[IO.Path]::GetFileNameWithoutExtension($name).ToLower()] = $code
  }
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]$Quality)

$exts = '.jpg', '.jpeg', '.png', '.bmp'
$files = Get-ChildItem -Path $Source -File -Recurse | Where-Object { $exts -contains $_.Extension.ToLower() }
$heic  = Get-ChildItem -Path $Source -File -Recurse | Where-Object { $_.Extension -match '(?i)^\.heic$' }
if ($heic) { Write-Warning ("HEIC は変換できません（iPhone側でJPEG書き出しが必要）: " + (($heic | ForEach-Object Name) -join ', ')) }
if (-not $files) { Write-Host "変換対象がありません（$Source に jpg/png/bmp を入れてください。サブフォルダ内も探索します）"; return }

$done = 0; $unmapped = @(); $seen = @{}
foreach ($f in $files) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  try {
    # EXIF Orientation(0x0112) を実回転に反映（スマホ写真の横倒れ防止）
    if ($img.PropertyIdList -contains 0x0112) {
      switch ($img.GetPropertyItem(0x0112).Value[0]) {
        2 { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
        3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        4 { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY) }
        5 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
        6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        7 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
        8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
      }
    }

    $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $base = $base -replace '(?i)\.(jpe?g|png|bmp)$', ''   # 二重拡張子の正規化（例 std-005_01.jpg.jpeg → std-005_01）
    $code = $map[$f.Name.ToLower()]; if (-not $code) { $code = $map[$base.ToLower()] }
    if ($MapCsv -and -not $code) { $unmapped += $f.Name }
    $outName = if ($code) { "$code.jpg" } else { "$base.jpg" }
    $outName = $outName.ToLower()   # Pages のURLは大文字小文字を区別するため小文字に統一
    if ($seen.ContainsKey($outName.ToLower())) {
      Write-Warning "出力名が重複するためスキップ: $($f.FullName) -> $outName（別フォルダに同名ファイルあり。リネームするか対応表で商品コードを分けてください）"
      continue
    }
    $seen[$outName.ToLower()] = $true
    $outPath = Join-Path $Dest $outName

    $scale = [Math]::Min(1.0, $MaxEdge / [double][Math]::Max($img.Width, $img.Height))
    $nw = [Math]::Max(1, [int][Math]::Round($img.Width * $scale))
    $nh = [Math]::Max(1, [int][Math]::Round($img.Height * $scale))

    $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $g.DrawImage($img, 0, 0, $nw, $nh)
    } finally { $g.Dispose() }

    try { $bmp.Save($outPath, $jpegCodec, $encParams) } finally { $bmp.Dispose() }
    $kb = [Math]::Round((Get-Item $outPath).Length / 1KB)
    Write-Host ("OK  {0}  ->  {1}  ({2}x{3}, {4} KB)" -f $f.Name, $outName, $nw, $nh, $kb)
    $done++
  } finally { $img.Dispose() }
}

Write-Host ""
Write-Host "変換完了: $done / $($files.Count) 件 -> $Dest"
if ($unmapped) { Write-Warning ("対応表に無い元ファイル（元の名前のまま出力済み）: " + ($unmapped -join ', ')) }
Write-Host "push 前に出力画像を目視してください（機微の写り込み・横倒れ・ぼやけ）"
