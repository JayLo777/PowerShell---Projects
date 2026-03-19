#<The Script will provide a snapshot of the health of a server and return the results. 

$os = Get-CimInstance -Class Win32_OperatingSystem 
$computerSystem = Get-CimInstance -Class Win32_ComputerSystem
$cpu = Get-CimInstance -Class Win32_Processor
$memory = Get-CimInstance -Class Win32_PhysicalMemory
$disk = Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='C:'"

$lastboot = $os.LastBootUpTime
$uptime = (Get-Date) - $lastboot

$totalMemory =  [math]::round(($memory.Capacity | Measure-Object -Sum).Sum / 1GB, 2)
$freeMemory  =  [math]::round(($os.FreePhysicalMemory / 1MB), 2)
$usedMemory  =  [math]::round($totalMemory - $freeMemory, 2)

$totalDisk =  [math]::round(($disk.Size | Measure-Object -Sum).Sum / 1GB, 2)
$freeDisk  =  [math]::round(($disk.FreeSpace | Measure-Object -Sum).Sum / 1GB, 2)
$usedDisk  =  [math]::round($totalDisk - $freeDisk, 2)

$cpuLoad = $cpu.LoadPercentage

#Creates the report folder if it doesn't exist
$ReportFolder = ".\ServerHealthReports"
if (-not (Test-Path $ReportFolder)) {     
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

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
    Write-Host "Warning: Memory usage is above 90%!" -ForegroundColor Red
}
else {
    Write-Host "Healthy: Memory usage is within normal limits." -ForegroundColor Green
}
if ($diskUsagePercentage -gt 90) {
    Write-Host "Warning: Disk usage is above 90%!" -ForegroundColor Red
}
else {
    Write-Host "Healthy: Disk usage is within normal limits." -ForegroundColor Green
}

