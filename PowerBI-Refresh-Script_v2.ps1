# PowerBI API Refresh Script
# This script authenticates with PowerBI API and triggers/monitors refresh operations

# Configuration Variables
#$ObjectNM = 'NHSN Reporting'
#$ObjectNM = 'Nursing Units LOS'
#$ObjectNM = 'Daily Financial Statistics Report'
#$ObjectNM = 'Labor Productivity Dashboard'
$ObjectNM = 'Dataflow 2'
$ClientID = 'a7ec0a28-2ea3-4d09-8bbc-f241f1e929b8'
$TenantID = '54115126-19c9-4b52-84ab-b746e438359a'
$ClientSecret = ''
$ServerNM = 'rhnv-edwdev.rhnv.hosted'
$DatabaseNM = 'IDEA'
$MethodCD = 'POST'
$CheckRefreshMinutesNBR = 2
$ClientUsername = ''
$ClientPassword = ''


# Initialize Variables (will be populated from SQL query)
$WorkspaceID = ''
$ObjectID = ''
$ObjectType = ''
$RetryAttemptNBR = 0
$CheckRefreshStatusFLG = ''

# Function to get variables from SQL Server
function Get-PowerBIVariablesFromSQL {
    param(
        [string]$ServerNM,
        [string]$DatabaseNM,
        [string]$ObjectNM
    )
    
    try {
        # Import SQL Server module if not already loaded
        if (-not (Get-Module -Name SqlServer -ListAvailable)) {
            Write-Output "SqlServer module not found. Please install it using: Install-Module -Name SqlServer"
            throw "SqlServer module required"
        }
        
        Import-Module SqlServer -ErrorAction SilentlyContinue
        
        # SQL Query to get PowerBI operation details
        $sqlQuery = @"
select ObjectID, WorkspaceId, ObjectTypeCD, RetryAttemptNBR, AuthenticationTypeCD
from IDEA.ClientAdmin.ETLSequencedPowerBIOperation
where ObjectNM = '$ObjectNM'
"@
        
        Write-Output "Connecting to SQL Server: $ServerNM, Database: $DatabaseNM"
        Write-Output "Executing query for ObjectNM: $ObjectNM"
        
        # Execute the SQL query with SSL certificate handling
        # Try multiple connection approaches to handle SSL certificate issues
        $result = $null
        $connectionAttempts = @(
            @{
                Description = "TrustServerCertificate"
                Method = "Parameters"
                Parameters = @{
                    ServerInstance = $ServerNM
                    Database = $DatabaseNM
                    Query = $sqlQuery
                    TrustServerCertificate = $true
                    ErrorAction = "Stop"
                }
            },
            @{
                Description = "Encrypt=False with Integrated Security"
                Method = "ConnectionString"
                ConnectionString = "Server=$ServerNM;Database=$DatabaseNM;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
                Parameters = @{
                    Query = $sqlQuery
                    ErrorAction = "Stop"
                }
            },
            @{
                Description = "Encrypt=Optional"
                Method = "ConnectionString"
                ConnectionString = "Server=$ServerNM;Database=$DatabaseNM;Integrated Security=True;Encrypt=Optional;"
                Parameters = @{
                    Query = $sqlQuery
                    ErrorAction = "Stop"
                }
            }
        )
        
        foreach ($attempt in $connectionAttempts) {
            try {
                Write-Output "Attempting connection with: $($attempt.Description)"
                
                if ($attempt.Method -eq "ConnectionString") {
                    $result = Invoke-Sqlcmd -ConnectionString $attempt.ConnectionString -Query $sqlQuery -ErrorAction Stop
                } else {
                    $result = Invoke-Sqlcmd -ServerInstance $ServerNM -Database $DatabaseNM -Query $sqlQuery -TrustServerCertificate -ErrorAction Stop
                }
                
                if ($result) {
                    Write-Output "Successfully connected using: $($attempt.Description)"
                    break
                }
            }
            catch {
                Write-Output "Connection attempt failed with $($attempt.Description): $($_.Exception.Message)"
                if ($attempt -eq $connectionAttempts[-1]) {
                    throw "All connection attempts failed. Last error: $_"
                }
            }
        }
        
        if ($result) {
            # Populate global variables from SQL result
            $global:WorkspaceID = $result.WorkspaceId
            $global:ObjectID = $result.ObjectID
            $global:ObjectType = $result.ObjectTypeCD
            $global:RetryAttemptNBR = $result.RetryAttemptNBR
            $global:AuthenticationTypeCD = $result.AuthenticationTypeCD
            
            # Set CheckRefreshStatusFLG based on RetryAttemptNBR
            if ($global:RetryAttemptNBR -eq 0) {
                $global:CheckRefreshStatusFLG = 'N'
            } elseif ($global:RetryAttemptNBR -ge 1) {
                $global:CheckRefreshStatusFLG = 'Y'
            }
            
            Write-Output "Variables successfully retrieved from SQL Server:"
            Write-Output "  WorkspaceID: $global:WorkspaceID"
            Write-Output "  ObjectID: $global:ObjectID"
            Write-Output "  ObjectType: $global:ObjectType"
            Write-Output "  RetryAttemptNBR: $global:RetryAttemptNBR"
            Write-Output "  CheckRefreshStatusFLG: $global:CheckRefreshStatusFLG"
            Write-Output "  AuthenticationTypeCD: $global:AuthenticationTypeCD"
            
            return $true
        } else {
            Write-Output "No records found for ObjectNM: $ObjectNM"
            return $false
        }
    }
    catch {
        Write-Output "Error retrieving variables from SQL Server: $_"
        throw
    }
}

# Get Variables from SQL Server
$sqlSuccess = Get-PowerBIVariablesFromSQL -ServerNM $ServerNM -DatabaseNM $DatabaseNM -ObjectNM $ObjectNM

if (-not $sqlSuccess) {
    Write-Output "Failed to retrieve required variables from SQL Server. Exiting script."
    exit 1
}


function CheckRefreshStatus {
    param(
        [string]$ApiURL,
        [int]$RetryCNT
    )
    
    $StatusLoopCNT = 1
    
    # Check the status of the API Refresh
    while ($refreshStatus -in "InProgress", "Unknown" -and $StatusLoopCNT -le $RetryCNT -and $MethodCD -eq "POST") {
        Write-Output "  --> Status of API Refresh (Initialized): $refreshStatus"
        
        try {
            # Wait 60 Seconds and see if the refresh is complete
            Start-Sleep -Seconds 60
            
            # Get refresh status
            $history = Invoke-RestMethod -Uri $ApiURL -Headers $headers -Method "Get"
            
            # Dataflow refresh history returns more records than expected and ?$top=1 does not work for Dataflow Transactions history
            $refreshStatus = $history.value.status | Select-Object -First 1
        }
        catch {
            $EventDescriptionTXT = "API call failed to check the status of the API Refresh. Error Details: $_"
            throw $EventDescriptionTXT
        }
        
        if ($refreshStatus -eq 'Failed') {
            Write-Output "  --> Status of API Refresh: $refreshStatus - Throw Exception and Display Error"
            $EventDescriptionTXT = "API Refresh: Failed - $ObjectType ($ObjectNM):: $ObjectID, for workspace: $WorkspaceID. Please manually check PowerBI object for errors."
            Write-Output $EventDescriptionTXT
            throw $EventDescriptionTXT
        }
        
        if ($refreshStatus -eq 'Unknown' -or $refreshStatus -eq 'InProgress') {
            $WaitSecondsNBR = 60 * $CheckRefreshMinutesNBR
            Write-Output "  --> Status of API Refresh: $refreshStatus - Check again in: $WaitSecondsNBR seconds"
            Start-Sleep -Seconds $WaitSecondsNBR
        }
        
        # Incremental Loop Counter
        $StatusLoopCNT = $StatusLoopCNT + 1
    }
    
    if ($refreshStatus -in 'InProgress', 'Unknown' -and $StatusLoopCNT -gt $RetryCNT) {
        $StatusMessage = "  --> API Refresh DID NOT COMPLETE - Checked Status $RetryCNT Times (Consider Increasing Retry Attempts) - $ObjectType ($ObjectNM):: $ObjectID, for workspace: $WorkspaceID."
        Write-Output $StatusMessage
    }
    
    if ($refreshStatus -eq 'Completed' -or $refreshStatus -eq 'Success') {
        $StatusMessage = "  --> API Refresh: Completed - $ObjectType ($ObjectNM):: $ObjectID, for workspace: $WorkspaceID."
        Write-Output $StatusMessage
    }
}

# Main Script Execution
try {
    Write-Output "Starting PowerBI API Refresh Process..."
    Write-Output "Object Type: $ObjectType"
    Write-Output "Object Name: $ObjectNM"
    Write-Output "Workspace ID: $WorkspaceID"
    Write-Output "Object ID: $ObjectID"
    
    # Prepare authentication form data
    if ($AuthenticationTypeCD -eq 'ClientSecret') {
        $formdata = @{
            grant_type    = 'client_credentials'
            client_id     = $ClientID
            client_secret = $ClientSecret
            resource      = 'https://analysis.windows.net/powerbi/api'
            scope         = 'openid'
        }
    }
    
    if ($AuthenticationTypeCD -eq 'ClientUsername') {
        $formdata = @{
            grant_type = 'password'
            client_id  = $ClientID
            client_secret = $ClientSecret
            resource   = 'https://analysis.windows.net/powerbi/api'
            scope      = 'openid'
            username   = $ClientUsername
            password   = $ClientPassword
        }
    }
    
    Write-Output "AuthenticationTypeCD: $AuthenticationTypeCD"
    Write-Output "PowerBI Credentials Created - Ready to Authenticate and Obtain Token"
    
    $loginURL = "https://login.microsoftonline.com/$TenantID/oauth2/token"
    Write-Output "loginURL: $loginURL"
    
    try {
        $response = Invoke-RestMethod -Uri $loginURL -Method 'POST' -Body $formdata
    }
    catch {
        Write-Output "Failed to login to PowerBI. Error is $_"
        throw
    }
    
    Write-Output "About to get headers"
    try {
        $headers = @{
            Authorization = "Bearer $($response.access_token)"
        }
    }
    catch {
        Write-Output "Failed to get authorization token from PowerBI. Error is $_"
        throw
    }
    
    $bodydata = @{
        "retryCount"     = $RetryAttemptNBR
        "refreshRequest" = "y"
        "type"          = "full"
    }
    
    # Set API endpoints based on object type
    if ($ObjectType -eq 'Semantic Model / Dataset') {
        $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceID/datasets/$ObjectID/refreshes"
        $UriRefreshStatus = $uri + '?$top=1'
        Write-Output "PostURI: $uri"
    }
    
    if ($ObjectType -eq 'Dataflow') {
        $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceID/dataflows/$ObjectID/refreshes"
        $UriRefreshStatus = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceID/dataflows/$ObjectID/transactions"
    }
    
    # Execute the API call
    Invoke-RestMethod -Uri $uri -Headers $headers -Method $MethodCD -Body $bodydata -Verbose
    
    # Display Method Code: POST or GET to Console
    Write-Output "$MethodCD called"
    
    # Check refresh status if enabled
    if ($CheckRefreshStatusFLG -eq "Y") {
        $refreshStatus = "Unknown"
        CheckRefreshStatus -ApiURL $UriRefreshStatus -RetryCNT $RetryAttemptNBR
    }
}
catch {
    $StatusMessage = "Error Message: $ObjectType ($ObjectNM):: $ObjectID, for workspace: $WorkspaceID. Error details: " + $_
    Write-Output $StatusMessage
    throw
}

Write-Output "PowerBI API Refresh Process Completed."