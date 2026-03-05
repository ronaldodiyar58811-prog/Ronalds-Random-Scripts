param (
    [Parameter(Mandatory=$true)]
    [int]$entityID,

    [Parameter(Mandatory=$true)]
    [int]$jobID,

    [Parameter(Mandatory=$true)]
    [string]$serverNM
)

# Testing Variables
#$entityID = 43066
#$jobID = 302944
#$serverNM = 'rhnv-edwdev'

$database = "SAM"

# Capture script start time
$scriptStart = Get-Date
Write-Output "--------------------------------------------"
Write-Output "Script Start Time: $scriptStart"
Write-Output "Server: $serverNM"
Write-Output "EntityID: $entityID"
Write-Output "JobID: $jobID"
Write-Output "--------------------------------------------"

try {

    $connString = "Server=$serverNM;Database=$database;Integrated Security=True;TrustServerCertificate=True"

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
        -ConnectionString $connString `
        -Query $query

    if ($result.ConfigCount -le 0) {
        Write-Output "This entity/table has not been configured to remove historical snapshot data."
        Write-Output "Please see: [IDEA].[ClientAdmin].[SAMSnapshotTableManagementBASE] table for tables that have been configured."
        exit 1
    }

    Write-Output "Entity configuration found. Executing purge stored procedure..."

    $execQuery = "EXEC [ClientAdmin].[etlPurgeHistoricalSnapshotData] $entityID, $jobID"

    Invoke-Sqlcmd `
        -ConnectionString $connString `
        -Query $execQuery

    Write-Output "Stored procedure executed successfully."

}
catch {
    Write-Error "Execution failed: $($_.Exception.Message)"
    exit 1
}
finally {

    # Capture end time
    $scriptEnd = Get-Date
    $duration = New-TimeSpan -Start $scriptStart -End $scriptEnd

    Write-Output "--------------------------------------------"
    Write-Output "Script End Time: $scriptEnd"
    Write-Output "Total Runtime: $($duration.ToString())"
    Write-Output "--------------------------------------------"
}