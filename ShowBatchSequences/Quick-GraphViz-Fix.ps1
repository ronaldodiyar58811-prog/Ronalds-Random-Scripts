# Quick GraphViz Fix - Add this to the beginning of your ShowBatchSequences script

# Download and setup GraphViz portable (no admin required)
$graphVizPath = "$env:USERPROFILE\Tools\GraphViz"
$dotExePath = "$graphVizPath\bin\dot.exe"

if (-not (Test-Path $dotExePath)) {
    Write-Host "Setting up GraphViz..." -ForegroundColor Yellow
    
    # Create directory
    New-Item -ItemType Directory -Path $graphVizPath -Force | Out-Null
    
    # Download GraphViz portable
    $zipUrl = "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/8.1.0/windows_10_cmake_Release_graphviz-install-8.1.0-win64.exe"
    $zipPath = "$graphVizPath\graphviz.exe"
    
    try {
        Write-Host "Downloading GraphViz..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        
        Write-Host "Please manually extract/install GraphViz to: $graphVizPath" -ForegroundColor Cyan
        Write-Host "Make sure dot.exe ends up at: $dotExePath" -ForegroundColor White
        
        # Wait for user to complete installation
        Read-Host "Press Enter after you've completed the GraphViz installation"
    }
    catch {
        Write-Host "Automatic download failed. Please manually install GraphViz:" -ForegroundColor Red
        Write-Host "1. Go to: https://graphviz.org/download/" -ForegroundColor White
        Write-Host "2. Download Windows installer" -ForegroundColor White
        Write-Host "3. Install to: $graphVizPath" -ForegroundColor White
        Write-Host "4. Ensure dot.exe is at: $dotExePath" -ForegroundColor White
        
        Read-Host "Press Enter after installation is complete"
    }
}

# Add GraphViz to PATH for current session
if (Test-Path $dotExePath) {
    $env:PATH += ";$graphVizPath\bin"
    Write-Host "GraphViz is ready!" -ForegroundColor Green
} else {
    Write-Error "GraphViz installation not found. Please install GraphViz manually."
    exit 1
}

Write-Host "You can now run your HCPosh commands!" -ForegroundColor Green