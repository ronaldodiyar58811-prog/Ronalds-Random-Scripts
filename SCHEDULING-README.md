# PowerBI Refresh Scheduling Options

This folder contains three different options for running `PowerBI-Refresh-Script_v2.ps1` every hour from 6 AM to 8 PM.

## Option 1: Windows Task Scheduler (RECOMMENDED)

**Best for:** Production use, runs in background, survives reboots

### Setup:
1. Right-click PowerShell and select "Run as Administrator"
2. Navigate to this folder
3. Run: `.\Setup-HourlyScheduledTask.ps1`

### Features:
- ✅ Runs automatically even if you're not logged in
- ✅ Survives computer restarts
- ✅ Runs in background (no window)
- ✅ Easy to manage via Task Scheduler GUI

### Manage:
- **View/Edit:** Open Task Scheduler (`taskschd.msc`) and look for "PowerBI Refresh - Hourly 6AM-8PM"
- **Remove:** Run `Unregister-ScheduledTask -TaskName "PowerBI Refresh - Hourly 6AM-8PM" -Confirm:$false`

---

## Option 2: PowerShell Loop Script

**Best for:** Testing, temporary use, when you want to see output

### Setup:
1. Open PowerShell (no admin needed)
2. Navigate to this folder
3. Run: `.\Run-HourlyLoop.ps1`
4. Keep the PowerShell window open

### Features:
- ✅ See real-time output
- ✅ Easy to stop (Ctrl+C)
- ✅ No admin privileges required
- ❌ Stops when you close the window
- ❌ Stops when computer restarts

---

## Option 3: Bash Script (WSL/Git Bash)

**Best for:** If you prefer bash or use WSL/Git Bash

### Setup:
1. Make executable: `chmod +x run-hourly.sh`
2. Run: `./run-hourly.sh`
3. Keep the terminal window open

### Features:
- ✅ Works in WSL, Git Bash, or Cygwin
- ✅ See real-time output
- ✅ Easy to stop (Ctrl+C)
- ❌ Stops when you close the window
- ❌ Stops when computer restarts

---

## Schedule Details

All options run the script:
- **Start:** 6:00 AM
- **End:** 8:00 PM (last run at 8:00 PM)
- **Frequency:** Every hour on the hour
- **Total runs per day:** 15 times (6 AM, 7 AM, 8 AM, ..., 7 PM, 8 PM)

---

## Troubleshooting

### "Execution Policy" Error
Run this in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script Not Found
Make sure all scripts are in the same folder as `PowerBI-Refresh-Script_v2.ps1`

### Task Scheduler Not Running
1. Open Task Scheduler (`taskschd.msc`)
2. Find "PowerBI Refresh - Hourly 6AM-8PM"
3. Right-click → Properties
4. Check "Run whether user is logged on or not"
5. Enter your password when prompted

### View Task History
1. Open Task Scheduler
2. Find the task
3. Click "History" tab at the bottom

---

## Recommendation

For production use, **Option 1 (Task Scheduler)** is recommended because:
- It runs reliably in the background
- Survives reboots and logoffs
- Can be monitored via Task Scheduler
- Logs execution history

For testing or one-time use, **Option 2 (PowerShell Loop)** is easier to set up and provides immediate feedback.
