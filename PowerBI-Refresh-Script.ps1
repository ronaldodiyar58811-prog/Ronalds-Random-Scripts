# PowerBI API Refresh Script
# This script authenticates with PowerBI API and triggers/monitors refresh operations

# Configuration Variables
$WorkspaceID = '824a0aad-763e-4ff0-9f3d-a4c67aa67f7b'
$ObjectID = '09df1e69-9516-4e9f-921c-a48dc61299e1'
$ObjectType = 'Semantic Model / Dataset'
$ObjectNM = 'NHSN Reporting'
$ClientID = 'a7ec0a28-2ea3-4d09-8bbc-f241f1e929b8'
$ClientSecret = ''
$TenantID = '54115126-19c9-4b52-84ab-b746e438359a'
$RetryAttemptNBR = 3
$AuthenticationTypeCD = 'ClientSecret'
$MethodCD = 'POST'
$CheckRefreshStatusFLG = 'Y'
$CheckRefreshMinutesNBR = 5
$ClientUsername = ''
$ClientPassword = ''

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
        Write-Output "UriRefreshStatus: $UriRefreshStatus"
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