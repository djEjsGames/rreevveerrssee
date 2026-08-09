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
$data = Join-Path $pages "game.data"
$hash = (Get-FileHash -LiteralPath $data -Algorithm SHA256).Hash.Substring(0, 12).ToLowerInvariant()
$dataName = "game-$hash.data"
Rename-Item -LiteralPath $data -NewName $dataName
$gameJs = Join-Path $pages "game.js"
(Get-Content -LiteralPath $gameJs -Raw).Replace("game.data", $dataName) | Set-Content -LiteralPath $gameJs -NoNewline
$info = [ordered]@{
	data_file = $dataName
	data_bytes = (Get-Item -LiteralPath (Join-Path $pages $dataName)).Length
	love_sha256 = (Get-FileHash -LiteralPath (Join-Path $root "dist\rreevveerrssee-prototype.love") -Algorithm SHA256).Hash.ToLowerInvariant()
}
$info | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $pages "build-info.json") -Encoding UTF8
Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"
