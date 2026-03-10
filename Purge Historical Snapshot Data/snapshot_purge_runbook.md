# Snapshot Historical Data Purge Framework

Operational Runbook

Last Generated: 2026-03-05 21:39 UTC

------------------------------------------------------------------------

# 1. Overview

The Snapshot Historical Data Purge framework provides a controlled way
to remove historical records from snapshot tables once they exceed a
configured retention period.

The system is composed of three primary components:

1.  **IDEA Application UI**
2.  **PowerShell Execution Script**
3.  **SQL Server Stored Procedure**

Administrators configure purge settings in the IDEA application.\
When an ETL job runs, the PowerShell script validates configuration and
then executes the purge stored procedure which removes historical data
safely in batches.

This framework ensures:

-   Controlled retention management
-   Auditable purge activity
-   Safe batch deletes
-   Ability to run in **Audit Mode** without deleting data

------------------------------------------------------------------------

# 2. High-Level Architecture

``` mermaid
flowchart LR

A[IDEA Application<br>Snapshot Table Management] 
B[PowerShell Script<br>PurgeHistoricalSnapshotData.ps1]
C[SQL Stored Procedure<br>etlPurgeHistoricalSnapshotData]
D[Snapshot Tables<br>in Data Marts]
E[ETL Event Logging]

A --> B
B --> C
C --> D
C --> E
```

------------------------------------------------------------------------

# 3. Administrator Workflow

Typical operational workflow:

1.  Administrator identifies snapshot tables requiring historical
    cleanup
2.  Configuration is added in the **IDEA Snapshot Table Management UI**
3.  ETL process triggers PowerShell script
4.  Script validates configuration
5.  Stored procedure purges historical data in batches
6.  Purge activity is logged in the ETL event logs

------------------------------------------------------------------------

# 4. IDEA Application Configuration

Administrators manage purge settings through:

**IDEA → Applications → SAM Snapshot Table Management**

Each record defines how historical snapshot data should be handled.

## Configuration Fields

  Field                   Description
  ----------------------- -------------------------------------------------
  Data Mart Name          The data mart where the snapshot table exists
  Table ID                Internal identifier for the snapshot table
  Table Name              Name of the snapshot table
  Validation Flag         Reserved for validation logic
  Unique Index Name       Optional index used for performance
  Purge Data Flag         Enables or disables deletion of historical data
  Purge Date Field Name   Column used to determine record age
  Purge Lookback Days     Number of days to retain snapshot records

### Example

| Table \| Purge Flag \| Date Field \| Retention \|

\|------\|------\|------\|------\| Provider Cohort Snapshot \| True \|
RunDTS \| 90 Days \| \| Diabetes Cohort Snapshot \| True \| RunDTS \| 90
Days \|

------------------------------------------------------------------------

# 5. Purge Execution Flow

``` mermaid
flowchart TD

A[Start Script] --> B[Validate Entity Configuration]

B -->|Not Configured| C[Stop Execution<br>Display Warning]

B -->|Configured| D[Execute Purge Stored Procedure]

D --> E[Determine Retention Cutoff Date]

E --> F[Delete Records in Batches]

F --> G{More Rows?}

G -->|Yes| F
G -->|No| H[Write Event Log]

H --> I[Script Completes]
```

------------------------------------------------------------------------

# 6. PowerShell Script Execution

The purge process is executed through the following script:

    PurgeHistoricalSnapshotData.ps1

### Example Execution

    G:\Databases\Staging\Scripts\PurgeHistoricalSnapshotData.ps1 `
        -entityID 43066 `
        -jobID 302944 `
        -serverNM localhost

### Script Parameters

  Parameter   Description
  ----------- ------------------------------------------------------
  entityID    Entity identifier associated with the snapshot table
  jobID       Batch execution identifier
  serverNM    SQL Server instance hosting the SAM database

------------------------------------------------------------------------

# 7. Script Runtime Output

When the script runs it prints:

-   Script start time
-   Server name
-   Entity ID
-   Job ID
-   Execution status
-   Script completion time
-   Total runtime

Example:

    --------------------------------------------
    Script Start Time: 2026-03-05 14:01
    Server: localhost
    EntityID: 43066
    JobID: 302944
    --------------------------------------------

    Entity configuration found. Executing purge stored procedure...

    Stored procedure executed successfully.

    --------------------------------------------
    Script End Time: 2026-03-05 14:04
    Total Runtime: 00:03:12
    --------------------------------------------

------------------------------------------------------------------------

# 8. Safety Controls

The purge framework includes several safeguards.

## Configuration Validation

Before execution, the script confirms the entity exists in the
configuration table.

If not configured, the script stops and displays:

    This entity/table has not been configured to remove historical snapshot data.

------------------------------------------------------------------------

## Audit Mode

If **Purge Data Flag = False**, the process runs in audit mode.

In this mode:

-   No records are deleted
-   SQL delete statements are logged for review

This allows administrators to validate purge behavior safely.

------------------------------------------------------------------------

## Batch Deletion

Deletes occur in **small batches (10,000 rows)**.

Benefits:

-   Prevents transaction log growth
-   Reduces locking
-   Improves system stability

------------------------------------------------------------------------

# 9. Logging and Monitoring

All purge operations are logged through the ETL logging framework.

Logged details include:

-   Table affected
-   Number of rows deleted
-   Retention cutoff date used
-   Execution statement
-   Batch execution ID

This allows full auditing of purge operations.

------------------------------------------------------------------------

# 10. Recommended Operational Process

### Step 1

Identify snapshot tables that accumulate historical data.

### Step 2

Add configuration in the IDEA application.

### Step 3

Enable purge flag only after validating configuration.

### Step 4

Run ETL job or scheduled process.

### Step 5

Review ETL logs for purge results.

------------------------------------------------------------------------

# 11. Operational Best Practices

Recommended guidelines:

• Always test with **Purge Flag disabled** first\
• Start with smaller retention periods in lower environments\
• Monitor transaction log growth during first execution\
• Ensure date field used for purge is indexed when possible

------------------------------------------------------------------------

# 12. Summary

The Snapshot Historical Data Purge framework provides:

-   Centralized configuration via the IDEA application
-   Automated purge execution through PowerShell
-   Controlled deletion through SQL stored procedures
-   Full auditing and logging

This ensures historical snapshot tables remain performant while
maintaining a safe and controlled retention policy.
