# Install GraphViz Portable (No Admin Rights Required)
# This script downloads and sets up GraphViz in a local directory

param(
    [string]$InstallPath = "$env:USERPROFILE\Tools\GraphViz"
)

function Install-GraphVizPortable {
    param([string]$InstallPath)
    
    try {
        # Create installation directory
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            Write-Host "Created directory: $InstallPath" -ForegroundColor Green
        }
        
        # GraphViz portable download URL (latest stable version)
        $graphVizUrl = "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/9.0.0/windows_10_cmake_Release_graphviz-install-9.0.0-win64.exe"
        $zipPath = "$InstallPath\graphviz-portable.exe"
        
        Write-Host "Downloading GraphViz portable..." -ForegroundColor Yellow
        
        # Download GraphViz
        try {
            Invoke-WebRequest -Uri $graphVizUrl -OutFile $zipPath -UseBasicParsing
            Write-Host "Downloaded GraphViz to: $zipPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Direct download failed. Trying alternative method..." -ForegroundColor Yellow
            
            # Alternative: Download from GitHub releases
            $altUrl = "https://github.com/xflr6/graphviz/releases/download/0.20.1/graphviz-0.20.1.zip"
            $altZipPath = "$InstallPath\graphviz-alt.zip"
            
            try {
                Invoke-WebRequest -Uri $altUrl -OutFile $altZipPath -UseBasicParsing
                Expand-Archive -Path $altZipPath -DestinationPath $InstallPath -Force
                Remove-Item $altZipPath -Force
                Write-Host "Downloaded and extracted alternative GraphViz" -ForegroundColor Green
            }
            catch {
                throw "Failed to download GraphViz from both sources: $_"
            }
        }
        
        # Manual installation instructions if download fails
        Write-Host "`nAlternative Manual Installation:" -ForegroundColor Cyan
        Write-Host "1. Go to: https://graphviz.org/download/" -ForegroundColor White
        Write-Host "2. Download 'graphviz-X.X.X-win64.exe' (stable release)" -ForegroundColor White
        Write-Host "3. Extract/Install to: $InstallPath" -ForegroundColor White
        Write-Host "4. Ensure dot.exe is in: $InstallPath\bin\dot.exe" -ForegroundColor White
        
        return $InstallPath
    }
    catch {
        Write-Error "Failed to install GraphViz: $_"
        return $null
    }
}

# Install GraphViz
$installLocation = Install-GraphVizPortable -InstallPath $InstallPath

if ($installLocation) {
    Write-Host "`nGraphViz installation completed!" -ForegroundColor Green
    Write-Host "Installation path: $installLocation" -ForegroundColor White
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Add to your PowerShell script: -GraphVizPath '$installLocation\bin\dot.exe'" -ForegroundColor White
    Write-Host "2. Or add to PATH environment variable (user level)" -ForegroundColor White
}