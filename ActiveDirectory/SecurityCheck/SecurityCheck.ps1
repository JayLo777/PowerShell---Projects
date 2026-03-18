#Snapshot of security posture of Active Directory environment (privileged accounts, domain controllers, firewalls, etc.

$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportFolder = "C:\SecurityCheckReports"
$ReportPath = "$ReportFolder\SecurityCheckReport_$TimeStamp.csv"
$Results = @()

#Privileged Accounts Check

if (-not (Test-Path $ReportFolder)) {
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

try {
    if (Get-Command Get-ADGroupMember -ErrorAction SilentlyContinue) {
        $Admins = Get-ADGroupMember -Identity "Domain Admins" -ErrorAction Stop
        $Type = "Domain Admins"
    }
    else {
        $Admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
        $Type = "Local Administrators"
    }

    $AdminCount = ($Admins | Measure-Object).Count

    $Results += [PSCustomObject]@{
        Check   = "Privileged Accounts - $Type"
        Status  = "PASS"
        Details = "$AdminCount privileged accounts found."
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check   = "Privileged Accounts - Domain Admins"
        Status  = "FAIL"
        Details = "Could not retrieve privileged accounts"
    }
}

# -----

#Firewall Checks
try {
    $FirewallProfile = Get-NetFirewallProfile
    $DisabledProfiles = $FirewallProfile | Where-Object { $_.Enabled -eq $false }

    if ($DisabledProfiles.Count -eq 0) {
        $Results += [PSCustomObject]@{
            Check = "Firewall Status"
            Status = "PASS"
            Details = "All firewall profiles are enabled"
        }
    } 
    else {
        $Results += [PSCustomObject]@{
        Check = "Firewall Status"
        Status = "WARNING"
        Details = "One or more firewall profiles are disabled: $($DisabledProfiles.Name -join ', ')"
        }
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check = "Firewall Status"
        Status = "FAIL"
        Details = "Could not retrieve firewall status"
    }
}

#Antivirus Checks

try {
    $Antivirus = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
    if ($Antivirus) {
        $Results += [PSCustomObject]@{
            Check = "Antivirus Status"
            Status = "PASS"
            Details = "$Antivirus product detected: $($Antivirus.displayName)"

        }
    } 
    else {
        $Results += [PSCustomObject]@{
            Check = "Antivirus Status"
            Status = "FAIL"
            Details = "No antivirus product detected"
        }
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check   = "Antivirus"
        Status  = "FAIL"
        Details = "Could not retrieve antivirus status" 
    }
}

#Check Defender Status

try {
    $Defender = Get-MpComputerStatus
    if ($Defender.AntivirusEnabled -and $Defender.RealTimeProtectionEnabled) {
        $Results += [PSCustomObject]@{
            Check = "Windows Defender Status"
            Status = "PASS"
            Details = "Windows Defender is enabled and real-time protection is active"
        }
    } 
    else {
        $Results += [PSCustomObject]@{
            Check = "Windows Defender Status"
            Status = "WARNING"
            Details = "Windows Defender is either disabled or real-time protection is not active"
        }
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check = "Windows Defender Status"
        Status = "FAIL"
        Details = "Windows Defender status is unavailable"
    }
}

#Check User Account Control (UAC) Status

try {
    $UAC = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA"
    if ($UAC.EnableLUA -eq 1) {
        $Results += [PSCustomObject]@{
            Check = "User Account Control Status"
            Status = "PASS"
            Details = "UAC is enabled"
        }
    } 
    else {
        $Results += [PSCustomObject]@{
            Check = "User Account Control Status"
            Status = "WARNING"
            Details = "UAC is disabled-Potential security risk!"
        }
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check = "User Account Control Status"
        Status = "FAIL"
        Details = "Could not retrieve UAC status"
    }
}

#Output to Screen
$Results | Format-Table -AutoSize

#Save detailed Report to txt abd csv for further analysis

$TxtReport = "$ReportFolder\SecurityCheckReport_$TimeStamp.txt"
$CsvReport = "$ReportFolder\SecurityCheckReport_$TimeStamp.csv"

"Security Check Report - $env:COMPUTERNAME" | Out-File -FilePath $TxtReport
"Generated on: $(Get-Date)" | Out-File -FilePath $TxtReport -Append


$Results | Format-Table -AutoSize | Out-File -FilePath $TxtReport -Append

$Results | Export-Csv -Path $CsvReport -NoTypeInformation

#--On page Update--#
Write-host "`nReports saved to:"
Write-host "TXT: $TxtReport"
Write-host "CSV: $CsvReport"
