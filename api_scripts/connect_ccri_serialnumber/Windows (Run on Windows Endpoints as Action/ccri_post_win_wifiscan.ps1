$WiFi = (netsh wlan show network  mode=bssid |  Select-Object -Skip  3).Trim()  | Out-String

$NetRegEx = @'
(?smi)SSID \d+ : (?<SSID>[^\r\n]+)
Network type\s+: (?<NetworkType>[^\r\n]+)
Authentication\s+: (?<Authentication>[^\r\n]+)
Encryption\s+: (?<Encryption>[^\r\n]+)
(?<BSSIDs>(.*))
'@ 

$BssidRegEx = @'
\s+\d+\s+: (?<BSSID>[^\r\n]+)
Signal\s+: (?<Signal>[^\%]+)[\%\r\n]
Radio type\s+: (?<RadioType>[^\r\n]+)
Channel\s+: (?<Channel>[^\r\n]+)
Basic rates \(Mbps\)\s+: (?<BasicRates>[^\r\n]+)
Other rates \(Mbps\)\s+: (?<OtherRates>[^\r\n]+)
'@

$Networks = $WiFi -split  "\r\s+\n" 

$WiFiNetworks = @()

$Networks | ForEach {
    If ($_ -match $NetRegEx) {
        $network = [pscustomobject]@{
            SSID =  $Matches.SSID
            NetworkType = $Matches.NetworkType
            AuthenticationType = $Matches.Authentication
            Encryption = $Matches.Encryption
            BSSID = ""
            Signal = 0
            RadioType = ""
            Channel = ""
            BasicRates = ""
            OtherRates = ""
        }

        $Matches.BSSIDs -split "BSSID" | ForEach {
            If ($_ -match $BssidRegEx) {
                $network.BSSID = $Matches.BSSID
                $network.Signal = $Matches.Signal
                $network.RadioType = $Matches.RadioType
                $network.Channel = $Matches.Channel
                $network.BasicRates = $Matches.BasicRates
                $network.OtherRates = $Matches.OtherRates
            }
            $WiFiNetworks += $network
        }
    }
}

$WiFiNetworks | ConvertTo-Json