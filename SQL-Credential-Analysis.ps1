# SQL Server Credential Analysis Script
# Alternative approaches for credential investigation

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$SqlCredential
)

function Get-CredentialMetadata {
    param(
        [string]$ServerInstance,
        [System.Management.Automation.PSCredential]$SqlCredential
    )
    
    $connectionParams = @{
        ServerInstance = $ServerInstance
        Database = "master"
    }
    
    if ($SqlCredential) {
        $connectionParams.Credential = $SqlCredential
    }
    
    # Comprehensive credential analysis query
    $query = @"
-- Credential Information with Related Objects
SELECT 
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    c.create_date,
    c.modify_date,
    CASE 
        WHEN EXISTS (SELECT 1 FROM sys.server_principals sp WHERE sp.credential_id = c.credential_id)
        THEN 'Used by Login'
        ELSE 'Not assigned to Login'
    END AS UsageStatus,
    (SELECT COUNT(*) FROM sys.server_principals sp WHERE sp.credential_id = c.credential_id) AS LoginCount
FROM sys.credentials c
ORDER BY c.name;

-- Logins using credentials
SELECT 
    sp.name AS LoginName,
    sp.type_desc AS LoginType,
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    sp.create_date AS LoginCreateDate,
    sp.modify_date AS LoginModifyDate
FROM sys.server_principals sp
INNER JOIN sys.credentials c ON sp.credential_id = c.credential_id
ORDER BY sp.name;

-- Proxy accounts (SQL Agent) using credentials
SELECT 
    p.proxy_id,
    p.name AS ProxyName,
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    p.enabled,
    p.description
FROM msdb.dbo.sysproxies p
INNER JOIN sys.credentials c ON p.credential_id = c.credential_id
ORDER BY p.name;
"@
    
    try {
        Write-Host "Analyzing credential metadata..." -ForegroundColor Yellow
        $results = Invoke-Sqlcmd @connectionParams -Query $query
        
        return $results
    }
    catch {
        Write-Error "Failed to retrieve credential metadata: $($_.Exception.Message)"
        return $null
    }
}

function Export-CredentialAuditReport {
    param(
        [string]$ServerInstance,
        [System.Management.Automation.PSCredential]$SqlCredential,
        [string]$OutputPath = ".\SQL_Credential_Audit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    )
    
    $connectionParams = @{
        ServerInstance = $ServerInstance
        Database = "master"
    }
    
    if ($SqlCredential) {
        $connectionParams.Credential = $SqlCredential
    }
    
    $auditQuery = @"
SELECT 
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    c.create_date,
    c.modify_date,
    COALESCE(sp.name, 'Not Assigned') AS AssignedLogin,
    COALESCE(sp.type_desc, 'N/A') AS LoginType,
    CASE 
        WHEN p.name IS NOT NULL THEN 'SQL Agent Proxy: ' + p.name
        ELSE 'No Proxy Usage'
    END AS ProxyUsage
FROM sys.credentials c
LEFT JOIN sys.server_principals sp ON c.credential_id = sp.credential_id
LEFT JOIN msdb.dbo.sysproxies p ON c.credential_id = p.credential_id
ORDER BY c.name
"@
    
    try {
        $auditData = Invoke-Sqlcmd @connectionParams -Query $auditQuery
        $auditData | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "Audit report exported to: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error "Failed to export audit report: $($_.Exception.Message)"
        return $null
    }
}

function Test-CredentialAccess {
    param(
        [string]$ServerInstance,
        [string]$CredentialName,
        [System.Management.Automation.PSCredential]$SqlCredential
    )
    
    $connectionParams = @{
        ServerInstance = $ServerInstance
        Database = "master"
    }
    
    if ($SqlCredential) {
        $connectionParams.Credential = $SqlCredential
    }
    
    # Test if we can access credential information
    $testQuery = @"
SELECT 
    HAS_PERMS_BY_NAME(NULL, NULL, 'ALTER ANY CREDENTIAL') AS CanAlterCredentials,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION') AS CanViewDefinitions,
    IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin,
    SYSTEM_USER AS CurrentUser,
    USER_NAME() AS DatabaseUser
"@
    
    try {
        $permissions = Invoke-Sqlcmd @connectionParams -Query $testQuery
        
        Write-Host "`nCurrent User Permissions:" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        Write-Host "Current User: $($permissions.CurrentUser)" -ForegroundColor White
        Write-Host "Database User: $($permissions.DatabaseUser)" -ForegroundColor White
        Write-Host "Can Alter Credentials: $($permissions.CanAlterCredentials)" -ForegroundColor $(if($permissions.CanAlterCredentials) {'Green'} else {'Red'})
        Write-Host "Can View Definitions: $($permissions.CanViewDefinitions)" -ForegroundColor $(if($permissions.CanViewDefinitions) {'Green'} else {'Red'})
        Write-Host "Is SysAdmin: $($permissions.IsSysAdmin)" -ForegroundColor $(if($permissions.IsSysAdmin) {'Green'} else {'Red'})
        
        return $permissions
    }
    catch {
        Write-Error "Failed to test permissions: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
Write-Host "SQL Server Credential Analysis Tool" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

# Test current user permissions
$permissions = Test-CredentialAccess -ServerInstance $ServerInstance -SqlCredential $SqlCredential

# Get credential metadata
$metadata = Get-CredentialMetadata -ServerInstance $ServerInstance -SqlCredential $SqlCredential

if ($metadata) {
    Write-Host "`nCredential Analysis Results:" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    $metadata | Format-Table -AutoSize
}

# Export audit report
$reportPath = Export-CredentialAuditReport -ServerInstance $ServerInstance -SqlCredential $SqlCredential

Write-Host "`nAnalysis completed." -ForegroundColor Green
Write-Host "Note: Actual passwords cannot be retrieved due to SQL Server security design." -ForegroundColor Yellow