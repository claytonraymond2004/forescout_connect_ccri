<#
.SYNOPSIS
    Gets Windows device serial number and POSTs it to Forescout CCRI Connect App connect_ccri_serialnumber property

.DESCRIPTION
    Grabs serial number from WMI, authenticates to Forescout Connect Web API, and then updates host data
    Run with: ccri_post_win_serialnumber.ps1 -ip {ip} -api <connect_api_ip> -username <connect_api_username> -password <connect_api_password>

.PARAMETER ip
    The IP of the host to update in Forescout (the device this is run on)

.PARAMETER api
    IP address of the Connect CCRI App API

.PARAMETER username
    Username for the Connect CCRI App API

.PARAMETER password
    Password for the Connect CCRI App API

#>
Param(
    [string]$ip = $(throw "-ip is required."),
    [string]$api = $(throw "-api is required."),
    [string]$username = $(throw "-username is required."),
    [string]$password = $(throw "-password is required.")
)

# Get system BIOS info
$biosData = Get-WmiObject win32_bios
Write-Host $biosData["SerialNumber"]

# Get Connect Web API Token
try {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $body = "{`"username`": `"$username`", `"password`": `"$password`", `"app_name`": `"ccri`", `"expiration`": `"1`"}"
    $response = Invoke-RestMethod "https://$api/connect/v1/authentication/token" -Method 'POST' -Headers $headers -Body $body

    # POST to /hosts API To put data
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "Bearer $($response.data.token)")
    $headers.Add("Accept", "application/json")
    $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_serialnumber`":`"$($biosData["SerialNumber"])`" }}"
    $response = Invoke-RestMethod "https://$api/connect/v1/hosts" -Method 'POST' -Headers $headers -Body $body

} catch {
    # Error authenticating
    Write-Error "Forescout Connect API Auth error - StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Error "Forescout Connect API Auth error - StatusDescription:" $_.Exception.Response.StatusDescription
}
