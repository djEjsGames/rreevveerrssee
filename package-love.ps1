$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root "LOVE"
$dist = Join-Path $root "dist"
$name = "nitori-factory-prototype"
$zip = Join-Path $dist "$name.zip"
$love = Join-Path $dist "$name.love"

if (-not (Test-Path $dist)) {
	New-Item -ItemType Directory -Path $dist | Out-Null
}

Remove-Item -LiteralPath $zip, $love -Force -ErrorAction SilentlyContinue

$items = Get-ChildItem -LiteralPath $src -Force | Where-Object {
	$_.Name -notmatch '\.tmp$|\.bak$|\.webp$'
}
Compress-Archive -LiteralPath $items.FullName -DestinationPath $zip -Force
Move-Item -LiteralPath $zip -Destination $love -Force

Write-Output "Created $love"

