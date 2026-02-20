#!/bin/bash
# run-hourly.sh
# Runs PowerBI-Refresh-Script_v2.ps1 every hour from 6 AM to 8 PM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERSHELL_SCRIPT="$SCRIPT_DIR/PowerBI-Refresh-Script_v2.ps1"

# Check if script exists
if [ ! -f "$POWERSHELL_SCRIPT" ]; then
    echo "Error: PowerBI-Refresh-Script_v2.ps1 not found at: $POWERSHELL_SCRIPT"
    exit 1
fi

echo "Hourly PowerBI Refresh Loop"
echo "Script: $POWERSHELL_SCRIPT"
echo "Schedule: Every hour from 6:00 AM to 8:00 PM"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    CURRENT_HOUR=$(date +%H)
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if we're in the active window (6 AM to 8 PM)
    if [ "$CURRENT_HOUR" -ge 6 ] && [ "$CURRENT_HOUR" -le 20 ]; then
        echo "[$CURRENT_TIME] Running PowerBI refresh..."
        
        # Run PowerShell script
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$POWERSHELL_SCRIPT"
        
        if [ $? -eq 0 ]; then
            echo "[$CURRENT_TIME] Completed successfully"
        else
            echo "[$CURRENT_TIME] Error occurred"
        fi
        
        # Calculate next run time (top of next hour)
        NEXT_HOUR=$(date -d "+1 hour" '+%Y-%m-%d %H:00:00')
        echo "Next run at: $NEXT_HOUR"
        
        # Wait until next hour
        SECONDS_TO_WAIT=$(( $(date -d "$NEXT_HOUR" +%s) - $(date +%s) ))
        MINUTES_TO_WAIT=$(( SECONDS_TO_WAIT / 60 ))
        echo "Waiting $MINUTES_TO_WAIT minutes..."
        echo ""
        
        sleep $SECONDS_TO_WAIT
    else
        # Outside active hours
        if [ "$CURRENT_HOUR" -lt 6 ]; then
            NEXT_RUN=$(date '+%Y-%m-%d 06:00:00')
            echo "[$CURRENT_TIME] Outside active hours. Next run at 6:00 AM"
        else
            NEXT_RUN=$(date -d "tomorrow 06:00:00" '+%Y-%m-%d %H:%M:%S')
            echo "[$CURRENT_TIME] Outside active hours. Next run tomorrow at 6:00 AM"
        fi
        
        SECONDS_TO_WAIT=$(( $(date -d "$NEXT_RUN" +%s) - $(date +%s) ))
        MINUTES_TO_WAIT=$(( SECONDS_TO_WAIT / 60 ))
        echo "Waiting $MINUTES_TO_WAIT minutes..."
        echo ""
        
        sleep $SECONDS_TO_WAIT
    fi
done
