<#
.SYNOPSIS
Collect inventory and basic health information from Windows endpoints.

.DESCRIPTION
Reads computer names from a text file and collects Windows version, build number, uptime, disk free space, latest installed hotfix and SCCM pending update information.

The script uses WinRM first and falls back to DCOM if necessary.
Results are exported to a timestamped CSV report.

.PARAMETER ComputerListPath
Path to the text file containing the computer names.
Default: computers.txt in the script directory.

.PARAMETER LowDiskThresholdPercent
Free disk space percentage below which the disk status is marked as LOW.
Default: 10.

.PARAMETER LongUptimeThresholdDays
Number of uptime days above which uptime status is marked as LONG.
Default: 30.

.EXAMPLE
.\EndpointInventory.ps1

Runs the script with the default settings.

.EXAMPLE
.\EndpointInventory.ps1 -LowDiskThresholdPercent 15 -LongUptimeThresholdDays 20

Runs the script with custom disk space and uptime thresholds.

.EXAMPLE
.\EndpointInventory.ps1 -ComputerListPath ".\test-computers.txt"

Uses a custom computer list file.
#>

param(
	[string]$ComputerListPath = (Join-Path $PSScriptRoot "computers.txt"),

	[ValidateRange(1, 100)]
	[int]$LowDiskThresholdPercent = 10,

	[ValidateRange(1, 365)]
	[int]$LongUptimeThresholdDays = 30
)

$Computers = Get-Content $ComputerListPath |
	Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
	ForEach-Object { $_.Trim() }

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$ReportDirectory = Join-Path $PSScriptRoot "reports"

if (-not (Test-Path $ReportDirectory)) {
    New-Item -ItemType Directory -Path $ReportDirectory | Out-Null
}

$ReportFile = Join-Path $ReportDirectory "endpoint_inventory_$Timestamp.csv"

$Results = foreach ($Computer in $Computers) {

    $Session = $null
    $ConnectionMethod = "WinRM"

    try {

        # -------------------------------------------------
        # CONNECTION
        # First try WinRM, then fall back to DCOM
        # -------------------------------------------------

        try {
            $Session = New-CimSession `
                -ComputerName $Computer `
                -ErrorAction Stop
        }
        catch {
            $ConnectionMethod = "DCOM"

            $DcomOption = New-CimSessionOption -Protocol Dcom

            $Session = New-CimSession `
                -ComputerName $Computer `
                -SessionOption $DcomOption `
                -ErrorAction Stop
        }


        # -------------------------------------------------
        # OPERATING SYSTEM
        # -------------------------------------------------

        $OS = Get-CimInstance `
            -CimSession $Session `
            -ClassName Win32_OperatingSystem `
            -ErrorAction Stop


        # -------------------------------------------------
        # SYSTEM DISK
        # -------------------------------------------------

        $Disk = Get-CimInstance `
            -CimSession $Session `
            -ClassName Win32_LogicalDisk `
            -Filter "DeviceID='C:'" `
            -ErrorAction Stop

        if (-not $Disk) {
            throw "C: drive information could not be retrieved."
        }


        # -------------------------------------------------
        # UPTIME
        # -------------------------------------------------

        $UptimeDays = ((Get-Date) - $OS.LastBootUpTime).Days

        if ($UptimeDays -gt $LongUptimeThresholdDays) {
            $UptimeStatus = "LONG"
        }
        else {
            $UptimeStatus = "OK"
        }


        # -------------------------------------------------
        # DISK SPACE
        # -------------------------------------------------

        $FreeSpacePercent = [math]::Round(
            ($Disk.FreeSpace / $Disk.Size) * 100,
            1
        )

        if ($FreeSpacePercent -lt $LowDiskThresholdPercent) {
            $DiskStatus = "LOW"
        }
        else {
            $DiskStatus = "OK"
        }


        # -------------------------------------------------
        # LATEST INSTALLED HOTFIX
        # -------------------------------------------------

        $Hotfixes = Get-CimInstance `
            -CimSession $Session `
            -ClassName Win32_QuickFixEngineering `
            -ErrorAction SilentlyContinue

        $LatestHotfix = $Hotfixes |
            Where-Object { $_.InstalledOn } |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 1

        if ($LatestHotfix) {
            $LastHotfix = $LatestHotfix.HotFixID
            $LastHotfixDate = $LatestHotfix.InstalledOn
        }
        else {
            $LastHotfix = "N/A"
            $LastHotfixDate = "N/A"
        }


        # -------------------------------------------------
        # LEGACY WINDOWS DETECTION
        # Windows versions below 10.0 are marked as legacy
        # -------------------------------------------------

        if (([version]$OS.Version) -lt ([version]"10.0")) {
            $LegacyOS = "YES"
        }
        else {
            $LegacyOS = "NO"
        }


        # -------------------------------------------------
        # SCCM PENDING UPDATES
        # Only checked on modern Windows systems
        # -------------------------------------------------

        $PendingSccmUpdates = "N/A"
        $SccmUpdateStatus = "N/A"

        if ($LegacyOS -eq "YES") {

            $SccmUpdateStatus = "Legacy OS"
        }
        else {

            try {
                $Updates = @(
                    Get-CimInstance `
                        -CimSession $Session `
                        -Namespace "root\ccm\ClientSDK" `
                        -ClassName CCM_SoftwareUpdate `
                        -ErrorAction Stop
                )

                $PendingSccmUpdates = $Updates.Count

                if ($PendingSccmUpdates -eq 0) {
                    $SccmUpdateStatus = "OK"
                }
                else {
                    $SccmUpdateStatus = "PENDING"
                }
            }
            catch {
                $PendingSccmUpdates = "N/A"
                $SccmUpdateStatus = "Unavailable"
            }
        }


        # -------------------------------------------------
        # RESULT
        # -------------------------------------------------

        [PSCustomObject]@{
            ComputerName       = $Computer
            Status             = "Online"
            ConnectionMethod   = $ConnectionMethod

            Windows            = $OS.Caption
            Version            = $OS.Version
            Build              = $OS.BuildNumber
            LegacyOS           = $LegacyOS

            LastBoot           = $OS.LastBootUpTime
            UptimeDays         = $UptimeDays
            UptimeStatus       = $UptimeStatus

            DiskSizeGB         = [math]::Round($Disk.Size / 1GB, 2)
            FreeSpaceGB        = [math]::Round($Disk.FreeSpace / 1GB, 2)
            FreeSpacePercent   = $FreeSpacePercent
            DiskStatus         = $DiskStatus

            LastHotfix         = $LastHotfix
            LastHotfixDate     = $LastHotfixDate

            PendingSccmUpdates = $PendingSccmUpdates
            SccmUpdateStatus   = $SccmUpdateStatus

            Error              = ""
        }
    }

    catch {

        [PSCustomObject]@{
            ComputerName       = $Computer
            Status             = "Query failed"
            ConnectionMethod   = "N/A"

            Windows            = "N/A"
            Version            = "N/A"
            Build              = "N/A"
            LegacyOS           = "N/A"

            LastBoot           = "N/A"
            UptimeDays         = "N/A"
            UptimeStatus       = "N/A"

            DiskSizeGB         = "N/A"
            FreeSpaceGB        = "N/A"
            FreeSpacePercent   = "N/A"
            DiskStatus         = "N/A"

            LastHotfix         = "N/A"
            LastHotfixDate     = "N/A"

            PendingSccmUpdates = "N/A"
            SccmUpdateStatus   = "N/A"

            Error              = $_.Exception.Message
        }
    }

    finally {

        if ($Session) {
            Remove-CimSession $Session
        }
    }
}


# -------------------------------------------------
# OUTPUT
# -------------------------------------------------

$Results |
    Format-Table `
        ComputerName,
        Status,
        ConnectionMethod,
        Windows,
        Build,
        FreeSpacePercent,
        DiskStatus,
        UptimeDays,
        UptimeStatus,
        LastHotfix,
        PendingSccmUpdates,
        SccmUpdateStatus `
        -AutoSize


$Results | Export-Csv `
    -Path $ReportFile `
    -NoTypeInformation `
    -Encoding UTF8


Write-Host ""
Write-Host "Report saved to:"
Write-Host $ReportFile
