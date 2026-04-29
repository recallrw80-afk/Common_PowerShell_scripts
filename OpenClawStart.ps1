<#
.SYNOPSIS
    OpenClaw Gateway + Chrome startup to Gateway UI.
.DESCRIPTION
    Task 1: Start OpenClaw Gateway at Windows startup.
    Task 2: Open Google Chrome to OpenClaw Web UI after user logon.
.NOTES
    Run as Administrator.
#>
Unregister-ScheduledTask -TaskName "OpenClawGateway" -Confirm:$false
Unregister-ScheduledTask -TaskName "OpenChromeGatewayUI" -Confirm:$false
# --------------------
# ����
# --------------------
$gatewayTaskName = "OpenClawGateway"
$chromeTaskName  = "OpenChromeGatewayUI"

# --------------------
# ������ԱȨ��
# --------------------
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Host "Please run PowerShell as Administrator!" -ForegroundColor Red
    exit 1
}

# --------------------
# ɾ��������
# --------------------
if (Get-ScheduledTask -TaskName $gatewayTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $gatewayTaskName -Confirm:$false
}
if (Get-ScheduledTask -TaskName $chromeTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $chromeTaskName -Confirm:$false
}

# --------------------
# ���� 1: OpenClaw Gateway
# --------------------
$gatewayAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"openclaw gateway`""

$gatewayTrigger = New-ScheduledTaskTrigger -AtStartup

$gatewayPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $gatewayTaskName `
    -Action $gatewayAction `
    -Trigger $gatewayTrigger `
    -Principal $gatewayPrincipal `
    -Description "Start OpenClaw Gateway at Windows startup"

# --------------------
# ���� 2: �� Chrome ���� Gateway UI
# --------------------
$chromeAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"openclaw dashboard`""

$chromeTrigger = New-ScheduledTaskTrigger -AtLogOn

$chromePrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $chromeTaskName `
    -Action $chromeAction `
    -Trigger $chromeTrigger `
    -Principal $chromePrincipal `
    -Description "Open Chrome to OpenClaw Web UI at user logon"

Write-Host ""
Write-Host "Done. Registered tasks:" -ForegroundColor Green
Write-Host " - $gatewayTaskName (OpenClaw Gateway)"
Write-Host " - $chromeTaskName (Chrome to $gatewayUrl)"


# Start-ScheduledTask -TaskName "OpenClawGateway"
# Start-ScheduledTask -TaskName "OpenChromeGatewayUI"

# Get-ScheduledTask -TaskName "OpenClawGateway","OpenChromeGatewayUI"

# Unregister-ScheduledTask -TaskName "OpenClawGateway" -Confirm:$false
# Unregister-ScheduledTask -TaskName "OpenChromeGatewayUI" -Confirm:$false