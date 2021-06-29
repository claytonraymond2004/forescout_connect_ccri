<#
.SYNOPSIS
    Enumerates WiFi networks discovered by local computer and POSTs it to Forescout CCRI Connect App connect_ccri_wifiscan property

.DESCRIPTION
    USes netsh to find local WiFi networks and processes to get each BSSID and signal information, authenticates to Forescout Connect Web API, and then updates host data

.PARAMETER ip
    The IP of the host to update in Forescout (the device this is run on)

.PARAMETER api
    IP address of the Connect CCRI App API

.PARAMETER username
    Username for the Connect CCRI App API

.PARAMETER password
    Password for the Connect CCRI App API

.PARAMETER AttemptDelay
    Optional - How long between location polls to attempt, defaults to 1000 (msec)

.PARAMETER MaxAttempts
    Optional - How many times to try to get location, defaults to 30 (= 30 seconds total with defaults)
    
.SWITCH inseucre
    Will ignore certificate validation to Forescout Web API
#>

Param(
    [string]$ip = $(throw "-ip is required."),
    [string]$api = $(throw "-api is required."),
    [string]$username = $(throw "-username is required."),
    [string]$password = $(throw "-password is required."),
    [switch]$insecure = $false,
    [int]$AttemptDelay = 1000,
    [int]$MaxAttempts = 30
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

# Get location services
Add-Type -AssemblyName System.Device
$GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher
$GeoWatcher.Start() #Begin resolving current locaton
$Attempts = 0;

# Try to get location, wait until Ready, Denied, or timed out (30 seconds)
while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied') -and ($Attempts -lt $MaxAttempts)) {
    Start-Sleep -Milliseconds $AttemptDelay #Wait for discovery.
    $Attempts++;
}  

#Parsed location object
$Location = @{}
if ($GeoWatcher.Permission -eq 'Denied'){
    # Catch location denied
    Write-Error 'Access Denied for Location Information'
    exit
} elseif ($Attempts -ge $MaxAttempts) {
    # Catch timeout
    Write-Error "Timed out resolving location"
    exit
} else {
    # Process location data
    $Location.isUnknown = $GeoWatcher.Position.Location.isUnknown
    if($GeoWatcher.Position.Location.isUnknown -eq $false) {
        $Location.latitude =  "$($GeoWatcher.Position.Location.Latitude)"
        $Location.longitude =  "$($GeoWatcher.Position.Location.Longitude)"
        if (($GeoWatcher.Position.Location.Altitude -ge 0) -or ($GeoWatcher.Position.Location.Altitude -le 0)) { $Location.altitude =  "$($GeoWatcher.Position.Location.Altitude)" }
        if ($GeoWatcher.Position.Location.HorizontalAccuracy -ge 0) { $Location.hAccuracy =  "$($GeoWatcher.Position.Location.HorizontalAccuracy)" }
        if ($GeoWatcher.Position.Location.VerticalAccuracy -ge 0) { $Location.vAccuracy =  "$($GeoWatcher.Position.Location.VerticalAccuracy)" }
        if (($GeoWatcher.Position.Location.Speed -ge 0) -and (Double.isNaN($GeoWatcher.Position.Location.Speed) -eq $fals)) { $Location.speed =  "$($GeoWatcher.Position.Location.Speed)" }
        if ($GeoWatcher.Position.Location.Course -ge 0) { $Location.course =  "$($GeoWatcher.Position.Location.Course)" }
    }
    ConvertTo-Json -Compress $Location
}

# Get Connect Web API Token
try {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $body = "{`"username`": `"$username`", `"password`": `"$password`", `"app_name`": `"ccri`", `"expiration`": `"5`"}"
    $response = Invoke-RestMethod "https://$api/connect/v1/authentication/token" -Method 'POST' -Headers $headers -Body $body

    # POST to /hosts API To put data
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Bearer $($response.data.token)")
        $headers.Add("Accept", "application/json")
        $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_gpscoords`": $(ConvertTo-Json -Compress $Location) }}"
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
