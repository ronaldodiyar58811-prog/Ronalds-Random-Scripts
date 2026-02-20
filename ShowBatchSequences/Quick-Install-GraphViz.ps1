# Quick GraphViz Installation for HCPosh
# Run this script to install GraphViz without admin rights

param(
    [string]$InstallPath = "$env:USERPROFILE\Tools\GraphViz"
)

Write-Host "Installing GraphViz for HCPosh..." -ForegroundColor Yellow

# Create installation directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "Created directory: $InstallPath" -ForegroundColor Green
}

# Method 1: Try Scoop (easiest)
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop package manager..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        # Refresh environment
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        
        Write-Host "Scoop installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Scoop installation failed, trying manual method..." -ForegroundColor Yellow
    }
}

# Install GraphViz with Scoop
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    try {
        Write-Host "Installing GraphViz with Scoop..." -ForegroundColor Yellow
        scoop install graphviz
        
        $scoopGraphVizPath = "$env:USERPROFILE\scoop\apps\graphviz\current\bin\dot.exe"
        if (Test-Path $scoopGraphVizPath) {
            Write-Host "GraphViz installed successfully with Scoop!" -ForegroundColor Green
            Write-Host "GraphViz location: $scoopGraphVizPath" -ForegroundColor White
            
            # Test GraphViz
            try {
                $version = & $scoopGraphVizPath -V 2>&1
                Write-Host "GraphViz version: $version" -ForegroundColor Green
                
                Write-Host "`nGraphViz is ready! You can now run your HCPosh script." -ForegroundColor Green
                exit 0
            }
            catch {
                Write-Host "GraphViz installed but not working properly: $_" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Scoop GraphViz installation failed: $_" -ForegroundColor Red
    }
}

# Method 2: Manual download
Write-Host "`nTrying manual download method..." -ForegroundColor Yellow

$downloadUrl = "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/9.0.0/windows_10_cmake_Release_graphviz-install-9.0.0-win64.exe"
$installerPath = "$InstallPath\graphviz-installer.exe"

try {
    Write-Host "Downloading GraphViz installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    
    Write-Host "GraphViz installer downloaded to: $installerPath" -ForegroundColor Green
    Write-Host "`nPlease follow these steps:" -ForegroundColor Cyan
    Write-Host "1. Run the installer: $installerPath" -ForegroundColor White
    Write-Host "2. Install to: $InstallPath" -ForegroundColor White
    Write-Host "3. Make sure 'Add to PATH' is checked during installation" -ForegroundColor White
    Write-Host "4. After installation, restart PowerShell and run your script again" -ForegroundColor White
    
    # Open the installer
    Start-Process -FilePath $installerPath -Wait
    
    # Check if installation was successful
    $dotExePath = "$InstallPath\bin\dot.exe"
    if (Test-Path $dotExePath) {
        Write-Host "`nGraphViz installed successfully!" -ForegroundColor Green
        
        # Test GraphViz
        try {
            $version = & $dotExePath -V 2>&1
            Write-Host "GraphViz version: $version" -ForegroundColor Green
        }
        catch {
            Write-Host "GraphViz installed but may need PATH configuration" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`nGraphViz installation may not be complete." -ForegroundColor Yellow
        Write-Host "Please ensure dot.exe is installed at: $dotExePath" -ForegroundColor White
    }
}
catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    Write-Host "`nManual installation required:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://graphviz.org/download/" -ForegroundColor White
    Write-Host "2. Download 'Stable Windows install packages'" -ForegroundColor White
    Write-Host "3. Choose the 64-bit EXE installer" -ForegroundColor White
    Write-Host "4. Install to: $InstallPath" -ForegroundColor White
    Write-Host "5. Make sure to add GraphViz to your PATH during installation" -ForegroundColor White
}

Write-Host "`nInstallation process completed. Please restart PowerShell and try your script again." -ForegroundColor Green