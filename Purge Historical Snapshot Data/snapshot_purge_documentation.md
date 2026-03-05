# Historical Snapshot Data Purge Management

## Overview

The Historical Snapshot Data Purge framework provides a controlled
method for removing old snapshot records from reporting tables while
maintaining transparency and auditability.\
Configuration is managed through the **IDEA application**, and execution
is performed through a **PowerShell script** that calls a backend stored
procedure.

This approach allows teams to: - Control which tables allow historical
data purging - Define how long snapshot history should be retained -
Safely test purge behavior before enabling deletes - Maintain logging
and visibility of purge actions

------------------------------------------------------------------------

# 1. IDEA Application -- Snapshot Table Management

The **SAM Snapshot Table Management** page in the IDEA application is
used to configure which snapshot tables are eligible for historical data
cleanup.

Administrators use this interface to define the purge policy for each
table.

## Configuration Fields

### Data Mart Name

Identifies the data mart where the snapshot table resides.

### Table ID

Internal identifier for the table within the data platform.

### Table Name

Name of the snapshot table that may have historical data removed.

### Validation Flag

Optional validation setting used internally for platform checks.

### Unique Index Name

Identifies the unique index used for the snapshot table.

### Purge Data Flag

Controls whether historical data will actually be deleted.

  -----------------------------------------------------------------------
  Value                        Behavior
  ---------------------------- ------------------------------------------
  **true**                     Historical records beyond the configured
                               retention period will be deleted

  **false**                    No records are deleted; the system runs in
                               **audit-only mode**
  -----------------------------------------------------------------------

Audit-only mode allows administrators to verify purge logic safely
before enabling deletes.

### Purge Date Field Name

Column used to determine record age (typically a snapshot run date such
as `RunDTS`).

### Purge Lookback Days

Number of days of history to retain.

Example: - Lookback Days = **90** - Any records **older than 90 days**
become eligible for purge.

------------------------------------------------------------------------

# 2. Purge Execution Process

The purge process is executed automatically through the data platform
using a PowerShell script.

The script: 1. Validates that the entity is configured for purge 2.
Executes the purge stored procedure 3. Logs the activity and execution
time

Execution occurs after the entity load process completes.

------------------------------------------------------------------------

# 3. PowerShell Execution

## Script Location

    G:\Databases\Staging\Scripts\PurgeHistoricalSnapshotData.ps1

## Execution Command

    PurgeHistoricalSnapshotData.ps1 -entityID <EntityID> -jobID <BatchID> -serverNM <ServerName>

Example:

    G:\Databases\Staging\Scripts\PurgeHistoricalSnapshotData.ps1 -entityID 43066 -jobID 302944 -serverNM localhost

## Parameters

### entityID

Identifies the entity associated with the snapshot table.

### jobID

Batch execution identifier used for logging and monitoring.

### serverNM

SQL Server instance where the purge stored procedure will run.

------------------------------------------------------------------------

# 4. Safety Controls

Several safeguards ensure purge operations remain controlled and
predictable.

## Configuration Validation

Before execution begins, the system verifies the entity exists in the
Snapshot Table Management configuration table.

If the entity is not configured, the script stops immediately.

## Audit‑Only Mode

If **Purge Data Flag = false**, the process:

-   Does **not delete data**
-   Logs what the delete statement **would have executed**
-   Allows administrators to validate behavior safely

## Controlled Batch Deletes

When purging is enabled, records are removed in **controlled batches**
to reduce locking and system impact.

## Full Logging

Every purge action generates log entries that include:

-   Table affected
-   Number of records removed
-   Retention cutoff date
-   Execution details

------------------------------------------------------------------------

# 5. Execution Logging

Purge activity is recorded within the platform event logging system.

Logged information includes:

-   Table name
-   Number of rows deleted
-   Retention cutoff date
-   Execution statements
-   Batch identifiers

This provides traceability and operational transparency for data
maintenance activities.

------------------------------------------------------------------------

# 6. Typical Workflow

### Step 1 -- Configure Table

Administrator adds a snapshot table in the **IDEA Snapshot Table
Management** interface.

### Step 2 -- Define Retention

Set: - Purge Date Field - Lookback Days

### Step 3 -- Validate in Audit Mode

Set **Purge Data Flag = false** and run the process to review logging
output.

### Step 4 -- Enable Purge

Once validated, set **Purge Data Flag = true**.

### Step 5 -- Automated Cleanup

The system automatically removes historical records during entity
processing.

------------------------------------------------------------------------

# 7. Benefits

This framework provides:

-   Centralized configuration
-   Safe validation mode
-   Controlled deletion behavior
-   Platform logging and traceability
-   Reduced storage growth for snapshot tables

------------------------------------------------------------------------

# Summary

The Historical Snapshot Purge framework combines the IDEA configuration
interface with automated execution through PowerShell and SQL
procedures.

Administrators maintain full control over retention policies while
ensuring historical snapshot tables remain optimized and manageable.
