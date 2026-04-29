# ==============================
# Delete OpenClaw / OpenClaw-CN on Win11
# Keep startup scheduled tasks
# Run as Administrator
# ==============================

Write-Host "=== OpenClaw uninstall start ===" -ForegroundColor Cyan

# Check administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Please run PowerShell as Administrator!" -ForegroundColor Red
    pause
    exit 1
}

# Stop OpenClaw processes
Write-Host "`n[1/5] Stopping OpenClaw processes..." -ForegroundColor Yellow

$processNames = @(
    "openclaw",
    "openclaw-cn"
)

foreach ($p in $processNames) {
    Get-Process -Name $p -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# Stop only node.exe processes related to openclaw
Get-CimInstance Win32_Process -Filter "name = 'node.exe'" -ErrorAction SilentlyContinue |
Where-Object {
    $_.CommandLine -match "openclaw"
} |
ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped OpenClaw node process: $($_.ProcessId)" -ForegroundColor Green
}

# Uninstall OpenClaw by npm
Write-Host "`n[2/5] Uninstalling OpenClaw from npm..." -ForegroundColor Yellow

if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm uninstall -g openclaw
    npm uninstall -g openclaw-cn
    npm uninstall -g @openclaw/cli
    npm uninstall -g @openclaw-cn/cli
} else {
    Write-Host "npm not found, skip npm uninstall." -ForegroundColor DarkYellow
}

# Delete config and cache
Write-Host "`n[3/5] Removing OpenClaw config and cache..." -ForegroundColor Yellow

$paths = @(
    "$env:USERPROFILE\.openclaw",
    "$env:USERPROFILE\.openclaw-cn",
    "$env:APPDATA\OpenClaw",
    "$env:APPDATA\openclaw",
    "$env:LOCALAPPDATA\OpenClaw",
    "$env:LOCALAPPDATA\openclaw",
    "$env:LOCALAPPDATA\openclaw-cn",
    "$env:TEMP\openclaw",
    "$env:TEMP\openclaw-cn"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted: $path" -ForegroundColor Green
    }
}

# Remove npm command leftovers
Write-Host "`n[4/5] Cleaning npm command leftovers..." -ForegroundColor Yellow

if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmPrefix = npm prefix -g 2>$null

    if ($npmPrefix) {
        $possibleFiles = @(
            "openclaw",
            "openclaw.cmd",
            "openclaw.ps1",
            "openclaw-cn",
            "openclaw-cn.cmd",
            "openclaw-cn.ps1"
        )

        foreach ($file in $possibleFiles) {
            $full = Join-Path $npmPrefix $file
            if (Test-Path $full) {
                Remove-Item $full -Force -ErrorAction SilentlyContinue
                Write-Host "Deleted command leftover: $full" -ForegroundColor Green
            }
        }
    }
}

# Verify
Write-Host "`n[5/5] Verifying..." -ForegroundColor Yellow

$openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
$openclawCnCmd = Get-Command openclaw-cn -ErrorAction SilentlyContinue

if (-not $openclawCmd -and -not $openclawCnCmd) {
    Write-Host "`nOpenClaw commands removed." -ForegroundColor Green
} else {
    Write-Host "`nOpenClaw command leftovers still found:" -ForegroundColor Red

    if ($openclawCmd) {
        Write-Host "openclaw: $($openclawCmd.Source)" -ForegroundColor Red
    }

    if ($openclawCnCmd) {
        Write-Host "openclaw-cn: $($openclawCnCmd.Source)" -ForegroundColor Red
    }
}

Write-Host "`nNotice: This script did NOT delete Windows startup scheduled tasks." -ForegroundColor Yellow
Write-Host "=== OpenClaw uninstall complete ===" -ForegroundColor Cyan

pause