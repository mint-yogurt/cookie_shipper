#Requires -Version 5.1
# Validates the Brave extension's raw cookie export and ships it to the receiver.
# Run on a timer (Task Scheduler) while logged in. A failed/invalid run is
# skipped silently -- the next scheduled run tries again.

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

function Write-Log([string]$msg) {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Add-Content -Path (Join-Path $here "ship.log") -Value $line
}

function Read-SecretsEnv([string]$path) {
    $map = @{}
    foreach ($line in Get-Content -Path $path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $idx = $trimmed.IndexOf("=")
        if ($idx -lt 1) { continue }
        $key = $trimmed.Substring(0, $idx).Trim()
        $val = $trimmed.Substring($idx + 1).Trim()
        $map[$key] = $val
    }
    return $map
}

try {
    $secretsPath = Join-Path $here "secrets.env"
    if (-not (Test-Path $secretsPath)) {
        Write-Log "ABORT: secrets.env not found"
        exit 0
    }
    $secrets = Read-SecretsEnv $secretsPath
    if (-not $secrets.ContainsKey("SSH_USER") -or -not $secrets.ContainsKey("SSH_HOST")) {
        Write-Log "ABORT: secrets.env missing SSH_USER / SSH_HOST"
        exit 0
    }
    $target = "{0}@{1}" -f $secrets["SSH_USER"], $secrets["SSH_HOST"]
    $keyPath = Join-Path $env:USERPROFILE ".ssh\cookie_shipper"
    if (-not (Test-Path $keyPath)) {
        Write-Log "ABORT: ssh key not found at $keyPath"
        exit 0
    }

    $rawPath = Join-Path $env:USERPROFILE "Downloads\cookie_shipper\youtube_cookies_raw.txt"
    if (-not (Test-Path $rawPath)) {
        Write-Log "ABORT: raw cookie export not found at $rawPath (is the Brave extension installed and Brave running?)"
        exit 0
    }

    $raw = [System.IO.File]::ReadAllText($rawPath)
    $rawLines = $raw -split "`n" | ForEach-Object { $_.TrimEnd("`r") }

    # --- filter to .youtube.com / .google.com cookies only ---
    $kept = @()
    foreach ($line in $rawLines) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $fields = $line.Split("`t")
        if ($fields.Count -ne 7) { continue }
        $domain = $fields[0].ToLowerInvariant().TrimStart(".")
        if ($domain -eq "youtube.com" -or $domain.EndsWith(".youtube.com") -or
            $domain -eq "google.com" -or $domain.EndsWith(".google.com")) {
            $kept += $line
        }
    }

    $finalLines = @("# Netscape HTTP Cookie File") + $kept
    $finalContent = ($finalLines -join "`n") + "`n"

    # --- validate ---
    if ($finalLines[0] -ne "# Netscape HTTP Cookie File") {
        Write-Log "ABORT: validation failed (missing header)"
        exit 0
    }
    $dataLines = $finalLines | Select-Object -Skip 1
    $badField = $dataLines | Where-Object { $_.Split("`t").Count -ne 7 }
    if ($badField) {
        Write-Log "ABORT: validation failed (a cookie line does not have 7 tab-separated fields)"
        exit 0
    }
    $youtubeCount = ($dataLines | Where-Object { $_.Split("`t")[0] -eq ".youtube.com" }).Count
    if ($youtubeCount -lt 1) {
        Write-Log "ABORT: validation failed (no .youtube.com cookie found)"
        exit 0
    }

    $finalPath = Join-Path $here "youtube_cookies.txt"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($finalPath, $finalContent, $utf8NoBom)
    Write-Log "validated: $($dataLines.Count) cookies ($youtubeCount .youtube.com)"

    # --- send ---
    # cmd /c, not a PowerShell pipe: PowerShell 5.1 has no `<` redirect and
    # `|` can mangle encoding/line endings (see RECEIVER.md).
    $remoteCmd = "cat > ~/cookie_shipper/.incoming_cookies.txt && mv ~/cookie_shipper/.incoming_cookies.txt ~/cookie_shipper/youtube_cookies.txt"
    $sshCmd = "ssh -i `"$keyPath`" $target `"$remoteCmd`" < `"$finalPath`""
    cmd /c $sshCmd
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Log "sent ok"
    } else {
        Write-Log "ABORT: ssh send failed (exit $exitCode) -- skipped, will retry next run"
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
}
