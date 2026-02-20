# Fix HCPosh GraphViz Path Issue
# This script copies GraphViz to where HCPosh expects it

param(
    [string]$SourceGraphVizPath = "C:\Users\58811.WMCDOMAIN\scoop\apps\graphviz\current\bin\dot.exe"
)

Write-Host "Fixing HCPosh GraphViz Path Issue..." -ForegroundColor Yellow

# Check if source GraphViz exists
if (-not (Test-Path $SourceGraphVizPath)) {
    # Try to find GraphViz in common locations
    $possiblePaths = @(
        "C:\Users\58811.WMCDOMAIN\scoop\apps\graphviz\current\bin\dot.exe",
        "$env:USERPROFILE\scoop\apps\graphviz\current\bin\dot.exe",
        "$env:USERPROFILE\Tools\GraphViz\bin\dot.exe",
        "C:\Program Files\Graphviz\bin\dot.exe",
        "C:\Program Files (x86)\Graphviz\bin\dot.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $SourceGraphVizPath = $path
            Write-Host "Found GraphViz at: $SourceGraphVizPath" -ForegroundColor Green
            break
        }
    }
    
    if (-not (Test-Path $SourceGraphVizPath)) {
        Write-Error "GraphViz not found in any standard locations. Please install GraphViz first."
        exit 1
    }
}

# Define HCPosh expected path
$hcposhModulePath = "$env:USERPROFILE\OneDrive - Renown Health\Documents\WindowsPowerShell\Modules\HCPosh\3.0.17.0"
$hcposhGraphVizDir = "$hcposhModulePath\graphviz"
$hcposhDotPath = "$hcposhGraphVizDir\dot.exe"

Write-Host "Source GraphViz: $SourceGraphVizPath" -ForegroundColor White
Write-Host "Target HCPosh location: $hcposhDotPath" -ForegroundColor White

try {
    # Create the graphviz directory in HCPosh module if it doesn't exist
    if (-not (Test-Path $hcposhGraphVizDir)) {
        New-Item -ItemType Directory -Path $hcposhGraphVizDir -Force | Out-Null
        Write-Host "Created directory: $hcposhGraphVizDir" -ForegroundColor Green
    }
    
    # Copy dot.exe to HCPosh expected location
    Copy-Item $SourceGraphVizPath $hcposhDotPath -Force
    Write-Host "Copied GraphViz to HCPosh location successfully!" -ForegroundColor Green
    
    # Also copy any required DLL files from the GraphViz bin directory
    $sourceDir = Split-Path $SourceGraphVizPath -Parent
    $dllFiles = Get-ChildItem "$sourceDir\*.dll" -ErrorAction SilentlyContinue
    
    if ($dllFiles) {
        foreach ($dll in $dllFiles) {
            Copy-Item $dll.FullName $hcposhGraphVizDir -Force
            Write-Host "Copied: $($dll.Name)" -ForegroundColor Gray
        }
    }
    
    # Test the installation
    if (Test-Path $hcposhDotPath) {
        try {
            $version = & $hcposhDotPath -V 2>&1
            Write-Host "GraphViz test successful! Version: $version" -ForegroundColor Green
            
            Write-Host "`n✅ HCPosh GraphViz configuration completed!" -ForegroundColor Green
            Write-Host "You can now run your ShowBatchSequences script successfully." -ForegroundColor White
        }
        catch {
            Write-Host "GraphViz copied but may need additional configuration: $_" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Error "Failed to copy GraphViz to HCPosh location: $_"
    
    # Alternative solution
    Write-Host "`nAlternative solution:" -ForegroundColor Cyan
    Write-Host "1. Open PowerShell as Administrator" -ForegroundColor White
    Write-Host "2. Run: New-Item -ItemType SymbolicLink -Path '$hcposhDotPath' -Target '$SourceGraphVizPath'" -ForegroundColor White
    Write-Host "3. This creates a symbolic link instead of copying the file" -ForegroundColor White
}

Write-Host "`nScript completed." -ForegroundColor Green