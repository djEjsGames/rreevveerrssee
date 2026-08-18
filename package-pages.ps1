$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$webPlay = Join-Path $root "web-play"
$pages = Join-Path $root "docs"

& (Join-Path $root "package-love.ps1")
$env:npm_config_cache = Join-Path $root ".npm-cache"

if (Test-Path -LiteralPath $webPlay) {
Remove-Item -LiteralPath $webPlay -Recurse -Force
}

npx -y -p love.js love.js.cmd (Join-Path $root "dist\nitori-factory-prototype.love") $webPlay -c -t nitori-factory-prototype

if (Test-Path -LiteralPath $pages) {
Remove-Item -LiteralPath $pages -Recurse -Force
}

Copy-Item -LiteralPath $webPlay -Destination $pages -Recurse
Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"

