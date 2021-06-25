<#
.SYNOPSIS
    Gets Windows device serial number and POSTs it to Forescout CCRI Connect App connect_ccri_serialnumber property

.DESCRIPTION
    Grabs serial number from WMI, authenticates to Forescout Connect Web API, and then updates host data

.PARAMETER ip
    The IP of the host to update in Forescout (the device this is run on)

.PARAMETER api
    IP address of the Connect CCRI App API

.PARAMETER username
    Username for the Connect CCRI App API

.PARAMETER password
    Password for the Connect CCRI App API
    
.SWITCH inseucre
    Will ignore certificate validation to Forescout Web API

#>
Param(
    [string]$ip = $(throw "-ip is required."),
    [string]$api = $(throw "-api is required."),
    [string]$username = $(throw "-username is required."),
    [string]$password = $(throw "-password is required."),
    [switch]$insecure = $false
)

# Create type for ignoring certs if specified
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
# Disable Certificate Validation in Powershell if specified
if ($insecure -eq $true) {
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# Get system BIOS info for computer serial number
$biosData = Get-WmiObject win32_bios
Write-Host "System Serial Number: $($biosData["SerialNumber"])"

# Get phyiscal media info for hard drive serial numbers
$physicalMedia = Get-WMIObject win32_physicalmedia
$mediaSerials = @()
foreach ($drive in $physicalMedia) {
    $mediaSerials += @{media_tag = $drive.Tag; serial_number = $drive.SerialNumber}
}
Write-Host "Media Serial Numbers: $(ConvertTo-Json -Compress $mediaSerials)"

# Get Connect Web API Token
try {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $body = "{`"username`": `"$username`", `"password`": `"$password`", `"app_name`": `"ccri`", `"expiration`": `"1`"}"
    $response = Invoke-RestMethod "https://$api/connect/v1/authentication/token" -Method 'POST' -Headers $headers -Body $body

    # POST to /hosts API To put data
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Bearer $($response.data.token)")
        $headers.Add("Accept", "application/json")
        $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_serialnumber`":`"$($biosData["SerialNumber"])`", `"connect_ccri_mserialnumber`": $(ConvertTo-Json -Compress $mediaSerials) }}"
        $response = Invoke-RestMethod "https://$api/connect/v1/hosts" -Method 'POST' -Headers $headers -Body $body
    } catch {
        # Error POSTing Data
        Write-Error "Forescout Connect ccri App API POST Error"
        Write-Error $_
    }

} catch {
    # Error authenticating
    Write-Error "Forescout Connect API Auth Error"
    Write-Error $_
}
