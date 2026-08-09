$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pages = Join-Path $root "docs"

& (Join-Path $root "package-love.ps1")

if (Test-Path -LiteralPath $pages) {
	Remove-Item -LiteralPath $pages -Recurse -Force
}

$env:npm_config_cache = Join-Path $root ".npm-cache"
npx -y -p love.js love.js.cmd (Join-Path $root "dist\rreevveerrssee-prototype.love") $pages -c -t rreevveerrssee-prototype
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"
