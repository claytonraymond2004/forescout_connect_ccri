# Get Wifi networks from windows
$WiFi = (netsh wlan show network  mode=bssid |  Select-Object -Skip  3).Trim()  | Out-String

# Regex for parsing data -- lump all the BSSIDs in a property we'll expand out later
$NetRegEx = @'
(?smi)SSID \d+ : (?<SSID>[^\r\n]+)
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
$WiFi -split  "\r\s+\n"  | ForEach {
    # Extract out network info
    If ($_ -match $NetRegEx) {
        $network = [pscustomobject]@{
            ssid =  $Matches.SSID
            network_type = $Matches.NetworkType
            auth_type = $Matches.Authentication
            encryption = $Matches.Encryption
            bssid = ""
            signal = 0
            radio_type = ""
            channel = ""
            basic_rates = ""
            other_rates = ""
        }
        # Explode on each BSSID
        $Matches.BSSIDs -split "BSSID" | ForEach {
            If ($_ -match $BssidRegEx) {
                $network.bssid = $Matches.BSSID
                $network.signal = [int]$Matches.Signal
                $network.radio_type = $Matches.RadioType
                $network.channel = [int]$Matches.Channel
                $network.basic_rates = $Matches.BasicRates
                $network.other_rates = $Matches.OtherRates
            }
            $WiFiNetworks += $network # Store full details of network/bssid
        }
    }
}

$WiFiNetworks | ConvertTo-Json