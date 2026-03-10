#param (
#    [Parameter(Mandatory=$true)]
#    [int]$entityID,
#
#    [Parameter(Mandatory=$true)]
#    [int]$jobID,
#
#    [Parameter(Mandatory=$true)]
#    [string]$serverNM,
#
#    [Parameter(Mandatory=$false)]
#    [switch]$diagnosticMode = $false
#)

# For testing purposes
$entityID = 43066
$jobID = 305046
$serverNM = 'rhnv-edwdev.rhnv.hosted'
$diagnosticMode = $false  # Set to $true for detailed diagnostic output

$database = "SAM"

$scriptStart = Get-Date

Write-Output "--------------------------------------------"
Write-Output "Validate Snapshot Script Starting"
Write-Output "Start Time: $scriptStart"
Write-Output "Server: $serverNM"
Write-Output "EntityID: $entityID"
Write-Output "JobID: $jobID"
Write-Output "--------------------------------------------"

$connectionString = "Server=$serverNM;Database=$database;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"

try {

        $qryCS = "Server=$serverNM;Database=$database;Integrated Security=True;TrustServerCertificate=True"

        # Query to verify entity is configured
        $query = @"
                    SELECT COUNT(*) AS ConfigCount
                    FROM [IDEA].[ClientAdmin].[SAMSnapshotTableManagementBASE] sn
                    JOIN EDWAdmin.CatalystAdmin.TableBASE tb 
                        ON sn.TableID = tb.TableID
                    JOIN EDWAdmin.CatalystAdmin.EntityBASE eb 
                        ON tb.ContentID = eb.ContentID
                    WHERE eb.EntityID = $entityID
"@

        $result = Invoke-Sqlcmd `
            -ConnectionString $qryCS `
            -Query $query

        if ($result.ConfigCount -le 0) {
            Write-Output "This entity/table has not been configured to remove historical snapshot data."
            Write-Output "Please see: [IDEA].[ClientAdmin].[SAMSnapshotTableManagementBASE] table for tables that have been configured."
            exit 1
        }

        #Script only proceeds if the query above "found" and entity configured
        Write-Output "Entity configuration found. Executing purge stored procedure..."

    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString

    # Capture SQL PRINT messages but NOT errors (severity < 11)
    $connection.FireInfoMessageEventOnUserErrors = $false  # Changed to false!
    $sqlMessages = @()
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler]{
        param($snd,$evt)
        foreach ($err in $evt.Errors) {
            $msg = "SQL Message [Severity $($err.Class)]: $($err.Message)"
            Write-Output $msg
            $script:sqlMessages += $msg
        }
    }
    $connection.add_InfoMessage($handler)

    $connection.Open()
    Write-Output "SQL connection established."

    $command = $connection.CreateCommand()
    $command.CommandText = "EXEC [ClientAdmin].[etlValidateSnapshotData] @EntityID, @JobID"
    $command.CommandTimeout = 300  # 5 minutes timeout

    $param1 = $command.Parameters.Add("@EntityID",[System.Data.SqlDbType]::Int)
    $param1.Value = $entityID

    $param2 = $command.Parameters.Add("@JobID",[System.Data.SqlDbType]::Int)
    $param2.Value = $jobID

    Write-Output "Executing stored procedure..."
    Write-Output ""

    # ExecuteNonQuery will throw exception on THROW
    $result = $command.ExecuteNonQuery()

    Write-Output ""
    Write-Output "Snapshot validation Script completed successfully (Check ETLLogBASE for more details)."

    if ($connection.State -eq "Open") {
        $connection.Close()
    }

    $scriptEnd = Get-Date
    $duration = New-TimeSpan -Start $scriptStart -End $scriptEnd

    Write-Output "--------------------------------------------"
    Write-Output "Script End Time: $scriptEnd"
    Write-Output "Total Runtime: $duration"
    Write-Output "--------------------------------------------"

    exit 0

}
catch {

    #Write-Output ""
    #Write-Output "============================================"
    #Write-Output "ERROR: Snapshot validation FAILED"
    #Write-Output "============================================"
    
    # Extract just the core error message from SQL
    $errorMessage = $_.Exception.Message
    if ($_.Exception.InnerException) {
        $errorMessage = $_.Exception.InnerException.Message
    }
    
    # Try to extract just the first line (the actual error message)
    $coreMessage = ($errorMessage -split "`n")[0].Trim()
    
    Write-Output "Error: $coreMessage"
    
    # Show diagnostic details only if diagnostic mode is enabled
    if ($diagnosticMode) {
        Write-Output ""
        Write-Output "--- DIAGNOSTIC MODE ENABLED ---"
        Write-Output ""
        Write-Output "Full Error Type: $($_.Exception.GetType().FullName)"
        Write-Output ""
        Write-Output "Full Error Message:"
        Write-Output $errorMessage
        Write-Output ""
        
        if ($_.Exception.InnerException) {
            Write-Output "Inner Exception:"
            Write-Output $_.Exception.InnerException.Message
            Write-Output ""
        }
        
        # Check for SQL errors specifically
        if ($_.Exception -is [System.Data.SqlClient.SqlException]) {
            $sqlEx = $_.Exception
            Write-Output "SQL Exception Details:"
            Write-Output "  Error Number: $($sqlEx.Number)"
            Write-Output "  Error State: $($sqlEx.State)"
            Write-Output "  Error Severity: $($sqlEx.Class)"
            Write-Output "  Line Number: $($sqlEx.LineNumber)"
            Write-Output "  Procedure: $($sqlEx.Procedure)"
            Write-Output "  Server: $($sqlEx.Server)"
            Write-Output ""
            Write-Output "All SQL Errors:"
            foreach ($err in $sqlEx.Errors) {
                Write-Output "  - [Error $($err.Number), Severity $($err.Class), State $($err.State), Line $($err.LineNumber)]"
                Write-Output "    $($err.Message)"
            }
            Write-Output ""
        }
        
        Write-Output "Stack Trace:"
        Write-Output $_.ScriptStackTrace
        Write-Output ""
        Write-Output "All captured SQL messages:"
        if ($sqlMessages.Count -gt 0) {
            foreach ($msg in $sqlMessages) {
                Write-Output "  $msg"
            }
        } else {
            Write-Output "  (No SQL messages captured)"
        }
        Write-Output ""
        Write-Output "--- END DIAGNOSTIC INFO ---"
    }
    
    Write-Output "============================================"
    if ($connection.State -eq "Open") {
        $connection.Close()
    }

    $scriptEnd = Get-Date
    $duration = New-TimeSpan -Start $scriptStart -End $scriptEnd

    Write-Output "--------------------------------------------"
    Write-Output "Script End Time: $scriptEnd"
    Write-Output "Total Runtime: $duration"
    Write-Output "--------------------------------------------"

    throw

}