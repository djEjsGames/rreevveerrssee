$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root "dist"
$web = Join-Path $root "web"
$love = Join-Path $dist "nitori-factory-prototype.love"

if (-not (Test-Path -LiteralPath $love)) {
	& (Join-Path $root "package-love.ps1")
}

Copy-Item -LiteralPath $love -Destination (Join-Path $web "nitori-factory-prototype.love") -Force
Write-Output "Created web test build in $web"

