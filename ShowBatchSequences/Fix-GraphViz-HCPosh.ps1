# Fix GraphViz for HCPosh without Admin Rights
# This script provides multiple solutions for GraphViz installation

param(
    [string]$InstallPath = "$env:USERPROFILE\Tools\GraphViz",
    [switch]$UsePortable,
    [switch]$UseScoop,
    [switch]$DownloadOnly
)

function Install-GraphVizPortable {
    param([string]$InstallPath)
    
    Write-Host "Installing GraphViz Portable to: $InstallPath" -ForegroundColor Yellow
    
    # Create installation directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    # Download GraphViz portable zip
    $graphVizUrl = "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/9.0.0/windows_10_cmake_Release_graphviz-install-9.0.0-win64.exe"
    $installerPath = "$InstallPath\graphviz-installer.exe"
    
    try {
        Write-Host "Downloading GraphViz..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $graphVizUrl -OutFile $installerPath -UseBasicParsing
        
        Write-Host "Please run the installer manually and install to: $InstallPath" -ForegroundColor Cyan
        Write-Host "Installer downloaded to: $installerPath" -ForegroundColor White
        
        return $InstallPath
    }
    catch {
        Write-Host "Download failed. Using alternative method..." -ForegroundColor Yellow
        
        # Alternative: Manual download instructions
        Write-Host "`nManual Installation Steps:" -ForegroundColor Cyan
        Write-Host "1. Go to: https://graphviz.org/download/" -ForegroundColor White
        Write-Host "2. Download: 'Stable Windows install packages'" -ForegroundColor White
        Write-Host "3. Choose: graphviz-X.X.X (64-bit) EXE installer" -ForegroundColor White
        Write-Host "4. Install to: $InstallPath" -ForegroundColor White
        Write-Host "5. Make sure dot.exe is in: $InstallPath\bin\dot.exe" -ForegroundColor White
        
        return $InstallPath
    }
}

function Install-GraphVizWithScoop {
    # Check if Scoop is installed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Scoop (user-level package manager)..." -ForegroundColor Yellow
        
        try {
            # Install Scoop
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        }
        catch {
            Write-Error "Failed to install Scoop: $_"
            return $null
        }
    }
    
    try {
        Write-Host "Installing GraphViz with Scoop..." -ForegroundColor Yellow
        
        # Install GraphViz using Scoop
        scoop install graphviz
        
        # Get GraphViz path
        $graphVizPath = "$env:USERPROFILE\scoop\apps\graphviz\current\bin"
        
        Write-Host "GraphViz installed successfully!" -ForegroundColor Green
        return $graphVizPath
    }
    catch {
        Write-Error "Failed to install GraphViz with Scoop: $_"
        return $null
    }
}

function Update-HCPoshScript {
    param([string]$GraphVizPath)
    
    $scriptPath = "ShowBatchSequences\ShowBatchSequences_Snapshots.ps1"
    
    if (Test-Path $scriptPath) {
        Write-Host "Updating your HCPosh script to use GraphViz..." -ForegroundColor Yellow
        
        # Read the current script
        $content = Get-Content $scriptPath -Raw
        
        # Add GraphViz path configuration at the beginning
        $graphVizConfig = @"
# GraphViz Configuration (Added automatically)
`$env:PATH += ";$GraphVizPath"
`$graphVizDotPath = "$GraphVizPath\dot.exe"

# Verify GraphViz is available
if (-not (Test-Path `$graphVizDotPath)) {
    Write-Error "GraphViz dot.exe not found at: `$graphVizDotPath"
    Write-Host "Please ensure GraphViz is installed correctly"
    exit 1
}

Write-Host "Using GraphViz from: `$graphVizDotPath" -ForegroundColor Green

"@
        
        # Insert the configuration after the first comment block
        $updatedContent = $content -replace "(#.*?\r?\n)", "`$1$graphVizConfig"
        
        # Create backup
        Copy-Item $scriptPath "$scriptPath.backup" -Force
        
        # Write updated content
        $updatedContent | Set-Content $scriptPath -Encoding UTF8
        
        Write-Host "Script updated successfully!" -ForegroundColor Green
        Write-Host "Backup created: $scriptPath.backup" -ForegroundColor White
    }
    else {
        Write-Host "Script not found: $scriptPath" -ForegroundColor Red
    }
}

function Test-GraphVizInstallation {
    param([string]$GraphVizPath)
    
    $dotExePath = "$GraphVizPath\dot.exe"
    
    if (Test-Path $dotExePath) {
        try {
            $version = & $dotExePath -V 2>&1
            Write-Host "GraphViz is working! Version: $version" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "GraphViz found but not working: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "GraphViz dot.exe not found at: $dotExePath" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "GraphViz Installation Helper for HCPosh" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta

$graphVizPath = $null

if ($UseScoop) {
    $graphVizPath = Install-GraphVizWithScoop
}
elseif ($UsePortable) {
    $graphVizPath = Install-GraphVizPortable -InstallPath $InstallPath
}
else {
    Write-Host "`nChoose installation method:" -ForegroundColor Cyan
    Write-Host "1. Scoop (Recommended - automatic)" -ForegroundColor White
    Write-Host "2. Portable installation" -ForegroundColor White
    Write-Host "3. Manual download only" -ForegroundColor White
    
    $choice = Read-Host "Enter choice (1-3)"
    
    switch ($choice) {
        "1" { $graphVizPath = Install-GraphVizWithScoop }
        "2" { $graphVizPath = Install-GraphVizPortable -InstallPath $InstallPath }
        "3" { 
            Write-Host "Manual download instructions:" -ForegroundColor Cyan
            Write-Host "1. Visit: https://graphviz.org/download/" -ForegroundColor White
            Write-Host "2. Download Windows installer" -ForegroundColor White
            Write-Host "3. Install to a folder you have write access to" -ForegroundColor White
            Write-Host "4. Note the installation path for next step" -ForegroundColor White
            $graphVizPath = Read-Host "Enter the GraphViz installation path (e.g., C:\Users\YourName\GraphViz\bin)"
        }
        default { 
            Write-Host "Invalid choice. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

if ($graphVizPath) {
    # Test the installation
    if (Test-GraphVizInstallation -GraphVizPath $graphVizPath) {
        # Update the HCPosh script
        Update-HCPoshScript -GraphVizPath $graphVizPath
        
        Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
        Write-Host "GraphViz path: $graphVizPath" -ForegroundColor White
        Write-Host "Your HCPosh script has been updated to use GraphViz" -ForegroundColor White
    }
    else {
        Write-Host "Installation verification failed. Please check the GraphViz installation." -ForegroundColor Red
    }
}
else {
    Write-Host "Installation failed or was cancelled." -ForegroundColor Red
}