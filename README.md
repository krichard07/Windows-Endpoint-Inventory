# Windows Endpoint Inventory

A PowerShell-based endpoint inventory tool for collecting system information from multiple Windows computers.

The script is designed for mixed Windows environments where different remote management methods may be required. It first attempts a standard WinRM/CIM connection and automatically falls back to DCOM if WinRM is unavailable.

## Features

- Reads computer names from an input file
- Queries multiple Windows endpoints
- WinRM connection with automatic DCOM fallback
- Windows edition, version and build information
- Legacy Windows detection
- Last boot time and uptime calculation
- Configurable long-uptime warning
- System drive size and free disk space
- Configurable low-disk-space warning
- Latest installed hotfix and installation date
- SCCM pending software update count where available
- Per-computer error handling
- Automatic CIM session cleanup
- Timestamped CSV reports

## Example Output

The repository contains a synthetic example report:

`sample-output/endpoint_inventory_sample.csv`

The sample data does not contain information from any real production environment.

It demonstrates:

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

Run the script:

```powershell
.\EndpointInventory.ps1
```

Reports are created automatically in:

```text
reports/
```

## Inventory Fields

The generated CSV includes:

- ComputerName
- Status
- ConnectionMethod
- Windows
- Version
- Build
- LegacyOS
- LastBoot
- UptimeDays
- UptimeStatus
- DiskSizeGB
- FreeSpaceGB
- FreeSpacePercent
- DiskStatus
- LastHotfix
- LastHotfixDate
- PendingSccmUpdates
- SccmUpdateStatus
- Error

## Thresholds

The default thresholds are defined at the beginning of the script:

```powershell
$LowDiskThresholdPercent = 10
$LongUptimeThresholdDays = 30
```

These values can be changed as required.

## SCCM Update Status

For supported Windows systems, the script queries:

```text
root\ccm\ClientSDK
CCM_SoftwareUpdate
```

`PendingSccmUpdates` represents software updates currently reported as applicable by the SCCM client.

An `SccmUpdateStatus` value of `OK` means that the SCCM client returned zero applicable pending updates.

It should not be interpreted as a complete Windows Update compliance assessment.

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
