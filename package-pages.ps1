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

$index = Join-Path $pages "index.html"
$bridge = @'
<script>
(function () {
  const originalOpen = window.open.bind(window);

  function stopGameInput(el) {
    ["keydown", "keyup", "keypress", "mousedown", "mouseup", "mousemove", "wheel", "touchstart", "touchmove"].forEach((name) => {
      el.addEventListener(name, (event) => event.stopPropagation(), { passive: false });
    });
  }

  function ensureDumpOverlay() {
    let overlay = document.getElementById("nitori-dump-overlay");
    if (overlay) return overlay;

    overlay = document.createElement("div");
    overlay.id = "nitori-dump-overlay";
    overlay.style.cssText = "position:fixed;inset:24px;z-index:99999;display:none;flex-direction:column;background:#101316;color:#f2f2e8;border:2px solid #ffd84a;border-radius:8px;box-shadow:0 18px 60px rgba(0,0,0,.55);font:14px system-ui,sans-serif;";

    const bar = document.createElement("div");
    bar.style.cssText = "display:flex;align-items:center;gap:8px;padding:10px 12px;border-bottom:1px solid #3b3f42;background:#181c1f;";

    const title = document.createElement("div");
    title.id = "nitori-dump-title";
    title.style.cssText = "flex:1;font-weight:700;";

    const select = document.createElement("button");
    select.textContent = "Select all";

    const close = document.createElement("button");
    close.textContent = "Close";

    const textarea = document.createElement("textarea");
    textarea.id = "nitori-dump-textarea";
    textarea.spellcheck = false;
    textarea.style.cssText = "flex:1;box-sizing:border-box;width:100%;resize:none;border:0;outline:0;padding:14px;background:#111;color:#f3f3e8;font:13px Consolas,monospace;line-height:1.35;white-space:pre;";

    select.addEventListener("click", () => { textarea.focus(); textarea.select(); });
    close.addEventListener("click", () => { overlay.style.display = "none"; });
    overlay.addEventListener("keydown", (event) => { if (event.key === "Escape") overlay.style.display = "none"; });

    bar.append(title, select, close);
    overlay.append(bar, textarea);
    document.body.appendChild(overlay);
    stopGameInput(overlay);
    return overlay;
  }

  window.showNitoriDump = function (title, text) {
    const overlay = ensureDumpOverlay();
    const textarea = document.getElementById("nitori-dump-textarea");
    document.getElementById("nitori-dump-title").textContent = title || "Nitori Dump";
    textarea.value = text || "";
    overlay.style.display = "flex";
    setTimeout(() => { textarea.focus(); textarea.select(); }, 0);
  };

  window.open = function (url, target, features) {
    if (typeof url === "string" && url.indexOf("nitori-dump:") === 0) {
      const payload = url.slice("nitori-dump:".length);
      const split = payload.indexOf(":");
      const title = split >= 0 ? payload.slice(0, split) : "Nitori Dump";
      const text = split >= 0 ? payload.slice(split + 1) : payload;
      window.showNitoriDump(decodeURIComponent(title), decodeURIComponent(text));
      return null;
    }
    return originalOpen(url, target, features);
  };
}());
</script>
'@
$html = Get-Content -LiteralPath $index -Raw
$html = $html -replace '</body>', ($bridge + "`r`n</body>")
Set-Content -LiteralPath $index -Value $html -NoNewline

Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"

