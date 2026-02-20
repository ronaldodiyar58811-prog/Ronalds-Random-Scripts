# Run-HourlyLoop.ps1
# This script runs PowerBI-Refresh-Script_v2.ps1 every hour from 6 AM to 8 PM
# Keep this PowerShell window open while it runs

$scriptPath = "$PSScriptRoot\PowerBI-Refresh-Script_v2.ps1"

# Verify the script exists
if (-not (Test-Path $scriptPath)) {
    Write-Error "PowerBI-Refresh-Script_v2.ps1 not found at: $scriptPath"
    exit
}

Write-Host "Hourly PowerBI Refresh Loop" -ForegroundColor Cyan
Write-Host "Script: $scriptPath" -ForegroundColor Gray
Write-Host "Schedule: Every hour from 6:00 AM to 8:00 PM" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

while ($true) {
    $currentTime = Get-Date
    $currentHour = $currentTime.Hour
    
    # Check if we're in the active window (6 AM to 8 PM)
    if ($currentHour -ge 6 -and $currentHour -le 20) {
        Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Running PowerBI refresh..." -ForegroundColor Green
        
        try {
            # Capture output and errors
            $output = & $scriptPath 2>&1
            
            # Check if there were any errors
            $hasErrors = $false
            foreach ($line in $output) {
                if ($line -is [System.Management.Automation.ErrorRecord]) {
                    $hasErrors = $true
                    Write-Host "  ERROR: $($line.Exception.Message)" -ForegroundColor Red
                } else {
                    Write-Host "  $line" -ForegroundColor Gray
                }
            }
            
            if ($hasErrors) {
                Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Completed with errors" -ForegroundColor Yellow
            } else {
                Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Completed successfully" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Error: $_" -ForegroundColor Red
            Write-Host "  Full error details:" -ForegroundColor Yellow
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor Gray
        }
        
        # Wait until the next hour
        $nextHour = $currentTime.AddHours(1)
        $nextRun = Get-Date -Year $nextHour.Year -Month $nextHour.Month -Day $nextHour.Day -Hour $nextHour.Hour -Minute 0 -Second 0
        $waitSeconds = ($nextRun - $currentTime).TotalSeconds
        
        Write-Host "`nNext run at: $($nextRun.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
        Write-Host "Waiting $([math]::Round($waitSeconds/60, 1)) minutes...`n" -ForegroundColor Gray
        Write-Host ("=" * 80) -ForegroundColor DarkGray
        
        Start-Sleep -Seconds $waitSeconds
    }
    else {
        # Outside active hours
        if ($currentHour -lt 6) {
            $nextRun = Get-Date -Hour 6 -Minute 0 -Second 0
            Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Outside active hours. Next run at 6:00 AM" -ForegroundColor Yellow
        }
        else {
            $nextRun = (Get-Date).AddDays(1).Date.AddHours(6)
            Write-Host "[$($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))] Outside active hours. Next run tomorrow at 6:00 AM" -ForegroundColor Yellow
        }
        
        $waitSeconds = ($nextRun - $currentTime).TotalSeconds
        Write-Host "Waiting $([math]::Round($waitSeconds/60, 1)) minutes...`n" -ForegroundColor Gray
        Start-Sleep -Seconds $waitSeconds
    }
}
