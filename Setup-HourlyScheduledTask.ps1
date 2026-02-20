# Setup-HourlyScheduledTask.ps1
# This script creates a Windows Scheduled Task to run PowerBI-Refresh-Script_v2.ps1
# every hour from 6 AM to 8 PM daily

# Requires Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please run as Administrator."
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again."
    exit
}

# Configuration
$scriptPath = "$PSScriptRoot\PowerBI-Refresh-Script_v2.ps1"
$taskName = "PowerBI Refresh - Hourly 6AM-8PM"
$taskDescription = "Runs PowerBI refresh script every hour from 6 AM to 8 PM"

# Verify the script exists
if (-not (Test-Path $scriptPath)) {
    Write-Error "PowerBI-Refresh-Script_v2.ps1 not found at: $scriptPath"
    Write-Host "Please ensure the script is in the same directory as this setup script."
    exit
}

Write-Host "Setting up scheduled task: $taskName" -ForegroundColor Cyan
Write-Host "Script to run: $scriptPath" -ForegroundColor Gray

# Create the action (what to run)
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $PSScriptRoot

# Create triggers for each hour from 6 AM to 8 PM (15 triggers total)
$triggers = @()
for ($hour = 6; $hour -le 20; $hour++) {
    $trigger = New-ScheduledTaskTrigger -Daily -At "$($hour):00"
    $triggers += $trigger
    Write-Host "  Added trigger: $($hour):00" -ForegroundColor Green
}

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

# Create principal (run as current user)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# Register the scheduled task
try {
    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    # Register new task
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $taskDescription `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null
    
    Write-Host "`nScheduled task created successfully!" -ForegroundColor Green
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $taskName"
    Write-Host "  Schedule: Every hour from 6:00 AM to 8:00 PM daily"
    Write-Host "  Script: $scriptPath"
    Write-Host "  User: $env:USERNAME"
    Write-Host "`nYou can view/modify this task in Task Scheduler (taskschd.msc)" -ForegroundColor Yellow
    Write-Host "To remove this task, run: Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}
