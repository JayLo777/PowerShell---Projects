#Security Check Report Script OnScreen.

#-----Routine Admin Accounts Check-----#
$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportFolder = ".\SecurityCheckReports"
$SvrRptTxt = "$ReportFolder\SecurityCheckReport_$TimeStamp.txt"
$SvrRptCsv = "$ReportFolder\SecurityCheckReport_$TimeStamp.csv"
$Results = @()

#Creates the report folder if it doesn't exist
$ReportFolder = ".\SecurityCheckReports"
if (-not (Test-Path $ReportFolder)) {     
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

#*Checks Priviliged Accounts
try {
    $Admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    $AdminCount = $Admins.Count
    $AdminNames = $Admins.Name -Join ', '

    if ($AdminCount -le 2) {
        $Status= "PASS"
    }
    else {
        $Status = "WARNING"
    }

$Results += [PSCustomObject]@{
        Check   = "Privileged Accounts - Local Administrators"
        Status  = $Status
        Details = "$AdminCount privileged accounts found: $AdminNames"
    }
}
catch {
    $Results += [PSCustomObject]@{
        Check   = "Privileged Accounts - Local Administrators"
        Status  = "FAIL"
        Details = "Could not retrieve privileged accounts"
    }
}


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
            Details = "$Antivirus product detected: $($Antivirus.displayName -join ',')"

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


#-----Go to the Security-Report to export the results to CSV, TXT, and HTML.-----#