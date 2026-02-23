        
# GraphViz Setup for HCPosh (No Admin Rights Required)
function Initialize-GraphViz {
    $possiblePaths = @(
        'C:\Users\58811.WMCDOMAIN\Tools\GraphViz\bin\dot.exe',
        "$env:USERPROFILE\Tools\GraphViz\bin\dot.exe",
        "$env:USERPROFILE\scoop\apps\graphviz\current\bin\dot.exe",
        "$env:USERPROFILE\chocolatey\lib\Graphviz\tools\bin\dot.exe",
        "C:\Program Files\Graphviz\bin\dot.exe",
        "C:\Program Files (x86)\Graphviz\bin\dot.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $graphVizDir = Split-Path $path -Parent
            $env:PATH += ";$graphVizDir"
            Write-Host "GraphViz found and configured: $path" -ForegroundColor Green
            
            # Also set GRAPHVIZ_DOT environment variable for HCPosh
            $env:GRAPHVIZ_DOT = $path
            
            return $path
        }
    }
    
    # Check if GraphViz is already in PATH
    $dotInPath = Get-Command dot -ErrorAction SilentlyContinue
    if ($dotInPath) {
        Write-Host "GraphViz found in PATH: $($dotInPath.Source)" -ForegroundColor Green
        $env:GRAPHVIZ_DOT = $dotInPath.Source
        return $dotInPath.Source
    }
    
    # If not found, provide installation guidance
    Write-Warning "GraphViz not found in any standard locations"
    Write-Host "To install GraphViz without admin rights:" -ForegroundColor Yellow
    Write-Host "1. Run: .\Install-GraphViz-Portable.ps1" -ForegroundColor White
    Write-Host "2. Or manually download from: https://graphviz.org/download/" -ForegroundColor White
    Write-Host "3. Install to: $env:USERPROFILE\Tools\GraphViz" -ForegroundColor White
    
    # Try to download and install automatically
    Write-Host "Attempting automatic GraphViz setup..." -ForegroundColor Yellow
    $autoInstallPath = "$env:USERPROFILE\Tools\GraphViz"
    
    try {
        if (-not (Test-Path $autoInstallPath)) {
            New-Item -ItemType Directory -Path $autoInstallPath -Force | Out-Null
        }
        
        Write-Host "Please install GraphViz manually to continue." -ForegroundColor Red
        Write-Host "The script will exit now. Re-run after GraphViz installation." -ForegroundColor Red
        exit 1
    }
    catch {
        Write-Error "Failed to setup GraphViz: $_"
        exit 1
    }
    
    return $null
}

# Setup GraphViz
$graphVizPath = Initialize-GraphViz

function remove-old_files {
    param(
        [string]$folder_path
        ,[string]$file_pattern
        ,[int]$days_to_keep_files
    )

    $limit = (Get-Date).AddDays(-$days_to_keep_files)
    $files_to_remove = get-childitem -File -path $folder_path -Filter $file_pattern | Where-Object { $_.CreationTime -lt $limit }
    foreach($file in $files_to_remove){
        write-outputlog "Removing old file: $file"
        $file | remove-item
    }

}

function write-outputlog {
    [CmdletBinding()]
    param
    (
        [parameter (Mandatory=$false)][string] $message
    )
    $d = get-date
    write-host "$d $message"
    if([string]::IsNullOrEmpty($global:runlogpath)){
        #$global:runlogpath is empty, do nothing
    } else {
        "$d $message" | out-file -append -filepath $global:runlogpath
    }
    
}

        #Relative Path Variables
        $tab = "".PadLeft(4)
        $crlf = "`r`n"
        
        #$ServerCD = $env:COMPUTERNAME.ToUpper()
		#$ServerCD = $ServerCD.Substring(0,$ServerCD.IndexOf('-'))
        $ServerCD = 'RHNV'
		$ProdServerCD = $ServerCD + "-EDWPROD.RHNV.HOSTED"
		$DevServerCD = $ServerCD + "-EDWDEV.RHNV.HOSTED"
		$devExist = $false

        #$directorypath = "\\"+$ProdServerCD+"\Staging\Powershell\ShowBatchSequences"
        $directorypath = "C:\Users\58811.WMCDOMAIN\OneDrive - Renown Health\Documents\Work\Repos and Workspaces\Ronalds-Random-Scripts\ShowBatchSequences"

		# Check if SQL Server exists
		Try {
			 $connectionTest = Test-NetConnection -ComputerName $DevServerCD -Port 1433 -ErrorAction Stop

			if ($connectionTest.TcpTestSucceeded) {
				Write-Output "SQL Server '$DevServerCD' exists. Will update BatchSequencing there too"
				$devExist = $true
			}
		}
		catch {
			Write-Output "SQL Server '$DevServerCD' does not exist, so skipping dev runs."
		}
        try
        {
            HCPosh -Version | Out-Null
        }
        catch
        {
            try{
                Install-Module HCPosh -Scope CurrentUser -Force
            }catch{
                Write-Host "You need to install HCPosh"
            }
        }    

        #Get-Date / Timestamp for archiving snapshots: day, hour, or minute intervals depending on format specified
        $CreationTimeStampDTS = Get-Date -Format "yyyyMMdd_HHmm"
        
        # Commennting out the "EDX" diagram as it is not typically helpful for end users
        #$SqlFileNames = "BatchSequenceDetail-IDEA","BatchSequenceDetail-EDX"
        $SqlFileNames = "BatchSequenceDetail-IDEA"
        
		if ($devExist) { 
			$Servers = $DevServerCD, $ProdServerCD
		}
		else
		{
			$Servers = $ProdServerCD
		}
		
        New-Item "$directorypath\GraphViz\" -type directory -Force | Out-Null
        
        foreach ($Server in $Servers) {

            foreach ($SqlFileName in $SqlFileNames) {

                $sqlFilePath="$($directorypath)\SQL\$($sqlFileName).sql"
                Write-Host "Directory Path $directorypath"
           
                 if(!(Test-Path $sqlFilePath))
                {
                    Write-Host "Unable to find the $sqlFilePath"
                    break;
                }
                $sql = Get-Content $sqlFilePath| Out-String
                $graphname = "Batch Sequencing - " + $server.replace('.RHNV.HOSTED','')        

                Write-Host ""
                Write-Host "Querying ETLSequencedBatches on $server..."
                
                # Execute SQL query with SSL certificate handling
                try {
                    $output = Invoke-Sqlcmd -ServerInstance $server -Query $sql -TrustServerCertificate -ErrorAction Stop
                }
                catch {
                    Write-Host "Failed with TrustServerCertificate. Trying with Encrypt=False..." -ForegroundColor Yellow
                    try {
                        $connectionString = "Server=$server;Database=master;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
                        $output = Invoke-Sqlcmd -ConnectionString $connectionString -Query $sql -ErrorAction Stop
                    }
                    catch {
                        Write-Error "All SQL connection attempts failed: $_"
                        throw
                    }
                }

                $digraph = "digraph `"" + $graphname + "`"" + "{" + $crlf
                $graph = $tab + "graph [layout=dot, fontname=Arial, fontsize=10, labelloc=t, label=<<b>" + $graphname + "</b><br />Click on an arrowhead to get more information<br /> >];" + $crlf
                $node = $tab + "node [shape=none, margin=0, fontname=Arial, fontsize=8];" + $crlf
               # $nodetimeline =$tab +"node [shape=plaintext, fontsize=16];"+ $crlf+"/* the time-line graph */"+
               # "`"Not Scheduled`" -> 12 am`" -> `"1 am`" -> `"2 am`" -> `"3 am`" -> `"4 am`" -> `"5 am`" -> `"6 am`" -> `"7 am`" -> `"8 am`" -> `"9 am`" -> `"10 am`" -> `"11 am`" -> `"12 pm`" -> `"1 pm`" -> `"2 pm`" -> `"3 pm`" -> `"4 pm`" -> `"5 pm`" -> `"6 pm`" -> `"7 pm`" -> `"8 pm`" -> `"9 pm`" -> `"10 pm`" -> `"11 pm`"" + $crlf
   
                $labels = $output.SegmentLabel | Where-Object { $_ } | ForEach-Object { $tab + $_ + $crlf } # Where-Object {$_} - clears out empty array values
                $arrows = $output.SegmentDisplay | Where-Object { $_ } | ForEach-Object { $tab + $_ + $crlf }

                $combine = "$($digraph +
                    $graph +
                    $node +
                    $labels + $crlf +
                    $arrows + "}")"
   
                #Commented out the "LR" - Left to Right Versions of the file as these are genernally not used
                Write-Host "Creating GraphViz file..."
                $combine | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server).gv" -Force -Encoding ascii

				## Create Files with Timestamps for Archving Purposes
				$combine | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_$($CreationTimeStampDTS).gv" -Force -Encoding ascii
                
                # Extract batches that didn't run today and their parent nodes
                Write-Host "Identifying batches that did not run today..."
                Write-Host "DEBUG: Checking $($output.Count) rows from SQL output" -ForegroundColor Magenta
                $batchesNotRun = @()
                $batchesNotRunWithParents = @()
                
                # Build a map of node relationships from arrows
                $nodeRelationships = @{}
                foreach ($row in $output) {
                    if ($row.SegmentDisplay -match '"([^"]+)"\s*->\s*"([^"]+)"') {
                        $fromNode = $matches[1]
                        $toNode = $matches[2]
                        if (-not $nodeRelationships.ContainsKey($toNode)) {
                            $nodeRelationships[$toNode] = @()
                        }
                        $nodeRelationships[$toNode] += $fromNode
                    }
                }
                
                # Debug: Show first few SegmentLabels to understand the format
                $debugCount = 0
                $debugNotRunCount = 0
                foreach ($row in $output) {
                    if ($row.SegmentLabel) {
                        if ($debugCount -lt 3) {
                            Write-Host "DEBUG: Sample SegmentLabel: $($row.SegmentLabel.Substring(0, [Math]::Min(200, $row.SegmentLabel.Length)))" -ForegroundColor Magenta
                            $debugCount++
                        }
                        if ($row.SegmentLabel -match '(?i)did not run' -and $debugNotRunCount -lt 3) {
                            Write-Host "DEBUG: Found 'did not run' in: $($row.SegmentLabel)" -ForegroundColor Yellow
                            $debugNotRunCount++
                        }
                    }
                }
                Write-Host "DEBUG: Found $debugNotRunCount labels containing 'did not run'" -ForegroundColor Magenta
                
                # Find batches that didn't run - using simple string contains instead of regex
                foreach ($row in $output) {
                    if ($row.SegmentLabel -and $row.SegmentLabel.Contains('Did not run today')) {
                        # Extract the batch name from the beginning of the label (between first pair of quotes)
                        if ($row.SegmentLabel -match '^"([^"]+)"') {
                            $batchName = $matches[1]
                            Write-Host "DEBUG: Extracted batch name: '$batchName'" -ForegroundColor Cyan
                            if ($batchName -and $batchesNotRun -notcontains $batchName) {
                                $batchesNotRun += $batchName
                                $batchesNotRunWithParents += $batchName
                                Write-Host "  Batch did not run today: $batchName" -ForegroundColor Yellow
                                
                                # Add parent nodes (1 level up)
                                if ($nodeRelationships.ContainsKey($batchName)) {
                                    foreach ($parent in $nodeRelationships[$batchName]) {
                                        if ($batchesNotRunWithParents -notcontains $parent) {
                                            $batchesNotRunWithParents += $parent
                                            Write-Host "    Including parent: $parent" -ForegroundColor Cyan
                                        }
                                    }
                                }
                            } else {
                                Write-Host "DEBUG: Skipping duplicate or empty batch name: '$batchName'" -ForegroundColor Gray
                            }
                        } else {
                            Write-Host "DEBUG: Could not extract batch name from: $($row.SegmentLabel.Substring(0, [Math]::Min(100, $row.SegmentLabel.Length)))" -ForegroundColor Red
                        }
                    }
                }
                
                Write-Host "DEBUG: Total unique batches that did not run: $($batchesNotRun.Count)" -ForegroundColor Magenta
                Write-Host "DEBUG: Total nodes to show (including parents): $($batchesNotRunWithParents.Count)" -ForegroundColor Magenta
                
                if ($batchesNotRun.Count -eq 0) {
                    Write-Host "  All batches ran successfully today!" -ForegroundColor Green
                } else {
                    Write-Host "  Total batches that did not run: $($batchesNotRun.Count)" -ForegroundColor Yellow
                    
                    # Create filtered GraphViz file with only nodes that didn't run (and their parents)
                    Write-Host "Creating filtered GraphViz file for batches that did not run..."
                    
                    $filteredLabels = @()
                    $filteredArrows = @()
                    
                    # Filter labels to only include nodes that didn't run or their parents
                    foreach ($row in $output) {
                        if ($row.SegmentLabel -match '"([^"]+)"') {
                            $nodeName = $matches[1]
                            if ($batchesNotRunWithParents -contains $nodeName) {
                                $filteredLabels += $tab + $row.SegmentLabel + $crlf
                            }
                        }
                    }
                    
                    # Filter arrows to only include connections between visible nodes
                    foreach ($row in $output) {
                        if ($row.SegmentDisplay -match '"([^"]+)"\s*->\s*"([^"]+)"') {
                            $fromNode = $matches[1]
                            $toNode = $matches[2]
                            if (($batchesNotRunWithParents -contains $fromNode) -and ($batchesNotRunWithParents -contains $toNode)) {
                                $filteredArrows += $tab + $row.SegmentDisplay + $crlf
                            }
                        }
                    }
                    
                    $graphFiltered = $tab + "graph [layout=dot, fontname=Arial, fontsize=10, labelloc=t, label=<<b>" + $graphname + " - Did Not Run Today</b><br />Showing only batches that did not run and their parent nodes<br /> >];" + $crlf
                    
                    $combineFiltered = "$($digraph +
                        $graphFiltered +
                        $node +
                        $filteredLabels + $crlf +
                        $filteredArrows + "}")"
                    
                    $combineFiltered | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_NotRun.gv" -Force -Encoding ascii
                    Write-Host "  Filtered GraphViz file created" -ForegroundColor Green
                }
                
                # Create Broken References filter
                Write-Host "Identifying nodes with broken references..."
                $brokenReferences = @()
                $brokenReferencesWithParents = @()
                
                # Find nodes with "Broken References" attribute
                foreach ($row in $output) {
                    if ($row.SegmentLabel -and $row.SegmentLabel.Contains('data-cell-info="Broken References"')) {
                        if ($row.SegmentLabel -match '^"([^"]+)"') {
                            $nodeName = $matches[1]
                            if ($nodeName -and $brokenReferences -notcontains $nodeName) {
                                $brokenReferences += $nodeName
                                $brokenReferencesWithParents += $nodeName
                                Write-Host "  Node with broken references: $nodeName" -ForegroundColor Yellow
                                
                                # Add parent nodes (1 level up)
                                if ($nodeRelationships.ContainsKey($nodeName)) {
                                    foreach ($parent in $nodeRelationships[$nodeName]) {
                                        if ($brokenReferencesWithParents -notcontains $parent) {
                                            $brokenReferencesWithParents += $parent
                                            Write-Host "    Including parent: $parent" -ForegroundColor Cyan
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                if ($brokenReferences.Count -eq 0) {
                    Write-Host "  No broken references found!" -ForegroundColor Green
                } else {
                    Write-Host "  Total nodes with broken references: $($brokenReferences.Count)" -ForegroundColor Yellow
                    
                    # Create filtered GraphViz file with only broken reference nodes (and their parents)
                    Write-Host "Creating filtered GraphViz file for broken references..."
                    
                    $filteredLabelsBroken = @()
                    $filteredArrowsBroken = @()
                    
                    # Filter labels to only include broken reference nodes or their parents
                    foreach ($row in $output) {
                        if ($row.SegmentLabel -match '^"([^"]+)"') {
                            $nodeName = $matches[1]
                            if ($brokenReferencesWithParents -contains $nodeName) {
                                $filteredLabelsBroken += $tab + $row.SegmentLabel + $crlf
                            }
                        }
                    }
                    
                    # Filter arrows to only include connections between visible nodes
                    foreach ($row in $output) {
                        if ($row.SegmentDisplay -match '"([^"]+)"\s*->\s*"([^"]+)"') {
                            $fromNode = $matches[1]
                            $toNode = $matches[2]
                            if (($brokenReferencesWithParents -contains $fromNode) -and ($brokenReferencesWithParents -contains $toNode)) {
                                $filteredArrowsBroken += $tab + $row.SegmentDisplay + $crlf
                            }
                        }
                    }
                    
                    $graphFilteredBroken = $tab + "graph [layout=dot, fontname=Arial, fontsize=10, labelloc=t, label=<<b>" + $graphname + " - Broken References</b><br />Showing only nodes with broken references and their parent nodes<br /> >];" + $crlf
                    
                    $combineFilteredBroken = "$($digraph +
                        $graphFilteredBroken +
                        $node +
                        $filteredLabelsBroken + $crlf +
                        $filteredArrowsBroken + "}")"
                    
                    $combineFilteredBroken | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_BrokenRefs.gv" -Force -Encoding ascii
                    Write-Host "  Filtered GraphViz file for broken references created" -ForegroundColor Green
                }

                Write-Host "Creating diagram...$($sqlFileName)_$($server)"
                
                # Configure HCPosh to use the correct GraphViz path
                $svgContent = $null
                $svgContentFiltered = $null
                $svgContentBroken = $null
                $svgOutputFile = "$directorypath\Diagrams\$($sqlFileName)_$($server).svg"
                $svgOutputFileFiltered = "$directorypath\Diagrams\$($sqlFileName)_$($server)_NotRun.svg"
                $svgOutputFileBroken = "$directorypath\Diagrams\$($sqlFileName)_$($server)_BrokenRefs.svg"
                $svgGenerated = $false
                $svgFilteredGenerated = $false
                $svgBrokenGenerated = $false
                
                # Function to generate SVG from GraphViz file
                function New-SVGFromGraphViz {
                    param($inputGvFile, $outputSvgFile)
                    
                    $generated = $false
                    
                    if ($graphVizPath -and (Test-Path $graphVizPath)) {
                        # Try direct GraphViz execution (most reliable)
                        try {
                            Write-Host "  Generating SVG: $outputSvgFile" -ForegroundColor Cyan
                            
                            # Ensure output directory exists
                            $outputDir = Split-Path $outputSvgFile -Parent
                            if (-not (Test-Path $outputDir)) {
                                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                            }
                            
                            # Run GraphViz directly
                            & $graphVizPath -Tsvg "$inputGvFile" -o "$outputSvgFile" 2>&1 | Out-Null
                            Start-Sleep -Milliseconds 500
                            
                            if (Test-Path $outputSvgFile) {
                                # Remove white background from SVG
                                $svgContent = Get-Content $outputSvgFile -Raw
                                
                                # Remove the white polygon background that GraphViz adds
                                $svgContent = $svgContent -replace '<polygon fill="white"[^>]*></polygon>', ''
                                $svgContent = $svgContent -replace '<polygon fill="#ffffff"[^>]*></polygon>', ''
                                
                                # Also remove any white rect backgrounds
                                $svgContent = $svgContent -replace '<rect fill="white"[^>]*></rect>', ''
                                $svgContent = $svgContent -replace '<rect fill="#ffffff"[^>]*></rect>', ''
                                
                                # Save the modified SVG
                                $svgContent | Out-File $outputSvgFile -Force -Encoding UTF8
                                
                                $generated = $true
                                Write-Host "  SVG generated successfully (background removed)" -ForegroundColor Green
                            }
                        }
                        catch {
                            Write-Warning "  GraphViz execution failed: $_"
                        }
                    }
                    
                    return $generated
                }
                
                # Generate main SVG (all nodes)
                $svgGenerated = New-SVGFromGraphViz "$directorypath\GraphViz\$($sqlFileName)_$($server).gv" $svgOutputFile
                
                # Generate filtered SVG (only nodes that didn't run) if the file exists
                if (Test-Path "$directorypath\GraphViz\$($sqlFileName)_$($server)_NotRun.gv") {
                    $svgFilteredGenerated = New-SVGFromGraphViz "$directorypath\GraphViz\$($sqlFileName)_$($server)_NotRun.gv" $svgOutputFileFiltered
                }
                
                # Generate broken references SVG if the file exists
                if (Test-Path "$directorypath\GraphViz\$($sqlFileName)_$($server)_BrokenRefs.gv") {
                    $svgBrokenGenerated = New-SVGFromGraphViz "$directorypath\GraphViz\$($sqlFileName)_$($server)_BrokenRefs.gv" $svgOutputFileBroken
                }
                
                # Read SVG contents
                if ($svgGenerated -and (Test-Path $svgOutputFile)) {
                    $svgContent = Get-Content $svgOutputFile -Raw
                    Write-Host "Main SVG content loaded ($($svgContent.Length) characters)" -ForegroundColor Green
                } else {
                    Write-Warning "Main SVG file was not created: $svgOutputFile"
                }
                
                if ($svgFilteredGenerated -and (Test-Path $svgOutputFileFiltered)) {
                    $svgContentFiltered = Get-Content $svgOutputFileFiltered -Raw
                    Write-Host "Filtered SVG content loaded ($($svgContentFiltered.Length) characters)" -ForegroundColor Green
                } else {
                    Write-Host "Filtered SVG not created - checking if filtered GraphViz file exists..." -ForegroundColor Yellow
                    if (Test-Path "$directorypath\GraphViz\$($sqlFileName)_$($server)_NotRun.gv") {
                        Write-Warning "Filtered GraphViz file exists but SVG generation failed"
                    } else {
                        Write-Host "No filtered GraphViz file (all batches may have run successfully)" -ForegroundColor Green
                    }
                    $svgContentFiltered = $null
                }
                
                if ($svgBrokenGenerated -and (Test-Path $svgOutputFileBroken)) {
                    $svgContentBroken = Get-Content $svgOutputFileBroken -Raw
                    Write-Host "Broken references SVG content loaded ($($svgContentBroken.Length) characters)" -ForegroundColor Green
                } else {
                    Write-Host "Broken references SVG not created" -ForegroundColor Yellow
                    $svgContentBroken = $null
                }
                
                # Create HTML page with embedded SVGs
                if ($svgContent) {
                    Write-Host "Creating HTML page with embedded diagrams..."
                    
                    # Read HTML template
                    $htmlTemplate = Get-Content "$directorypath\html_template.html" -Raw
                    
                    # Prepare filtered SVG content (use fallback message if doesn't exist)
                    $svgContentForFiltered = if ($svgContentFiltered) { 
                        $svgContentFiltered 
                    } else { 
                        @"
<div style='display: flex; align-items: center; justify-content: center; height: 100%; padding: 40px;'>
    <div style='text-align: center; color: #666; max-width: 600px;'>
        <svg width='100' height='100' viewBox='0 0 100 100' style='margin-bottom: 20px;'>
            <circle cx='50' cy='50' r='45' fill='#4CAF50' opacity='0.2'/>
            <path d='M30 50 L45 65 L70 35' stroke='#4CAF50' stroke-width='6' fill='none' stroke-linecap='round' stroke-linejoin='round'/>
        </svg>
        <h2 style='color: #4CAF50; margin-bottom: 10px;'>All Batches Ran Successfully!</h2>
        <p style='font-size: 16px;'>No batches to display in filtered view. All scheduled batches completed today.</p>
    </div>
</div>
"@
                    }
                    
                    # Prepare broken references SVG content
                    $svgContentForBroken = if ($svgContentBroken) {
                        $svgContentBroken
                    } else {
                        @"
<div style='display: flex; align-items: center; justify-content: center; height: 100%; padding: 40px;'>
    <div style='text-align: center; color: #666; max-width: 600px;'>
        <svg width='100' height='100' viewBox='0 0 100 100' style='margin-bottom: 20px;'>
            <circle cx='50' cy='50' r='45' fill='#4CAF50' opacity='0.2'/>
            <path d='M30 50 L45 65 L70 35' stroke='#4CAF50' stroke-width='6' fill='none' stroke-linecap='round' stroke-linejoin='round'/>
        </svg>
        <h2 style='color: #4CAF50; margin-bottom: 10px;'>No Broken References!</h2>
        <p style='font-size: 16px;'>All node references are valid.</p>
    </div>
</div>
"@
                    }
                    
                    # Build historical snapshots JSON array
                    Write-Host "Building historical snapshots list..." -ForegroundColor Cyan
                    $snapshotsJson = @()
                    $snapshotPattern = "$($sqlFileName)_$($server)_*_*.svg"
                    Write-Host "  Looking for files matching: $snapshotPattern" -ForegroundColor Gray
                    $snapshotFiles = Get-ChildItem "$directorypath\Diagrams\$snapshotPattern" -ErrorAction SilentlyContinue
                    Write-Host "  Found $($snapshotFiles.Count) snapshot files" -ForegroundColor Gray
                    
                    foreach ($file in $snapshotFiles) {
                        if ($file.Name -match '_(\d{8})_(\d{4})\.svg$') {
                            $dateStr = $matches[1]
                            $timeStr = $matches[2]
                            
                            # Parse the date
                            $year = [int]$dateStr.Substring(0,4)
                            $month = [int]$dateStr.Substring(4,2)
                            $day = [int]$dateStr.Substring(6,2)
                            $hour = [int]$timeStr.Substring(0,2)
                            $minute = [int]$timeStr.Substring(2,2)
                            $fileDate = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second 0
                            
                            # Convert to 12-hour format
                            $ampm = if ($hour -ge 12) { "PM" } else { "AM" }
                            $hour12 = $hour % 12
                            if ($hour12 -eq 0) { $hour12 = 12 }
                            $timeFormatted = "{0}:{1:D2} {2}" -f $hour12, $minute, $ampm
                            
                            $snapshot = @{
                                filename = $file.Name
                                htmlFile = $file.Name -replace '\.svg$', '.html'
                                date = "$($dateStr.Substring(0,4))-$($dateStr.Substring(4,2))-$($dateStr.Substring(6,2))"
                                time = "$($timeStr.Substring(0,2)):$($timeStr.Substring(2,2))"
                                timeFormatted = $timeFormatted
                                timestamp = "$($dateStr.Substring(0,4))-$($dateStr.Substring(4,2))-$($dateStr.Substring(6,2))T$($timeStr.Substring(0,2)):$($timeStr.Substring(2,2)):00"
                            }
                            
                            # Generate HTML file for this snapshot
                            $snapshotSvgPath = "$directorypath\Diagrams\$($file.Name)"
                            if (Test-Path $snapshotSvgPath) {
                                $snapshotSvgContent = Get-Content $snapshotSvgPath -Raw
                                
                                # Create HTML for this snapshot (no filters, just the snapshot SVG)
                                $snapshotHtmlContent = $htmlTemplate
                                $snapshotHtmlContent = $snapshotHtmlContent -replace 'GRAPHNAME_PLACEHOLDER', "$graphname - Snapshot $($snapshot.date) $($snapshot.time)"
                                $snapshotHtmlContent = $snapshotHtmlContent -replace 'SERVER_PLACEHOLDER', $server
                                $snapshotHtmlContent = $snapshotHtmlContent.Replace('SNAPSHOTS_JSON_PLACEHOLDER', '[]')
                                $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_ALL_PLACEHOLDER', $snapshotSvgContent)
                                # For snapshots, show the same SVG in all filter views
                                $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_FILTERED_PLACEHOLDER', $snapshotSvgContent)
                                $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_BROKEN_PLACEHOLDER', $snapshotSvgContent)
                                
                                # Save snapshot HTML file
                                $snapshotHtmlFile = "$directorypath\Diagrams\$($snapshot.htmlFile)"
                                $snapshotHtmlContent | Out-File $snapshotHtmlFile -Force -Encoding UTF8
                                Write-Host "    Generated HTML: $($snapshot.htmlFile)" -ForegroundColor Green
                            }
                            
                            $snapshotsJson += $snapshot
                        }
                    }
                    
                    # Sort by timestamp descending
                    $snapshotsJson = $snapshotsJson | Sort-Object -Property timestamp -Descending
                    
                    # Convert to JSON string for embedding in HTML
                    $snapshotsJsonString = $snapshotsJson | ConvertTo-Json -Depth 10 -Compress
                    if ($snapshotsJson.Count -eq 0) {
                        $snapshotsJsonString = "[]"
                    }
                    Write-Host "  Built snapshots list with $($snapshotsJson.Count) items" -ForegroundColor Green
                    
                    # Define the latest page URL
                    $latestPageUrl = "$($sqlFileName)_$($server).html"
                    
                    # Clean up orphaned HTML files (HTML files without corresponding SVG files)
                    Write-Host "Cleaning up orphaned HTML files..." -ForegroundColor Cyan
                    $allSnapshotHtmlFiles = Get-ChildItem "$directorypath\Diagrams\$($sqlFileName)_$($server)_*_*.html" -ErrorAction SilentlyContinue
                    $orphanedCount = 0
                    foreach ($htmlFile in $allSnapshotHtmlFiles) {
                        # Check if corresponding SVG exists
                        $svgFileName = $htmlFile.Name -replace '\.html$', '.svg'
                        $svgFilePath = "$directorypath\Diagrams\$svgFileName"
                        if (-not (Test-Path $svgFilePath)) {
                            # SVG doesn't exist, remove the orphaned HTML
                            Remove-Item $htmlFile.FullName -Force
                            Write-Host "    Removed orphaned HTML: $($htmlFile.Name)" -ForegroundColor Yellow
                            $orphanedCount++
                        }
                    }
                    if ($orphanedCount -eq 0) {
                        Write-Host "    No orphaned HTML files found" -ForegroundColor Green
                    } else {
                        Write-Host "    Removed $orphanedCount orphaned HTML file(s)" -ForegroundColor Green
                    }
                    
                    # Generate HTML files for historical snapshots
                    Write-Host "Generating HTML files for historical snapshots..." -ForegroundColor Cyan
                    foreach ($snapshot in $snapshotsJson) {
                        $snapshotSvgPath = "$directorypath\Diagrams\$($snapshot.filename)"
                        if (Test-Path $snapshotSvgPath) {
                            $snapshotSvgContent = Get-Content $snapshotSvgPath -Raw
                            
                            # Create HTML for this snapshot
                            $snapshotHtmlContent = $htmlTemplate
                            $snapshotHtmlContent = $snapshotHtmlContent -replace 'GRAPHNAME_PLACEHOLDER', "$graphname <span class='snapshot-badge'>[ Snapshot $($snapshot.date) $($snapshot.timeFormatted) ]</span>"
                            $snapshotHtmlContent = $snapshotHtmlContent -replace 'SERVER_PLACEHOLDER', $server
                            $snapshotHtmlContent = $snapshotHtmlContent.Replace('LATEST_PAGE_URL_PLACEHOLDER', $latestPageUrl)
                            $snapshotHtmlContent = $snapshotHtmlContent.Replace('SNAPSHOTS_JSON_PLACEHOLDER', $snapshotsJsonString)
                            $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_ALL_PLACEHOLDER', $snapshotSvgContent)
                            # For snapshots, show the same SVG in all filter views
                            $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_FILTERED_PLACEHOLDER', $snapshotSvgContent)
                            $snapshotHtmlContent = $snapshotHtmlContent.Replace('SVG_CONTENT_BROKEN_PLACEHOLDER', $snapshotSvgContent)
                            
                            # Save snapshot HTML file
                            $snapshotHtmlFile = "$directorypath\Diagrams\$($snapshot.htmlFile)"
                            $snapshotHtmlContent | Out-File $snapshotHtmlFile -Force -Encoding UTF8
                            Write-Host "    Generated HTML: $($snapshot.htmlFile)" -ForegroundColor Green
                        }
                    }
                    
                    # Replace placeholders in template for main page
                    # Get current timestamp for the main page
                    $currentTime = Get-Date
                    $currentTimeFormatted = $currentTime.ToString("yyyy-MM-dd h:mm tt")
                    
                    $htmlContent = $htmlTemplate
                    $htmlContent = $htmlContent -replace 'GRAPHNAME_PLACEHOLDER', "$graphname <span class='latest-badge'>[ Latest $currentTimeFormatted ]</span>"
                    $htmlContent = $htmlContent -replace 'SERVER_PLACEHOLDER', $server
                    $htmlContent = $htmlContent.Replace('LATEST_PAGE_URL_PLACEHOLDER', $latestPageUrl)
                    # Use .Replace() instead of -replace for JSON to avoid regex interpretation
                    $htmlContent = $htmlContent.Replace('SNAPSHOTS_JSON_PLACEHOLDER', $snapshotsJsonString)
                    $htmlContent = $htmlContent.Replace('SVG_CONTENT_ALL_PLACEHOLDER', $svgContent)
                    $htmlContent = $htmlContent.Replace('SVG_CONTENT_FILTERED_PLACEHOLDER', $svgContentForFiltered)
                    $htmlContent = $htmlContent.Replace('SVG_CONTENT_BROKEN_PLACEHOLDER', $svgContentForBroken)
                    
                    # Save HTML file
                    $htmlFile = "$directorypath\Diagrams\$($sqlFileName)_$($server).html"
                    $htmlContent | Out-File $htmlFile -Force -Encoding UTF8
                    Write-Host "HTML page created: $htmlFile" -ForegroundColor Green
                    
                    # Also save JSON file for reference (optional)
                    $jsonFile = "$directorypath\Diagrams\$($sqlFileName)_$($server)_snapshots.json"
                    $snapshotsJsonString | Out-File $jsonFile -Force -Encoding UTF8
                    Write-Host "  Snapshots JSON saved: $jsonFile" -ForegroundColor Gray
                } else {
                    Write-Warning "Skipping HTML generation - SVG content not available"
                }
                
                ## Create Files with Timestamps for Archving Purposes
                if ($graphVizPath -and (Test-Path $graphVizPath)) {
                    # Configure HCPosh to use the correct GraphViz path for timestamped files
                    try {
                        HCPosh -OutDir "$directorypath\Diagrams\" -Graphviz -InputDir "$directorypath\GraphViz\$($sqlFileName)_$($server)_$($CreationTimeStampDTS).gv" -OutType svg -GraphVizPath $graphVizPath
                    }
                    catch {
                        # Fallback to direct GraphViz execution
                        $inputFile = "$directorypath\GraphViz\$($sqlFileName)_$($server)_$($CreationTimeStampDTS).gv"
                        $outputFile = "$directorypath\Diagrams\$($sqlFileName)_$($server)_$($CreationTimeStampDTS).svg"
                        
                        # Ensure output directory exists
                        $outputDir = Split-Path $outputFile -Parent
                        if (-not (Test-Path $outputDir)) {
                            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                        }
                        
                        # Run GraphViz directly
                        & $graphVizPath -Tsvg $inputFile -o $outputFile
                        Write-Host "Generated timestamped diagram using direct GraphViz: $outputFile" -ForegroundColor Green
                    }
                }
                #HCPosh -OutDir "$directorypath\Diagrams\" -Graphviz -InputDir "$directorypath\GraphViz\$($sqlFileName)_$($server)_LR_$($CreationTimeStampDTS).gv" -OutType svg
                
                #if (!$quiet) {
                #    Start-Process -FilePath "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" -ArgumentList "$directorypath\Diagrams\$($sqlFileName)_$($server).svg"
                #}
                    
                Write-Host "Diagram Completed: $($sqlFileName)_$($server)"
            } ##End ForEach SqlFileName
        } ##End ForEach Server

        #Clean up files older than 90 days
        # Define the folder path and the pattern of file names you want to delete
        $folderPath = $directorypath + "\GraphViz"
        $fileNamePattern = $sqlFileName+ "_"+ $serverCD+"*_20*"

        Write-Output "about to attempt a delete on the folder: $folderPath for the file name: $fileNamePattern"

		try{
			#remove old files
			remove-old_files -folder_path $folderPath -file_pattern $fileNamePattern -days_to_keep_files 90
		} catch {
			throw "Error removing old files, error was " + $_
		}
        Write-Host "Deletion for GraphViz complete."

        $folderPath = $directorypath + "\Diagrams"
		
        Write-Output "about to attempt a delete on the folder: $folderPath for the file name: $fileNamePattern"

		try{
			#remove old files
			remove-old_files -folder_path $folderPath -file_pattern $fileNamePattern -days_to_keep_files 90
		} catch {
			throw "Error removing old files, error was " + $_
		}

        Write-Host "Deletion for Diagrams complete."

        Write-Host "Process complete. The diagrams and HTML pages were generated in the following folder: $directorypath\Diagrams\"
        Write-Host "Open the .html files in a web browser to view the interactive diagrams with filtering." -ForegroundColor Cyan
        Set-Location $directorypath
    
