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
$buildVersion = (git -C $root rev-parse --short HEAD).Trim() + " / " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss K")
$bridge = @'
<script>
(function () {
  const originalOpen = window.open.bind(window);
  const BUILD_VERSION = "__NITORI_BUILD_VERSION__";

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
    overlay.style.cssText = "width:min(940px,calc(100vw - 48px));height:360px;margin:24px auto;display:none;flex-direction:column;background:#101316;color:#f2f2e8;border:2px solid #ffd84a;border-radius:8px;box-shadow:0 12px 36px rgba(0,0,0,.35);font:14px system-ui,sans-serif;";

    const bar = document.createElement("div");
    bar.style.cssText = "display:flex;align-items:center;gap:8px;padding:10px 12px;border-bottom:1px solid #3b3f42;background:#181c1f;";

    const title = document.createElement("div");
    title.id = "nitori-dump-title";
    title.style.cssText = "flex:1;font-weight:700;";

    const select = document.createElement("button");
    select.textContent = "Select all";

    const issue = document.createElement("button");
    issue.textContent = "GitHub issue";

    const status = document.createElement("span");
    status.id = "nitori-dump-status";
    status.style.cssText = "color:#bfc4c8;font-size:12px;";

    const close = document.createElement("button");
    close.textContent = "Close";

    const textarea = document.createElement("textarea");
    textarea.id = "nitori-dump-textarea";
    textarea.spellcheck = false;
    textarea.style.cssText = "flex:1;box-sizing:border-box;width:100%;resize:none;border:0;outline:0;padding:14px;background:#111;color:#f3f3e8;font:13px Consolas,monospace;line-height:1.35;white-space:pre;";

    select.addEventListener("click", () => { textarea.focus(); textarea.select(); });
    issue.addEventListener("click", () => {
      const titleText = "Nitori Factory Dump - " + new Date().toISOString().slice(0, 19).replace("T", " ");
      const body = "Build: " + BUILD_VERSION + "\nURL: " + location.href + "\nUser-Agent: " + navigator.userAgent + "\n\n" + textarea.value;
      const issueBase = "https://github.com/djEjsGames/rreevveerrssee/issues/new";
      const fullUrl = issueBase + "?title=" + encodeURIComponent(titleText) + "&body=" + encodeURIComponent(body);
      if (fullUrl.length < 7500) {
        originalOpen(fullUrl, "_blank", "noopener");
        status.textContent = "Issue tab opened with body.";
      } else {
        textarea.focus();
        textarea.select();
        originalOpen(issueBase + "?title=" + encodeURIComponent(titleText), "_blank", "noopener");
        status.textContent = "Dump is long. Paste the selected text into the issue body.";
      }
    });
    close.addEventListener("click", () => { overlay.style.display = "none"; });
    overlay.addEventListener("keydown", (event) => { if (event.key === "Escape") overlay.style.display = "none"; });

    bar.append(title, select, issue, status, close);
    overlay.append(bar, textarea);
    const canvas = document.getElementById("canvas");
    if (canvas && canvas.parentNode) {
      canvas.parentNode.insertBefore(overlay, canvas.nextSibling);
    } else {
      document.body.appendChild(overlay);
    }
    stopGameInput(overlay);
    return overlay;
  }

  window.showNitoriDump = function (title, text) {
    const overlay = ensureDumpOverlay();
    const textarea = document.getElementById("nitori-dump-textarea");
    document.getElementById("nitori-dump-title").textContent = (title || "Nitori Dump") + "  Build " + BUILD_VERSION;
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
$bridgeVersion = $buildVersion.Replace("\", "\\").Replace('"', '\"')
$bridge = $bridge.Replace("__NITORI_BUILD_VERSION__", $bridgeVersion)
$html = $html -replace '</body>', ($bridge + "`r`n</body>")
Set-Content -LiteralPath $index -Value $html -NoNewline

Set-Content -LiteralPath (Join-Path $pages ".nojekyll") -Value ""
Write-Output "Created GitHub Pages build in $pages"

