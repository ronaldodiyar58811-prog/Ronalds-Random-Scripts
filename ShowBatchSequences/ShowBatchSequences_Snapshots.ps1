        
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
        $directorypath = "C:\Users\58811.WMCDOMAIN\OneDrive - Renown Health\Documents\Work\Scripts\ShowBatchSequences"

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
                $graphname = "Batch Sequencing - " + $server        

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
                $graphLR = $tab + "graph [layout=dot, rankdir=LR, fontname=Arial, fontsize=10, labelloc=t, label=<<b>" + $graphname + "</b><br />Click on an arrowhead to to get more information<br /> >];" + $crlf
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

                $combineLR = "$($digraph +
                    $graphLR +
                    $node +
					$labels + $crlf +
     				$arrows + "}")"
   
                #Commented out the "LR" - Left to Right Versions of the file as these are genernally not used
                Write-Host "Creating GraphViz file..."
                $combine | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server).gv" -Force -Encoding ascii
                #$combineLR | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_LR.gv" -Force -Encoding ascii

				## Create Files with Timestamps for Archving Purposes
				$combine | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_$($CreationTimeStampDTS).gv" -Force -Encoding ascii
                #$combineLR | Out-File "$directorypath\GraphViz\$($sqlFileName)_$($server)_LR_$($CreationTimeStampDTS).gv" -Force -Encoding ascii

                Write-Host "Creating diagram...$($sqlFileName)_$($server)"
                
                # Configure HCPosh to use the correct GraphViz path
                if ($graphVizPath -and (Test-Path $graphVizPath)) {
                    # Method 1: Try using HCPosh with explicit GraphViz path parameter
                    try {
                        HCPosh -OutDir "$directorypath\Diagrams\" -Graphviz -InputDir "$directorypath\GraphViz\$($sqlFileName)_$($server).gv" -OutType svg -GraphVizPath $graphVizPath
                    }
                    catch {
                        Write-Host "HCPosh with GraphVizPath parameter failed, trying alternative method..." -ForegroundColor Yellow
                        
                        # Method 2: Temporarily copy GraphViz to HCPosh expected location
                        $hcposhGraphVizDir = "$env:USERPROFILE\OneDrive - Renown Health\Documents\WindowsPowerShell\Modules\HCPosh\3.0.17.0\graphviz"
                        $hcposhDotPath = "$hcposhGraphVizDir\dot.exe"
                        
                        try {
                            # Create the directory HCPosh expects
                            if (-not (Test-Path $hcposhGraphVizDir)) {
                                New-Item -ItemType Directory -Path $hcposhGraphVizDir -Force | Out-Null
                            }
                            
                            # Copy dot.exe to where HCPosh expects it
                            Copy-Item $graphVizPath $hcposhDotPath -Force
                            Write-Host "Copied GraphViz to HCPosh expected location: $hcposhDotPath" -ForegroundColor Green
                            
                            # Now try HCPosh again
                            HCPosh -OutDir "$directorypath\Diagrams\" -Graphviz -InputDir "$directorypath\GraphViz\$($sqlFileName)_$($server).gv" -OutType svg
                        }
                        catch {
                            Write-Host "Copy method failed, trying direct dot.exe execution..." -ForegroundColor Yellow
                            
                            # Method 3: Use dot.exe directly instead of HCPosh
                            $inputFile = "$directorypath\GraphViz\$($sqlFileName)_$($server).gv"
                            $outputFile = "$directorypath\Diagrams\$($sqlFileName)_$($server).svg"
                            
                            # Ensure output directory exists
                            $outputDir = Split-Path $outputFile -Parent
                            if (-not (Test-Path $outputDir)) {
                                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                            }
                            
                            # Run GraphViz directly
                            & $graphVizPath -Tsvg $inputFile -o $outputFile
                            Write-Host "Generated diagram using direct GraphViz execution: $outputFile" -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Error "GraphViz not found or not properly configured"
                    throw "Cannot generate diagrams without GraphViz"
                }
                #HCPosh -OutDir "$directorypath\Diagrams\" -Graphviz -InputDir "$directorypath\GraphViz\$($sqlFileName)_$($server)_LR.gv" -OutType svg
                
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

                #Clean up files older than 7 days
        # Define the folder path and the pattern of file names you want to delete
        $folderPath = $directorypath + "\GraphViz"
        $fileNamePattern = $sqlFileName+ "_"+ $serverCD+"*_20*"

        Write-Output "about to attempt a delete on the folder: $folderPath for the file name: $fileNamePattern"

		try{
			#remove old files
			remove-old_files -folder_path $folderPath -file_pattern $fileNamePattern -days_to_keep_files 7
		} catch {
			throw "Error removing old files, error was " + $_
		}
        Write-Host "Deletion for GraphViz complete."

        $folderPath = $directorypath + "\Diagrams"
		
        Write-Output "about to attempt a delete on the folder: $folderPath for the file name: $fileNamePattern"

		try{
			#remove old files
			remove-old_files -folder_path $folderPath -file_pattern $fileNamePattern -days_to_keep_files 7
		} catch {
			throw "Error removing old files, error was " + $_
		}

        Write-Host "Deletion for Diagrams complete."

        Write-Host "Process complete.  The diagrams were generated in the following folder: $directorypath\Diagrams\"
        Set-Location $directorypath
    
