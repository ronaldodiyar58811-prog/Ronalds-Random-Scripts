# Install GraphViz using Chocolatey (User-level, no admin required)

function Install-ChocolateyUser {
    # Check if Chocolatey is already installed
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed" -ForegroundColor Green
        return $true
    }
    
    try {
        Write-Host "Installing Chocolatey (user-level)..." -ForegroundColor Yellow
        
        # Set execution policy for current user
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        # Install Chocolatey for current user only
        $env:ChocolateyInstall = "$env:USERPROFILE\chocolatey"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Add to PATH for current session
        $env:PATH += ";$env:USERPROFILE\chocolatey\bin"
        
        Write-Host "Chocolatey installed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to install Chocolatey: $_"
        return $false
    }
}

function Install-GraphVizWithChocolatey {
    if (Install-ChocolateyUser) {
        try {
            Write-Host "Installing GraphViz with Chocolatey..." -ForegroundColor Yellow
            
            # Install GraphViz using Chocolatey
            & choco install graphviz --user -y
            
            # Add GraphViz to user PATH
            $graphVizPath = "$env:USERPROFILE\chocolatey\lib\Graphviz\tools\bin"
            if (Test-Path $graphVizPath) {
                $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                if ($userPath -notlike "*$graphVizPath*") {
                    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$graphVizPath", "User")
                    $env:PATH += ";$graphVizPath"
                    Write-Host "Added GraphViz to user PATH" -ForegroundColor Green
                }
            }
            
            Write-Host "GraphViz installed successfully!" -ForegroundColor Green
            return $graphVizPath
        }
        catch {
            Write-Error "Failed to install GraphViz with Chocolatey: $_"
            return $null
        }
    }
    return $null
}

# Install GraphViz
$graphVizPath = Install-GraphVizWithChocolatey

if ($graphVizPath) {
    Write-Host "`nInstallation completed!" -ForegroundColor Green
    Write-Host "GraphViz path: $graphVizPath" -ForegroundColor White
    Write-Host "Restart PowerShell to use GraphViz commands" -ForegroundColor Yellow
}