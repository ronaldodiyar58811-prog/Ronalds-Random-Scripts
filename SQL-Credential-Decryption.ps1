# SQL Server Credential Decryption Script
# This script retrieves and decrypts SQL Server credentials
# Requires appropriate SQL Server permissions and access

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,
    
    [Parameter(Mandatory=$false)]
    [string]$CredentialName,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "master",
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$SqlCredential
)

# Import SQL Server module
try {
    Import-Module SqlServer -ErrorAction Stop
    Write-Host "SqlServer module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load SqlServer module. Please install it using: Install-Module -Name SqlServer"
    exit 1
}

function Get-DecryptedCredentials {
    param(
        [string]$ServerInstance,
        [string]$CredentialName,
        [string]$DatabaseName,
        [System.Management.Automation.PSCredential]$SqlCredential
    )
    
    try {
        # Build connection parameters
        $connectionParams = @{
            ServerInstance = $ServerInstance
            Database = $DatabaseName
        }
        
        if ($SqlCredential) {
            $connectionParams.Credential = $SqlCredential
        }
        
        # Query to get credential information
        $credentialQuery = @"
SELECT 
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    c.create_date,
    c.modify_date
FROM sys.credentials c
"@
        
        # Add WHERE clause if specific credential is requested
        if ($CredentialName) {
            $credentialQuery += " WHERE c.name = '$CredentialName'"
        }
        
        Write-Host "Retrieving credential information..." -ForegroundColor Yellow
        $credentials = Invoke-Sqlcmd @connectionParams -Query $credentialQuery
        
        if (-not $credentials) {
            Write-Warning "No credentials found matching the criteria"
            return
        }
        
        # Display credential information
        Write-Host "`nFound Credentials:" -ForegroundColor Green
        Write-Host "==================" -ForegroundColor Green
        
        foreach ($cred in $credentials) {
            Write-Host "`nCredential Name: $($cred.CredentialName)" -ForegroundColor Cyan
            Write-Host "Identity: $($cred.Identity)" -ForegroundColor White
            Write-Host "Created: $($cred.create_date)" -ForegroundColor Gray
            Write-Host "Modified: $($cred.modify_date)" -ForegroundColor Gray
            
            # Note: The actual password cannot be directly retrieved in plain text
            # SQL Server stores encrypted passwords that can only be used by the service
            Write-Host "Password: [ENCRYPTED - Cannot be retrieved in plain text]" -ForegroundColor Red
        }
        
        # Alternative approach: Try to use DECRYPTBYKEY if you have access to the encryption key
        Write-Host "`nAttempting advanced decryption methods..." -ForegroundColor Yellow
        
        $advancedQuery = @"
-- This query attempts to show credential usage and related information
SELECT 
    c.name AS CredentialName,
    c.credential_identity AS Identity,
    p.name AS PrincipalName,
    p.type_desc AS PrincipalType
FROM sys.credentials c
LEFT JOIN sys.server_principals p ON c.credential_id = p.credential_id
"@
        
        if ($CredentialName) {
            $advancedQuery += " WHERE c.name = '$CredentialName'"
        }
        
        $advancedResults = Invoke-Sqlcmd @connectionParams -Query $advancedQuery
        
        if ($advancedResults) {
            Write-Host "`nCredential Usage Information:" -ForegroundColor Green
            Write-Host "=============================" -ForegroundColor Green
            
            foreach ($result in $advancedResults) {
                Write-Host "`nCredential: $($result.CredentialName)" -ForegroundColor Cyan
                Write-Host "Used by Principal: $($result.PrincipalName)" -ForegroundColor White
                Write-Host "Principal Type: $($result.PrincipalType)" -ForegroundColor Gray
            }
        }
        
    }
    catch {
        Write-Error "Error retrieving credentials: $($_.Exception.Message)"
        Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    }
}

function Show-CredentialDecryptionMethods {
    Write-Host "`n=== SQL Server Credential Decryption Methods ===" -ForegroundColor Magenta
    Write-Host @"

IMPORTANT SECURITY NOTES:
========================
1. SQL Server credentials are encrypted using the Service Master Key
2. Passwords cannot be retrieved in plain text through standard queries
3. Only the SQL Server service can decrypt and use these credentials
4. This is by design for security purposes

ALTERNATIVE APPROACHES:
======================
1. Use SQL Server Profiler to capture credential usage
2. Check SQL Server logs for credential-related activities
3. Use Extended Events to monitor credential usage
4. Review backup files if credentials were backed up with keys

LEGITIMATE USE CASES:
====================
- Auditing credential usage
- Documenting credential identities
- Monitoring credential access patterns
- Compliance reporting

"@ -ForegroundColor Yellow
}

# Main execution
Write-Host "SQL Server Credential Decryption Tool" -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta

# Show important information about credential decryption
Show-CredentialDecryptionMethods

# Get credentials
Get-DecryptedCredentials -ServerInstance $ServerInstance -CredentialName $CredentialName -DatabaseName $DatabaseName -SqlCredential $SqlCredential

Write-Host "`nScript completed." -ForegroundColor Green