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

# Get Wifi networks from windows
$WiFi = (netsh wlan show network  mode=bssid |  Select-Object -Skip  3).Trim()  | Out-String

# Regex for parsing data -- lump all the BSSIDs in a property we'll expand out later
$NetRegEx = @'
(?smi)SSID \d+ :(?<SSID>[^\r\n]*)
Network type\s+: (?<NetworkType>[^\r\n]+)
Authentication\s+: (?<Authentication>[^\r\n]+)
Encryption\s+: (?<Encryption>[^\r\n]+)
(?<BSSIDs>(.*))
'@ 
# Regex for parsing each BSSID under the network
$BssidRegEx = @'
\s+\d+\s+: (?<BSSID>[^\r\n]+)
Signal\s+: (?<Signal>[^\%]+)[\%\r\n]
Radio type\s+: (?<RadioType>[^\r\n]+)
Channel\s+: (?<Channel>[^\r\n]+)
Basic rates \(Mbps\)\s+: (?<BasicRates>[^\r\n]+)
Other rates \(Mbps\)\s+: (?<OtherRates>[^\r\n]+)
'@

# hold all found networks/bssid
$WiFiNetworks = @()

# Iterate through each discovered network
$WiFi -split  "\r\s+\n" | ForEach {
    # Extract out network info
    If ($_ -match $NetRegEx) {
        $netMatch = $Matches
        # Explode on each BSSID
        $netMatch.BSSIDs.Trim() -split "BSSID" | ForEach {
            $network = [pscustomobject]@{
                ssid =  $netMatch.SSID.Trim()
                network_type = $netMatch.NetworkType
                auth_type = $netMatch.Authentication
                encryption = $netMatch.Encryption
                bssid = ""
                signal = 0
                radio_type = ""
                channel = ""
                basic_rates = ""
                other_rates = ""
            }
            If ($_ -match $BssidRegEx) {
                # Set name of SSID if empty
                if($network.ssid -eq "") {
                    $network.ssid = "HIDDEN NETWORK: $($Matches.BSSID)"
                }
                $network.bssid = $Matches.BSSID
                $network.signal = [int]$Matches.Signal
                $network.radio_type = $Matches.RadioType
                $network.channel = [int]$Matches.Channel
                $network.basic_rates = $Matches.BasicRates
                $network.other_rates = $Matches.OtherRates

                # Store full details of network/bssid
                $WiFiNetworks += $network
            }
            
        }
    }
}

$WiFiNetworks | ConvertTo-Json

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
        $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_wifiscan`": $(ConvertTo-Json -Compress $WiFiNetworks) }}"
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
