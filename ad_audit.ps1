#___READ JSON___
# create path to json file
#.\ means current calatog, ad_export.json is in the same folder asad_audit.ps1
$jsonPath = ".\ad_export.json"

# Get-Content: read the content of json file
# -Path $jsonPath: points to the file
# Raw: read file as a text, not lines
$jsonText = Get-Content -Path $jsonPath -Raw -Encoding UTF8

# pipeline | transfer the content of $jsonText to the following command
# Converting json to PowerShell using ConvertFrom
$data = $jsonText | ConvertFrom-Json


#___DISPLAY DOMAIN NAME & EXPORT DATE___
# retrieve info from JSON: $data.domain and $data.export_date
# $(): process data within ()
Write-Host "Domain: $($data.domain)"
Write-Host "Export Date: $($data.export_date)"


#___LIST INACTIVE USERS___
# calculate date from 30 days ago; Get-Date: is the current date
$thirtyDaysAgo = (Get-Date).AddDays(-30)

# filter users not logged in for +30 days
# $data.users: list of users in JSON; Where-Object {}: apply filter according to {condition}; -lt: less than
$inactiveUsers = $data.users | Where-Object { [datetime]$_.lastLogon -lt $thirtyDaysAgo
}

# Display inactive users: account name, display name, inactive days
# `n: add new line
Write-Host "`n Inactive users:"

# `t add TAB
# subtract [datetime]$user.lastLogon from (Get-Date)
foreach ($user in $inactiveUsers) {
    $daysInactive = ((Get-Date) - [datetime]$user.lastLogon).Days
    Write-Host "$($user.samAccountName)`t$($user.displayName)`t$daysInactive days"
}
# pipeline command: export samAccountName, displayName, lastLogon from $inactive Users into inactive_users.csv
$inactiveUsers | Select-Object samAccountName, displayName, lastLogon | Export-Csv -Path "inactive_users.csv"


#___NO. USERS PER DEPARTMENT___
# create empty dictionary
$departmentCount = @{}

# loop through users; if $dept key exists, add 1 to counter
# if $dept not present, create new key with value 1
foreach ($user in $data.users) {
    $dept = $user.department
    if ($departmentCount.ContainsKey($dept)) {
        $departmentCount[$dept]++
    }
    else {
        $departmentCount[$dept] = 1
    }
}
# .Keys returns a list of department names (keys)
Write-Host "`n Users per department:"
foreach ($dept in $departmentCount.Keys) {
    Write-Host "$dept :$($departmentCount[$dept]) users"
}


#___GROUPING COMPUTERS___
# Group-Objest: grouping elements by the 'site' value in json
$groupedComputers = $data.computers | Group-Object -Property site

foreach ($group in $groupedComputers) {
    Write-Host "$($group.Name) has $($group.Count) computers"
}


# ___PASSWORD AGE___
Write-Host "`n Days since last password update of users:"
# pipeline: convert last password change date [datetime]$_.passwordLastSet of
# every user ForEach-Object, and subtracts from current date (Get-Date), creates custom
# object[PSCustomObject]@{} containing SamAccountName, DisplayName, PasswordAgeDays, and
# displays values in a table
$data.users  | ForEach-object {
    $passwordAge = (Get-Date) - [datetime]$_.passwordLastSet
    [PSCustomObject]@{
        SamAccountName  = $_.samAccountName
        DisplayName     = $_.displayName
        PasswordAgeDays = [math]::Round($passwordAge.TotalDays, 0)
    }
} | Format-Table


#___OLDEST LOGIN___
Write-Host "`n Devices with oldest logons:"
$top10OldCOmputers = $data.computers | Sort-Object { [datetime]$_.lastLogon } | Select-Object -First 10
$top10OldCOmputers | Select-Object name, site, lastLogon | Format-Table