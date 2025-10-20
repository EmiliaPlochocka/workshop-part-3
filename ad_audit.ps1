#___READ JSON___
# create path to json file
$jsonPath = ".\ad_export.json"
# read file as text
# Get-Content reads the content of json file
$jsonText = Get-Content -Path $jsonPath -Raw -Encoding UTF8
# Converting json to PowerShell using ConvertFrom
$data = $jsonText | ConvertFrom-Json

#___DISPLAY DOMAIN NAME & EXPORT DATE___
# retrieve info from JSON: domain and export_date
Write-Host "Domain: $($data.domain)"
Write-Host "Export Date: $($data.export_date)"

#___LIST INACTIVE USERS___
# calculate date from 30 days ago
$thirtyDaysAgo = (Get-Date).AddDays(-30)
# filter users not logged in for +30 days
$inactiveUsers = $data.users | Where-Object { [datetime]$_.lastLogon -lt $thirtyDaysAgo
}
# Display inactive users: account name, display name, inactive days
# `t adds a TAB
Write-Host "`n Inactive users:"
foreach ($user in $inactiveUsers) {
    $daysInactive = ((Get-Date) - [datetime]$user.lastLogon).Days
    Write-Host "$($user.samAccountName)`t$($user.displayName)`t$daysInactive days"
}
$inactiveUsers | Select-Object samAccountName, displayName, lastLogon | Export-Csv -Path "inactive_users.csv"

#___NO. USERS PER DEPARTMENT___
# create empty counter
$departmentCount = @{}
foreach ($user in $data.users) {
    $dept = $user.department
    if ($departmentCount.ContainsKey($dept)) {
        $departmentCount[$dept]++
    }
    else {
        $departmentCount[$dept] = 1
    }
}
Write-Host "`n Users per department:"
foreach ($dept in $departmentCount.Keys) {
    Write-Host "$dept :$($departmentCount[$dept]) users"
}

#___GROUPING COMPUTERS___
# grouping computers by the 'site' value in json
$groupedComputers = $data.computers | Group-Object -Property site

foreach ($group in $groupedComputers) {
    Write-Host "$($group.Name) has $($group.Count) computers"
}

# ___PASSWORD AGE___
$data.users  | ForEach-object {
    $passwordAge = (Get-Date) - [datetime]$_.passwordLastSet
    [PSCustomObject]@{
        SamAccountName  = $_.samAccountName
        DisplayName     = $_.displayName
        PasswordAgeDays = [math]::Round($passwordAge.TotalDays, 0)
    }
} | Format-Table

#___OLDEST LOGIN___
$top10OldCOmputers = $data.computers | Sort-Object { [datetime]._.lastLogon } | Select-Object -First 10
$top10OldCOmputers | Select-Object name, site, lastLogon | Format-Table