<#
.SYNOPSIS
    Map Windows ports to WSL2 and register startup task.
.DESCRIPTION
    Ports: 
    Safe to run repeatedly.
.NOTES
    Run as Administrator.
#>

# --------------------
# Config
# --------------------
$ports = @(8000, 7860)

# Auto get WSL2 IP
$wslAddress = (wsl hostname -I).Trim().Split(" ")[0]

if (-not $wslAddress) {
    Write-Host "Cannot get WSL2 IP. Please start WSL first." -ForegroundColor Red
    exit 1
}

Write-Host "WSL2 IP: $wslAddress" -ForegroundColor Green

# --------------------
# Check Administrator
# --------------------
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Host "Please run PowerShell as Administrator!" -ForegroundColor Red
    exit 1
}

# --------------------
# Delete old portproxy rules
# --------------------
foreach ($port in $ports) {
    Write-Host "Delete existing port mapping: $port"
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
}

# --------------------
# Add new portproxy rules
# --------------------
foreach ($port in $ports) {
    Write-Host "Add port mapping: Windows $port -> WSL $wslAddress`:$port"
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslAddress
}

# --------------------
# Show result
# --------------------
Write-Host ""
Write-Host "Current portproxy list:"
netsh interface portproxy show all

# --------------------
# Register startup task
# --------------------
$taskName = "WSLPortMapping"
$taskDescription = "Auto map Windows ports to WSL2"
$scriptPath = $MyInvocation.MyCommand.Definition

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description $taskDescription

Write-Host ""
Write-Host "Startup task registered."