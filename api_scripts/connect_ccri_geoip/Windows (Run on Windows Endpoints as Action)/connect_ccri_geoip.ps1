<#
.SYNOPSIS
    Gets the computer external IP GeoIP info and POSTs it to Forescout CCRI Connect App connect_ccri_wifiscan property

.DESCRIPTION
    Uses ip-api.com to get GeoIP information about the external IP, authenticates to Forescout Connect Web API, and then updates host data

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

# Get data from ip-api.com and process
$GeoIP = @{}
try {
    $GeoIPRaw = Invoke-RestMethod "http://ip-api.com/json?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,reverse,mobile,proxy,hosting,query"
} catch {
    # Error getting Data
    Write-Error "Couldn't get GeoIP data from ip-api.com"
    Write-Error $_
    exit
}

# Disable Certificate Validation in Powershell if specified
if ($insecure -eq $true) {
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# Process location data
$GeoIP.status = $GeoIPRaw.status
$GeoIP.country = $GeoIPRaw.country
$GeoIP.countryCode = $GeoIPRaw.countryCode
$GeoIP.region = $GeoIPRaw.region
$GeoIP.regionName = $GeoIPRaw.regionName
$GeoIP.city = $GeoIPRaw.city
$GeoIP.zip = $GeoIPRaw.zip
$GeoIP.lat = "$($GeoIPRaw.lat)" #convert float to string
$GeoIP.lon = "$($GeoIPRaw.lon)" #convert float to string
$GeoIP.timezone = $GeoIPRaw.timezone
$GeoIP.isp = $GeoIPRaw.isp
$GeoIP.org = $GeoIPRaw.org
$GeoIP.as = $GeoIPRaw.as
$GeoIP.asname = $GeoIPRaw.asname
$GeoIP.reverse = $GeoIPRaw.reverse
$GeoIP.mobile = $GeoIPRaw.mobile
$GeoIP.proxy = $GeoIPRaw.proxy
$GeoIP.hosting = $GeoIPRaw.hosting
$GeoIP.query = $GeoIPRaw.query

ConvertTo-Json -Compress $GeoIP

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
        $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_geoip`": $(ConvertTo-Json -Compress $GeoIP) }}"
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