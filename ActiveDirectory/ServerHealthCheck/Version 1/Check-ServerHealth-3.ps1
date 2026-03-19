<#Version 3 of the Server Health Check script. This version includes error handling, checks for multiple disks, and generates an HTML report.
This script is designed to check the health of one or more computers and report on:

Operating system info
Uptime
Memory usage
Disk space
Health status
Error handling
Optional HTML report switch

Avition explanation:
Think of this script like a maintenance inspection on an aircraft.
Before a flight, you check fuel, engine condition, warning lights, and system status.

This script does the same thing for computers:
-Memory is like available fuel
-Disk space is like storage capacity
-Uptime is how long the aircraft has been flying without shutdown or maintenance
-Error handling is what keeps the inspection going even if one aircraft has a problem

#>
<# Step 1: Accept one or more computer names.
If no name is provided, use the local computer.#>
#Enable-PSRemoting -Force allows the script to run on remote computers. 

#Enable-PSRemoting -Force<<<<<<<<Use if it dont work>>>>

param(
    [string[]]$ComputerName= $env:COMPUTERNAME,
    [switch]$FromAD,
    [switch]$ExportHtml
)
if ($FromAD) {
    try{
        $ComputerName = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
}
    catch {
        Write-Host "Failed to retrieve computer names from Active Directory." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        return
    }
}
# Step 2: Define threshold values for memory and disk usage.
$DiskWarningPercent = 20
$DiskFailPercentage = 10
$MemoryWarningGB = 2
$UptimeWarningDays = 30

# Step 3: Create a report folder if it does not already exist.

$ReportFolder = "C:\ServerHealthReports"
if (-not (Test-Path -Path $ReportFolder)) {
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

# Step 4: Loop through each computer in the ComputerName parameter.
$Results = foreach ($Computer in $ComputerName) {
    try {
# Step 5: Use Get-CimInstance to retrieve system information for each computer.
    $os = Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Stop
    $computerSystem = Get-CimInstance -Class Win32_ComputerSystem -ErrorAction Stop
    $MemoryModules = Get-CimInstance -Class Win32_PhysicalMemory -ErrorAction Stop
    $disks = Get-CimInstance -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType=3" -ErrorAction Stop
    
    # Step 6: Calculate uptime from the last boot time.
    $LastBootUpTime = $os.LastBootUpTime
    $Uptime = (Get-Date) - $LastBootUpTime

    # step 7: Calculate memory in GB.
    $totalMemory = [math]::round(($MemoryModules.Capacity | Measure-Object -Sum).Sum / 1GB, 2)
    $freeMemory = [math]::round((($os.FreePhysicalMemory * 1KB) / 1GB), 2)
    $usedMemory = [math]::round($totalMemory - $freeMemory, 2)

    # Step 8: Calculate free memory in GB against threshold.
        if ($freeMemory -lt $MemoryWarningGB) {
            $MemoryStatus = "WARNING"  
        }
        else {
            $MemoryStatus = "PASS"
        }
        # Step 9: Compare uptime in days against threshold.
        if ($Uptime.Days -gt $UptimeWarningDays) {
            $UptimeStatus = "WARNING" 
        }
        elseif ($Uptime.Days -lt $UptimeWarningDays) {
            $UptimeStatus = "PASS"
        }
    # Step 10: Loop through each disk and calculate free space in GB against threshold.
    foreach ($disk in $disks) {
        $totalDiskGB = [math]::round($disk.Size / 1GB, 2)
        $freeDisk = [math]::round($disk.FreeSpace / 1GB, 2)
        $usedDisk = [math]::round($totalDiskGB - $freeDisk, 2)
        $freeDiskPercent = [math]::round(($freeDisk / $totalDiskGB) * 100, 2)
        
        # Step 11: Evaluate disk health using threshold values.    
        if ($freeDiskPercent -lt $DiskFailPercentage) {
            $DiskStatus = "Warning: Disk $($disk.DeviceID) free space is below $DiskFailPercentage%!"
        }
        elseif ($freeDiskPercent -lt $DiskWarningPercent) {
            $DiskStatus = "Warning: Disk $($disk.DeviceID) free space is below $DiskWarningPercent%!"
        }
        else {
            $DiskStatus = "Healthy: Disk $($disk.DeviceID) free space is above $DiskWarningPercent%."
        }
        
        # Step 12: Create a custom object to store the results for each computer and add it to a collection.
        [PSCustomObject]@{
            ComputerName = $computerSystem.Name
            OSName = $os.Caption
            OSVersion = $os.Version
            LastBootTime = $LastBootUpTime
            UptimeDays =  $Uptime.Days
            UptimeHours = $Uptime.Hours
            Drive = $disk.DeviceID
            TotalDiskGB = $totalDiskGB
            FreeDiskGB = $freeDisk
            UsedDiskGB = $usedDisk
            FreeDiskPercent = $freeDiskPercent
            TotalMemoryGB = $totalMemory
            freeMemoryGB = $freeMemory
            UsedMemoryGB = $usedMemory
            MemoryStatus = $MemoryStatus
            UptimeStatus = $UptimeStatus
            DiskStatus = $DiskStatus
        }
    }
}
# Step 13: If data collection fails return results with the following
    catch {
        Write-Host "Failed to retrieve data for computer: $Computer" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        [PSCustomObject]@{
            ComputerName = $Computer
            OSName = "N/A"
            OSVersion = "N/A"
            LastBootTime = "N/A"
            UptimeDays = "N/A"
            UptimeHours = "N/A"
            Drive = "N/A"
            TotalDiskGB = "N/A"
            FreeDiskGB = "N/A"
            UsedDiskGB = "N/A"
            FreeDiskPercent = "N/A"
            TotalMemoryGB = "N/A"
            freeMemoryGB = "N/A"
            UsedMemoryGB = "N/A"
            MemoryStatus = "Fail"
            UptimeStatus = "Fail"
            DiskStatus = "Fail."
        }
    } 
}

#Step 14: Output the results to the console in table.
$Results | Format-Table -AutoSize

Write-Host "Computer Name: $($computerSystem.Name)"
Write-Host "Operating System: $($os.Caption) $($os.OSArchitecture)"
Write-Host "OS Version: $($os.Version)"
Write-Host "last Boot Time: $($os.LastBootUpTime)"
Write-Host "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
Write-Host ""
Write-Host "Memory Status:"
Write-Host "  Free: $freeMemory GB"
Write-Host "  Used: $usedMemory GB"
Write-Host "  Total: $totalMemory GB"
Write-Host ""
Write-Host "Disk Status (C:):"
Write-Host "  Free: $freeDisk GB"
Write-Host "  Used: $usedDisk GB"
Write-Host "  Total: $totalDisk GB"
Write-Host ""
Write-Host "CPU: $($cpu.Name)"
Write-Host "CPU Load: $($cpu.LoadPercentage)%"

if ($memoryUsagePercentage -gt 90) {
    Write-Host "Fail: Disk usage is Critically High 90%!" -ForegroundColor Red
    $DiskStatus = "Fail: Disk usage is Critically High!"   
}
elseif ($DiskFailPercentage -ge 80) {
    Write-Host "Warning: Disk usage is High 80%!" -ForegroundColor Yellow
    $DiskStatus = "Warning: Disk usage is High!"   
}
else {
    Write-Host "PASS: Memory Healthy." -ForegroundColor Green
}
if ($diskUsagePercentage -gt 90) {
    Write-Host "Warning: Disk usage is above 90%!" -ForegroundColor Red
}
else {
    Write-Host "PASS: Disk usage is within normal limits." -ForegroundColor Green
}
