$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$webPlay = Join-Path $root "web-play"
$pages = Join-Path $root "docs"

if (-not (Test-Path -LiteralPath $webPlay)) {
	& (Join-Path $root "package-love.ps1")
	$env:npm_config_cache = Join-Path $root ".npm-cache"
	npx -y -p love.js love.js.cmd (Join-Path $root "dist\rreevveerrssee-prototype.love") $webPlay -c -t rreevveerrssee-prototype
}

if (Test-Path -LiteralPath $pages) {
	Remove-Item -LiteralPath $pages -Recurse -Force
}

Copy-Item -LiteralPath $webPlay -Destination $pages -Recurse
Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"
