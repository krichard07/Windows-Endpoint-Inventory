# Windows Endpoint Inventory

A PowerShell-based endpoint inventory and health-check tool for collecting system information from multiple Windows computers.

The script is designed for mixed Windows environments where different remote management methods may be required. It first attempts a standard WinRM/CIM connection and automatically falls back to DCOM if WinRM is unavailable.

The tool performs read-only queries and exports the collected information to timestamped CSV reports.

## Features

- Reads computer names from a configurable input file
- Queries multiple Windows endpoints
- WinRM connection with automatic DCOM fallback
- Windows edition, version and build information
- Legacy Windows detection
- Last boot time and uptime calculation
- Configurable long-uptime warning threshold
- System drive size and free disk space
- Configurable low-disk-space warning threshold
- Latest installed hotfix and installation date
- SCCM pending software update count where available
- Per-computer error handling
- Automatic CIM session cleanup
- Timestamped CSV reports
- Built-in PowerShell help with usage examples

## Example Output

The repository contains a synthetic example report:

`sample-output/endpoint_inventory_sample.csv`

The sample data does not contain information from any real production environment.

It demonstrates several possible results, including:

- successful WinRM connection
- DCOM fallback
- low disk space
- long uptime
- pending SCCM updates
- legacy Windows
- failed remote query

## Requirements

- Windows PowerShell
- Appropriate permissions to remotely query target computers
- WinRM or DCOM remote access
- SCCM client for SCCM-specific update information

SCCM is optional. If the SCCM ClientSDK namespace is unavailable, the script continues and reports the SCCM update status as unavailable.

## Usage

Create a file named:

`computers.txt`

Use `computers.example.txt` as a template:

```text
DEMO-PC-01
DEMO-PC-02
DEMO-PC-03
```

Place one computer name on each line.

Run the script with the default settings:

```powershell
.\EndpointInventory.ps1
```

By default, the script:

- reads computer names from `computers.txt`
- marks disk space as `LOW` below 10% free space
- marks uptime as `LONG` above 30 days
- saves the generated CSV report to the `reports` directory

## Parameters

### ComputerListPath

Specifies the path to the text file containing the target computer names.

Default:

```text
computers.txt
```

Example:

```powershell
.\EndpointInventory.ps1 -ComputerListPath ".\test-computers.txt"
```

### LowDiskThresholdPercent

Specifies the free disk space percentage below which the disk status is marked as `LOW`.

Default:

```text
10
```

Example:

```powershell
.\EndpointInventory.ps1 -LowDiskThresholdPercent 15
```

### LongUptimeThresholdDays

Specifies the number of uptime days above which the uptime status is marked as `LONG`.

Default:

```text
30
```

Example:

```powershell
.\EndpointInventory.ps1 -LongUptimeThresholdDays 20
```

Multiple parameters can also be used together:

```powershell
.\EndpointInventory.ps1 -LowDiskThresholdPercent 15 -LongUptimeThresholdDays 20
```

## Built-in Help

The script includes PowerShell comment-based help.

Display the full help:

```powershell
Get-Help .\EndpointInventory.ps1 -Full
```

Display usage examples:

```powershell
Get-Help .\EndpointInventory.ps1 -Examples
```

## Reports

Reports are created automatically in:

```text
reports/
```

Each report uses a timestamped filename so previous inventory results are not overwritten.

## Inventory Fields

The generated CSV includes:

- `ComputerName`
- `Status`
- `ConnectionMethod`
- `Windows`
- `Version`
- `Build`
- `LegacyOS`
- `LastBoot`
- `UptimeDays`
- `UptimeStatus`
- `DiskSizeGB`
- `FreeSpaceGB`
- `FreeSpacePercent`
- `DiskStatus`
- `LastHotfix`
- `LastHotfixDate`
- `PendingSccmUpdates`
- `SccmUpdateStatus`
- `Error`

## SCCM Update Status

For supported Windows systems, the script queries:

```text
root\ccm\ClientSDK
CCM_SoftwareUpdate
```

`PendingSccmUpdates` represents software updates currently reported as applicable by the SCCM client.

An `SccmUpdateStatus` value of `OK` means that the SCCM client returned zero applicable pending updates.

It should not be interpreted as a complete Windows Update compliance assessment.

## Error Handling

Failures are handled independently for each endpoint.

If one computer cannot be queried, the script records the failure in the CSV report and continues processing the remaining computers.

This allows inventory collection to continue even when individual endpoints are offline, unreachable, or unavailable through the configured remote management methods.

## Safety

The script performs read-only inventory and diagnostic queries.

It does not:

- install updates
- modify remote system settings
- restart computers
- change Windows services
- modify the registry
- enable WinRM or DCOM

## Privacy

Real computer names and generated production reports are excluded through `.gitignore`.

Only synthetic example data is included in the public repository.
