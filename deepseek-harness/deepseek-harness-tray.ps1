# deepseek-harness tray supervisor (Windows PowerShell 5.1, no external deps)
# Modes: default = resident tray;  -Stop = stop deepseek-harness and exit (single implementation of stop).
param([switch]$Stop)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'

# Force every relative path in this script to resolve against the script's own folder,
# not the caller's CWD. PS cmdlets use the session location; .NET APIs use CurrentDirectory.
if ($PSScriptRoot) {
    Set-Location -LiteralPath $PSScriptRoot
    [Environment]::CurrentDirectory = $PSScriptRoot + [IO.Path]::DirectorySeparatorChar
}

$port     = 3080
$launcher = '.\deepseek-harness.ps1'
$iconSource = '..\favicon.ico'
$title    = 'deepseek-harness web'

$script:busy = $false
$script:iconOn = $null
$script:iconOff = $null
$script:lastPhase = $null

# Balloon for processes that have no tray icon of their own (e.g. a refused duplicate).
# The pump is required: a balloon is drawn by the shell while this process keeps pumping
# messages, so exiting immediately would drop it.
function Show-OrphanTip([string]$text, [int]$ms) {
    $icon = $null
    try {
        $icon = New-Object System.Windows.Forms.NotifyIcon
        $icon.Icon = [System.Drawing.SystemIcons]::Application
        $icon.Visible = $true
        $icon.BalloonTipTitle = $title
        $icon.BalloonTipText  = $text
        $icon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info
        $icon.ShowBalloonTip($ms)
        $end = (Get-Date).AddMilliseconds($ms + 500)
        while ((Get-Date) -lt $end) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 60
        }
        $icon.Visible = $false
    } catch {}
    if ($icon) { $icon.Dispose() }
}

if (-not $Stop) {
    $script:mutex = New-Object System.Threading.Mutex($false, 'Local\deepseek-harness-tray-supervisor')
    if (-not $script:mutex.WaitOne(0)) {
        Show-OrphanTip '托盘已在运行，去托盘区找那个圆点图标。' 5000
        exit 0
    }
}

function Get-PortOwner {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($c) { return ($c.OwningProcess | Sort-Object -Unique | Select-Object -First 1) }
    return $null
}

function Get-LauncherPid {
    $p = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
         Where-Object { $_.CommandLine -like '*WindowStyle Hidden*' -and $_.CommandLine -like '*\deepseek-harness.ps1*' }
    return @($p | ForEach-Object { $_.ProcessId })
}

function Get-Phase {
    $owner = Get-PortOwner
    $lch = Get-LauncherPid
    if ($owner) { return [pscustomobject]@{ Name = 'running'; PortPid = $owner; Launcher = $lch } }
    if ($lch.Count -gt 0) { return [pscustomobject]@{ Name = 'building'; PortPid = $null; Launcher = $lch } }
    return [pscustomobject]@{ Name = 'stopped'; PortPid = $null; Launcher = @() }
}

function Stop-Tree([int]$procId) {
    if ($procId -gt 0) { & taskkill.exe /T /F /PID $procId 2>&1 | Out-Null }
}

function Invoke-Stop {
    $s = Get-Phase
    if ($s.Name -eq 'stopped') { return $true }
    foreach ($p in $s.Launcher) { Stop-Tree ([int]$p) }
    if ($s.PortPid) { Stop-Tree ([int]$s.PortPid) }
    Start-Sleep -Milliseconds 800
    return ((Get-Phase).Name -eq 'stopped')
}

if ($Stop) {
    $s = Get-Phase
    if ($s.Name -eq 'stopped') { Write-Host '[INFO] deepseek-harness already stopped.'; exit 0 }
    Write-Host ('[STOP] launcher PID: ' + $(if ($s.Launcher.Count) { $s.Launcher -join ',' } else { '-' }))
    Write-Host ('[STOP] port' + $port + ' PID : ' + $(if ($s.PortPid) { $s.PortPid } else { '-' }))
    if (Invoke-Stop) { Write-Host '[STOP] done, port released.'; exit 0 }
    Write-Host '[STOP] WARNING: still running - inspect manually.'
    exit 1
}

function Show-Balloon([string]$text, [bool]$err) {
    $ni.BalloonTipTitle = $title
    $ni.BalloonTipText  = $text
    if ($err) { $ni.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error }
    else      { $ni.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info }
    $ni.ShowBalloonTip(4000)
}

function New-StatusIcon([bool]$running) {
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $drawn = $false
        if (Test-Path $iconSource) {
            try {
                $art = New-Object System.Drawing.Bitmap -ArgumentList $iconSource
                try { $g.DrawImage($art, 0, 0, $size - 6, $size - 6); $drawn = $true }
                finally { $art.Dispose() }
            } catch { $drawn = $false }
        }
        if (-not $drawn) {
            $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 100, 100, 100))
            try { $g.FillEllipse($b, 3, 3, $size - 10, $size - 10) } finally { $b.Dispose() }
        }

        if ($running) { $c = [System.Drawing.Color]::FromArgb(255, 22, 160, 84) }
        else          { $c = [System.Drawing.Color]::FromArgb(255, 165, 165, 165) }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
        $b2  = New-Object System.Drawing.SolidBrush $c
        try {
            $g.DrawEllipse($pen, 19, 19, 12, 12)
            $g.FillEllipse($b2, 20, 20, 10, 10)
        } finally { $pen.Dispose(); $b2.Dispose() }

        return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    } finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

function Initialize-Icons {
    $script:iconOn  = New-StatusIcon $true
    $script:iconOff = New-StatusIcon $false
}

function Refresh-Ui {
    $s = Get-Phase

    # Transition-based notification: the tray already recomputes phase every tick, so a
    # "startup finished" tip is just an edge on that state machine - no separate watcher.
    if ($script:lastPhase -and $script:lastPhase -ne 'running' -and $s.Name -eq 'running') {
        Show-Balloon "启动完成，端口 $port 已就绪 (PID $($s.PortPid))。" $false
    }
    $script:lastPhase = $s.Name

    switch ($s.Name) {
        'running' {
            $miState.Text  = "状态: 运行中  (端口 $port / PID $($s.PortPid))"
            $ni.Icon = $script:iconOn
            $ni.Text = "$title - 运行中 (PID $($s.PortPid))"
        }
        'building' {
            $miState.Text  = "状态: 构建中  (启动器 PID $($s.Launcher -join ','), 约 3-5 分钟)"
            $ni.Icon = $script:iconOff
            $ni.Text = "$title - 构建中"
        }
        default {
            $miState.Text  = '状态: 已停止'
            $ni.Icon = $script:iconOff
            $ni.Text = "$title - 已停止"
        }
    }
    $canAct = -not $script:busy
    $miStart.Enabled   = ($s.Name -eq 'stopped') -and $canAct
    $miStop.Enabled    = ($s.Name -ne 'stopped') -and $canAct
    $miRestart.Enabled = $canAct
    $ni.Visible = $true
}

function Do-Start {
    if ($script:busy) { return }
    $s = Get-Phase
    if ($s.Name -ne 'stopped') {
        if ($s.Name -eq 'building') { Show-Balloon '正在构建中，请等它完成（互斥锁会拒绝重复启动）。' $false }
        else { Show-Balloon "端口 $port 已在服务，无需重复启动。" $false }
        return
    }
    if (-not (Test-Path $launcher)) { Show-Balloon "找不到 $launcher" $true; return }
    $script:busy = $true
    Refresh-Ui
    Show-Balloon '开始 clean/install/build 并启动，约 3-5 分钟，完成后图标变绿。' $false
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $launcher)
    $script:busy = $false
    Refresh-Ui
}

function Do-Stop {
    if ($script:busy) { return }
    $s = Get-Phase
    if ($s.Name -eq 'stopped') { Show-Balloon '没有在运行，无需停止。' $false; return }
    $script:busy = $true
    Refresh-Ui
    $ok = Invoke-Stop
    $script:busy = $false
    if ($ok) { Show-Balloon '已停止。' $false } else { Show-Balloon '停止后端口仍被占用，请手动检查。' $true }
    Refresh-Ui
}

function Do-Restart {
    if ($script:busy) { return }
    Do-Stop
    if ($script:busy) { return }
    if ((Get-Phase).Name -eq 'stopped') { Do-Start }
}

function Do-Open {
    if (Get-PortOwner) { Start-Process "http://127.0.0.1:$port/" }
    else { Show-Balloon '服务未运行，无法打开。' $true }
}

function Do-Exit {
    $s = Get-Phase
    $script:busy = $false
    if ($s.Name -ne 'stopped') { Invoke-Stop | Out-Null }
    if ($script:timer) { $script:timer.Stop() }
    $ni.Visible = $false
    [System.Windows.Forms.Application]::Exit()
}

Initialize-Icons

$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = $script:iconOff
$ni.Visible = $true

$miState = New-Object System.Windows.Forms.ToolStripMenuItem('状态: 检测中')
$miState.Enabled = $false
$miStart   = New-Object System.Windows.Forms.ToolStripMenuItem('启动 / 构建')
$miStop    = New-Object System.Windows.Forms.ToolStripMenuItem('停止')
$miRestart = New-Object System.Windows.Forms.ToolStripMenuItem('重启')
$miOpen    = New-Object System.Windows.Forms.ToolStripMenuItem('在浏览器中打开')
$miExit    = New-Object System.Windows.Forms.ToolStripMenuItem('退出（同时停止 deepseek-harness 服务）')

$miStart.add_Click({ Do-Start })
$miStop.add_Click({ Do-Stop })
$miRestart.add_Click({ Do-Restart })
$miOpen.add_Click({ Do-Open })
$miExit.add_Click({ Do-Exit })
$ni.add_MouseDoubleClick({ Do-Open })

$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add($miState)
[void]$menu.Items.Add('-')
[void]$menu.Items.Add($miStart)
[void]$menu.Items.Add($miStop)
[void]$menu.Items.Add($miRestart)
[void]$menu.Items.Add('-')
[void]$menu.Items.Add($miOpen)
[void]$menu.Items.Add('-')
[void]$menu.Items.Add($miExit)
$ni.ContextMenuStrip = $menu

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 3000
$script:timer.add_Tick({ Refresh-Ui })
$script:timer.Start()

Refresh-Ui

# Double-click means "get it running": build and launch immediately unless something already is.
if ((Get-Phase).Name -eq 'stopped') { Do-Start }

[System.Windows.Forms.Application]::Run()

$script:timer.Stop(); $script:timer.Dispose()
$ni.Dispose()
if ($script:iconOn)  { $script:iconOn.Dispose() }
if ($script:iconOff) { $script:iconOff.Dispose() }
if ($script:mutex)   { try { $script:mutex.ReleaseMutex(); $script:mutex.Dispose() } catch {} }
