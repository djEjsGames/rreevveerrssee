param(
	[string]$BaseUrl = "https://djejsgames.github.io/rreevveerrssee"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pages = Join-Path $root "docs"
$infoPath = Join-Path $pages "build-info.json"

if (-not (Test-Path -LiteralPath $infoPath)) {
	throw "Run package-pages.ps1 first."
}

$info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json
$cacheBust = [Uri]::EscapeDataString($info.love_sha256.Substring(0, 12))
$remoteInfo = Invoke-RestMethod -Uri "$BaseUrl/build-info.json?v=$cacheBust"

if ($remoteInfo.love_sha256 -ne $info.love_sha256) {
	throw "Pages is stale. local=$($info.love_sha256) remote=$($remoteInfo.love_sha256)"
}

$gameJs = Invoke-WebRequest -Uri "$BaseUrl/game.js?v=$cacheBust" -UseBasicParsing
if ($gameJs.Content -notmatch [Regex]::Escape($info.data_file)) {
	throw "Pages game.js does not reference $($info.data_file)."
}

$data = Invoke-WebRequest -Uri "$BaseUrl/$($info.data_file)?v=$cacheBust" -Method Head -UseBasicParsing
if ([int64]$data.Headers["Content-Length"] -ne [int64]$info.data_bytes) {
	throw "Pages data size mismatch. local=$($info.data_bytes) remote=$($data.Headers["Content-Length"])"
}

Write-Output "OK: Pages is serving $($info.data_file) ($($info.love_sha256.Substring(0, 12)))."
