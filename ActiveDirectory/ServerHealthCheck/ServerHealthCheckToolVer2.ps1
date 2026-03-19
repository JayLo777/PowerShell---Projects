#Update to ServerHealthCheckToolVer2

param(
    [string[]]$ComputerName = $env:COMPUTERNAME
)       
# Threshold values for CPU and Memory usage
$DiskWarningThreshold = 20
$DiskFailPercentage = 10
$MemoryWarningGB = 2
$UptimeWarningDays = 30

# Create a report folder if need
$ReportFolder = "C:\ServerHealthCheckReports"
if (-not (Test-Path -Path $ReportFolder)) {
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

$Results = foreach ($Computer in $ComputerName) {
    $target = if ([string]::IsNullOrWhiteSpace($Computer)) { $env:COMPUTERNAME } else { $Computer.Trim() }

    try {
        $isLocal = @($env:COMPUTERNAME, 'localhost', '.') -contains $target

        if ($isLocal) {
            $os = Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Stop
            $ComputerSystem = Get-CimInstance -Class Win32_ComputerSystem -ErrorAction Stop
            $MemoryModules = Get-CimInstance -Class Win32_PhysicalMemory -ErrorAction Stop
            $disks = Get-CimInstance -Class Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        }
        else {
            $os = Get-CimInstance -Class Win32_OperatingSystem -ComputerName $target -ErrorAction Stop
            $ComputerSystem = Get-CimInstance -Class Win32_ComputerSystem -ComputerName $target -ErrorAction Stop
            $MemoryModules = Get-CimInstance -Class Win32_PhysicalMemory -ComputerName $target -ErrorAction Stop
            $disks = Get-CimInstance -Class Win32_LogicalDisk -ComputerName $target -Filter "DriveType=3" -ErrorAction Stop
        }

        $LastBootUpTime = $os.LastBootUpTime
        $Uptime = (Get-Date) - $LastBootUpTime

        $totalMemory = [math]::round(($MemoryModules.Capacity | Measure-Object -Sum).Sum / 1GB, 2)
        $freeMemory = [math]::round((($os.FreePhysicalMemory * 1KB) / 1GB), 2)
        $usedMemory = [math]::round($totalMemory - $freeMemory, 2)

        if ($freeMemory -lt $MemoryWarningGB) {
            $MemoryStatus = "Warning: Free Memory is below $MemoryWarningGB GB!"
        }
        else {
            $MemoryStatus = "Healthy: Free Memory is above $MemoryWarningGB GB."       
        }
        if ($Uptime.Days -gt $UptimeWarningDays) {
            $UptimeStatus = "Warning: Uptime is above $UptimeWarningDays days!"
        }
        else {
            $UptimeStatus = "Healthy: Uptime is within normal limits."       
        }
        if (-not $disks) {
            [PSCustomObject]@{
                ComputerName = $ComputerSystem.Name
                OSName = $os.Caption
                OSVersion = $os.Version
                LastBootTime = $LastBootUpTime
                Uptime = $Uptime.Days
                UptimeHours = $Uptime.Hours
                UptimeStatus = $UptimeStatus
                DriveLetter = "N/A"
                TotalDiskGB = "N/A"
                FreeDiskGB = "N/A"
                UsedDiskGB = "N/A"
                FreeDiskPercentage = "N/A"
                DiskStatus = "Warning: No fixed disks returned."
                TotalMemoryGB = $totalMemory
                UsedMemoryGB = $usedMemory
                FreeMemoryGB = $freeMemory
                MemoryStatus = $MemoryStatus
            }
            continue
        }

        foreach ($disk in $disks) {
                $totalDiskGB = [math]::round($disk.Size / 1GB, 2)
                $freeDiskGB = [math]::round($disk.FreeSpace / 1GB, 2)
                $usedDiskGB = [math]::round($totalDiskGB - $freeDiskGB, 2)

                if ($totalDiskGB -le 0) {
                    $freeDiskPercentage = 0
                }
                else {
                    $freeDiskPercentage = [math]::round(($freeDiskGB / $totalDiskGB) * 100, 2)
                }

                if ($freeDiskPercentage -lt $DiskFailPercentage) {
                    $DiskStatus = "Fail: Free Disk space is below $DiskFailPercentage%!"
                }
                elseif ($freeDiskPercentage -lt $DiskWarningThreshold) {
                    $DiskStatus = "Warning: Free Disk space is below $DiskWarningThreshold%!"
                }
                else {
                    $DiskStatus = "Healthy: Free Disk space is within normal limits."
                }
                [PSCustomObject]@{
                    ComputerName = $ComputerSystem.Name
                    OSName = $os.Caption
                    OSVersion = $os.Version
                    LastBootTime = $LastBootUpTime
                    Uptime = $Uptime.Days
                    UptimeHours = $Uptime.Hours                    
                    UptimeStatus = $UptimeStatus
                    DriveLetter = $disk.DeviceID
                    TotalDiskGB = $totalDiskGB
                    FreeDiskGB = $freeDiskGB 
                    UsedDiskGB = $usedDiskGB
                    FreeDiskPercentage = $freeDiskPercentage
                    DiskStatus = $DiskStatus
                    TotalMemoryGB = $totalMemory
                    UsedMemoryGB = $usedMemory
                    FreeMemoryGB = $freeMemory             
                    MemoryStatus = $MemoryStatus
                }
        }
}
    catch {
        [PSCustomObject]@{
                ComputerName = $target
                OSName = "N/A"
                OSVersion = "N/A"
                LastBootTime = "N/A"
                Uptime = "N/A"
                UptimeHours = "N/A"
                UptimeStatus = "FAIL"
                DriveLetter = "N/A"
                TotalDiskGB = "N/A"
                FreeDiskGB = "N/A"
                UsedDiskGB = "N/A"
                FreeDiskPercentage = "N/A"
                DiskStatus = "FAIL"
                TotalMemoryGB = "N/A"
                UsedMemoryGB = "N/A"
                FreeMemoryGB = "N/A"
                MemoryStatus = "FAIL"
                ErrorMessage = $_.Exception.Message
        }
    }   
}
#Display the results on Screen
$Results | Format-Table -AutoSize
