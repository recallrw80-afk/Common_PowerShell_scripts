# deepseek-harness-web launcher (PowerShell)
# Requires: git, node, pnpm on PATH.
$ErrorActionPreference = 'Continue'

# Force relative paths to resolve against this script's own folder, not the caller's CWD.
if ($PSScriptRoot) {
    Set-Location -LiteralPath $PSScriptRoot
    [Environment]::CurrentDirectory = $PSScriptRoot + [IO.Path]::DirectorySeparatorChar
}

$repo = 'C:\Users\user001\deepseek-harness'
$port = 3080

$script:mutex = New-Object System.Threading.Mutex($false, 'Local\deepseek-harness-web-launcher')
if (-not $script:mutex.WaitOne(0)) {
    Write-Host '[INFO] Another deepseek-harness launcher is already running or serving; exiting.'
    exit 0
}

function Fail([string]$msg) {
    Write-Host "[ERROR] $msg"
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $tip = New-Object System.Windows.Forms.NotifyIcon
        $tip.Icon = [System.Drawing.SystemIcons]::Error
        $tip.Visible = $true
        $tip.BalloonTipTitle = 'deepseek-harness 启动失败'
        $tip.BalloonTipText  = $msg
        $tip.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Error
        $tip.ShowBalloonTip(8000)
        # The shell renders the balloon only while this process keeps pumping messages.
        $end = (Get-Date).AddMilliseconds(8500)
        while ((Get-Date) -lt $end) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 60
        }
        $tip.Visible = $false
        $tip.Dispose()
    } catch {}
    Pop-Location -ErrorAction SilentlyContinue
    exit 1
}

if (-not (Test-Path $repo)) { Fail "Repo dir not found: $repo" }
Push-Location $repo

Write-Host '============================================================'
Write-Host '[Step 1/6] Checking for a new git tag release ...'
Write-Host '============================================================'

git fetch --quiet --tags 2>$null

$newest = (git tag --sort=-v:refname 2>$null | Select-Object -First 1)
if (-not $newest) {
    Write-Host '[INFO] No tags found, skipping update.'
} else {
    git merge-base --is-ancestor $newest HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[INFO] Already up to date at $newest, skipping update."
    } else {
        Write-Host "[INFO] New version $newest detected, checking out ..."
        $attempt = 0
        while ($true) {
            $attempt++
            git checkout --detach $newest 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[INFO] Checked out $newest (attempt $attempt)."
                break
            }
            Write-Host "[!] Update to $newest failed (attempt $attempt), retrying in 2s ..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host ''
Write-Host '============================================================'
Write-Host '[Step 2/6] Cleaning build outputs ...'
Write-Host '============================================================'
& pnpm run clean
if ($LASTEXITCODE -ne 0) { Fail 'pnpm run clean failed.' }

Write-Host ''
Write-Host '============================================================'
Write-Host '[Step 3/6] Installing dependencies ...'
Write-Host '============================================================'
& pnpm install
if ($LASTEXITCODE -ne 0) { Fail 'pnpm install failed.' }

Write-Host ''
Write-Host '============================================================'
Write-Host '[Step 4/6] Building ...'
Write-Host '============================================================'
& pnpm run build
if ($LASTEXITCODE -ne 0) { Fail 'pnpm run build failed.' }

Write-Host ''
Write-Host '============================================================'
Write-Host "[Step 5/6] Checking port $port ..."
Write-Host '============================================================'
$listeners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listeners) {
    $listeners | ForEach-Object {
        Write-Host "[INFO] Port $port in use by PID $($_.OwningProcess), stopping process ..."
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[INFO] Port $port is free."
}

Write-Host ''
Write-Host '============================================================'
Write-Host '[Step 6/6] Starting deepseek-harness web ...'
Write-Host '============================================================'
& pnpm dsh web --no-open

Write-Host ''
Write-Host '============================================================'
Write-Host 'deepseek-harness web exited.'
Write-Host '============================================================'
Pop-Location
