# Forescout Connect CCRI App

This package is a collection of utilities, policy templates, and scripts to help with commonly requested items in the US DoD.

# Capabilities

- When ACAS/Tenable integration is configured/enabled/functioning, creates and maintains an attribute on Hosts for the number of CAT 1/2/3 vulnerabilities on the host.
  - Useful to make it easy to find hosts with a high number of CAT 1/2/3 vulnerabilities and block/quarantine them if they are over a threshold.
  - Properties added:
    - ACAS CAT 1 Count
    - ACAS CAT 2 Count
    - ACAS CAT 3 Count

- Creates and maintains a timestamp property on hosts for the last time the device was seen online. Useful to create policies to find computers that have been offline for a period of time.
  - Properties added:
    - 'Online' Last Reported Timestamp
  
- Creates properties which are updatable via the Connect API
  - Properties added:
    - Device Serial Number
    - Physical Media Serial Numbers
    - WiFi Networks (Scan)
    - Physical Location (GPS)

- Scripts & templates to populate/use the properties created above:
  - Device Serial Number & Physical Media Serial Numbers
    - Cisco IP Phones via scraping Web Page from Forescout managing appliance in a Python script ("Device Serial Number" only)
    - Windows devices via running Powershell script on manageable Windows devices ("Device Serial Number and "Physical Media Serial Numbers")
  - WiFi Networks (Scan)
    - Windows devices via running Powershell script on manageable Windows Devices
  - Physical Location (GPS)
    - Windows devices via running Powershell script on manageable Windows Devices

# Setup

1) Go to Web API in Options and create a username/password for this App to use and make sure the API is allowed to be accessed from all Forescout appliance IP addresses
 - *This app uses the Forescout Web API to gather information about endpoints and process it to create other attributes on endpoints.*
 - Create a complex username/password combonation as this username/password can be used to pull all information about hosts and we don't want this being leaked/guessed
 - We'll need this username/password during the app import
 - Note the token expiration time in the Web API settings. We'll need to use this during the App setup as the app needs to know how long tokens are valid for so it can refresh it before it expires

2) Go to Connect in Options > Import this app

3) Connect will ask to set an App API username/password. Create one and note it -- we'll need it later.
 - Note that this username/password is passed to scripts run on endpoints and therefore shouldn't be considered super secret or difficult. Also complex passwords may break the scripts since I've not done much with special character handling.
 - This username/password will be used to update host properties defined in this app for things like device serial number

4) The System Description dialog will appear, click Add

5) Enter the information for the Forescout Web API connection
 - URL: <https://<IP>  address  of  appliance  running  Web  API  (EM)>
 - Username: username from step 1
 - Password: password from step 1

6) Go through the rest of the settings and set as desired.
 - Note that on the "API Settings" pane:
  - The "Number of API queries per second" number can be adjusted -- this throttle setting will limit the amount of requests to the Web API for resolving the ACAS/timestamp properties. You can adjust this setting to be larger to allow for faster resolution of the related properties, just be careful as at some point the Web API will become overloaded and you'll start getting errors. Be careful here.
  - Make sure to set the "Forescout Web API Authorization Interval" to a value less than the Web API token expiration time from step 1.

7) Complete the app setup and Apply the Connect settings to start the app.

# Policies

Multiple policy templates are included in the "CCRI" Policy template tree to try and kick start the process to resolving the properties added by the app. These policy templates should be fairly self explanatory, just make sure they are scoped correctly and deal with any groups that may be inadvertently imported by deploying these policies.

There are two categories of policies in this App: "Populator" policies and compliance policies. Populator policies run scripts to populate properties via API. Compliance policies do something with the data added.

Populator Policies:

- Serial Number Populator
- WiFi Networks (Scan) Populator
- Physical Location (GPS) Populator

Compliance Policies:

- ACAS CAT 1 Count
- ACAS CAT 2 Count
- ACAS CAT 3 Count
- Host Offline Length
- Rouge WiFi Network Discovered

## Populator Policies

### Serial Number Populator

This policy template is a bit special and requires some tuning and importing some scripts included in this repo.  This policy utilizes a python script that runs on the Forescout managing appliance to scrape the serial number from Cisco IP Phone's website and POSTs the data to this Connect App's Web API to update the attribute. Similarly, a Powershell script is included which runs on Windows endpoints to get the serial number of the device and physical media and POST the data via API.

When deploying this policy, you will need to upload these scripts to the Forescout Script Repository and adjust some arguments in the policy sub-rules.

#### Cisco VoIP Serial Number sub-rule

Edit the "Run Script on CounterACT" action and click the [...] button to upload the `ccri_post_cisco_voip_serialnumber.py` file (in the `api_scripts/connect_ccri_serialnumber/Cisco IP Phone (Run on Forescout Appliance as Action)` folder). In the "Command or Script" textbox you then need to reference this script and give it some parameters:

`ccri_post_cisco_voip_serialnumber.py {ip} <connect_web_api_server_ip> <app_username> <app_password>`

Replace `<connect_web_api_server_ip>` with the IP address of the appliance running the connect API (probably your EM).
Replace `<app_username>` with the Connect App username created when you imported the app (step 3 in the Setup section)
Replace `<app_password>`  with the Connect App password created when you imported the app (step 3 in the Setup section)
Leave the `{ip}` argument alone -- this passes the IP address of the phone we want to resolve to the script.

Example: `ccri_post_cisco_voip_serialnumber.py {ip} 10.0.1.15 demo demo`

It is also recommended to adjust the conditions on the sub-rule to make sure it matches your Cisco IP Phones properly.

##### ccri_post_cisco_voip_serialnumber.py Script details

This script is fairly basic and may not scrape the Serial number from all IP Phones. Currently it is simply grabs the HTML page off the phone at `http://<phone ip>` and looks for the following Regular Expression on the HTML page on the phone: `Serial Number.+?(?=<B>)<B>([^\<]+)` -- This expression is looking for a table on the page with a row with a bolded "Serial Number" text, then looks at the next table cell to grab the Serial Number.

Please feel free to branch this repo and make a merge request to enhance this search if it doesn't work for you.

#### Windows Serial Number sub-rule

Edit the "Run Script on Windows" action and click the [...] button to upload the `ccri_post_win_serialnumber.ps1` file (in the `api_scripts/connect_ccri_serialnumber/Windows (Run on Windows Endpoints as Action` folder). In the "Command or Script" textbox you then need to reference this script and give it some parameters:

`ccri_post_win_serialnumber.ps1 -ip {ip} -api <connect_web_api_server_ip> -username <app_username> -password <app_password> -insecure`

Replace `<connect_web_api_server_ip>` with the IP address of the appliance running the connect API (probably your EM).
Replace `<app_username>` with the Connect App username created when you imported the app (step 3 in the Setup section)
Replace `<app_password>`  with the Connect App password created when you imported the app (step 3 in the Setup section)
The `-insecure` switch is optional if you want to disable certificate validation on the script to the Forescout Web API (self signed Forescout certificate)
Leave the `{ip}` argument alone -- this passes the IP address of the phone we want to resolve to the script.

Example: `ccri_post_win_serialnumber.ps1 -ip {ip} -api 10.0.1.15 -username demo -password demo`

It is also recommended to adjust the conditions on the sub-rule to make sure it matches to your manageable Windows endpoints properly.

##### ccri_post_win_serialnumber.ps1 Script details

This script is fairly basic and just grabs the `SerialNumber` attribute from the powershell `Get-WmiObject win32_bios` call and the drive information from the `Get-WMIObject win32_physicalmedia` call.

Please feel free to branch this repo and make a merge request to enhance this if there's something better.


### WiFi Networks (Scan) Populator

Currently this policy only works on Windows devices and will enumerate the WiFi networks the devices has in range using netsh. It will explode out the BSSIDs of networks created and discover hidden networks and identify them by BSSID. The policy template attempts to narrow down the scope to only those devices that have a Network Adapter that has "Wireless", "WiFi", or "Wi-Fi" in the name.



### Physical Location (GPS) Populator

Currently this policy only works on Windows devices and uses Windows Location Services to try to determine the approximate physical location of the device (GPS Corrdinates). The more information/accuracy information location services provides, the more info will be collected (Horizontal/Vertical accuracy, Course, Speed, altitude). The policy attempts to narrow down scope to only those devices that have location services enabled by checking the registry.

##### Policy Action details

Edit the "Run Script on Windows" action and click the [...] button to upload the `ccri_post_win_gps_coords.ps1` file (in the `api_scripts/connect_ccri_gpscoords/Windows (Run on Windows Endpoints as Action` folder). In the "Command or Script" textbox you then need to reference this script and give it some parameters:

`ccri_post_win_gps_coords.ps1 -ip {ip} -api <connect_web_api_server_ip> -username <app_username> -password <app_password> -insecure`

Replace `<connect_web_api_server_ip>` with the IP address of the appliance running the connect API (probably your EM).
Replace `<app_username>` with the Connect App username created when you imported the app (step 3 in the Setup section)
Replace `<app_password>`  with the Connect App password created when you imported the app (step 3 in the Setup section)
The `-insecure` switch is optional if you want to disable certificate validation on the script to the Forescout Web API (self signed Forescout certificate)
Leave the `{ip}` argument alone -- this passes the IP address of the phone we want to resolve to the script.

Optionally you can set `AttemptDelay` and `MaxAttempts` parameters to adjust location resolution delay/attempt paramters. By default these are set to `1000` and `30` respectively to re-attempt resolution every second, 30 times (30 seconds total).

Example: `ccri_post_win_gps_coords.ps1 -ip {ip} -api 10.0.1.15 -username demo -password demo -AttemptDelay 1000 -MaxAttempts 30`

It is also recommended to adjust the conditions on the sub-rule to make sure it matches to your manageable Windows endpoints with location services properly.

### P12/PFX Search Populator

Currently this policy only works on Windows devices and uses Windows Search service to find .p12 and .pfx files on the device. An optional parameter (`-fallback`) allows the script to fallback to a recursive file-system level search using the Powershell `Get-ChildItem` cmdlet. This method may be more comprehensive than the Windows Search Index, however it comes at an expesnive disk and time utilization penalty and would probably be noticable by users. Use this sparingly.

The policy has 2 sub-rules, "Search using Windows Search" which checks if the Windows Search service is running before executing the script. "Search using Fallback Search (Slow)" is conditional on the Search Service not running and adds the `-fallback` parameter to the script. Note however that in some cases you may want to add the `-fallback` parameter to the "Search using Windows Search" rule in the event the Windows Search service throws an exception for some reason and you want it to fallback to the slow method.

### GeoIP Populator

Currently this policy only works on Windows devices and uses ip-api.com on endpoints to get their External IP address and GeoIP information.

Note: By default we use the insecure, rate limited, free tier of ip-api.com that is not allowed for commerical use. To remove the rate limiting and enable secure communications to get GeoIP information, sign up for an ip-api account and modify scripts accordingly to use the API key and https.


##### Policy Action details

Edit the "Run Script on Windows" action and click the [...] button to upload the `ccri_post_win_gps_coords.ps1` file (in the `api_scripts/connect_ccri_geoip/Windows (Run on Windows Endpoints as Action` folder). In the "Command or Script" textbox you then need to reference this script and give it some parameters:

`connect_ccri_geoip.ps1 -ip {ip} -api <connect_web_api_server_ip> -username <app_username> -password <app_password> -insecure`

Replace `<connect_web_api_server_ip>` with the IP address of the appliance running the connect API (probably your EM).
Replace `<app_username>` with the Connect App username created when you imported the app (step 3 in the Setup section)
Replace `<app_password>`  with the Connect App password created when you imported the app (step 3 in the Setup section)
The `-insecure` switch is optional if you want to disable certificate validation on the script to the Forescout Web API (self signed Forescout certificate)
Leave the `{ip}` argument alone -- this passes the IP address of the phone we want to resolve to the script.

Example: `connect_ccri_geoip.ps1 -ip {ip} -api 10.0.1.15 -username demo -password demo`

It is also recommended to adjust the conditions on the sub-rule to make sure it matches to your manageable Windows endpoints properly.

## Compliance Policies

### Rouge WiFi Network Discovered
This policy uses the discoverd WiFi networks data to show devices that see a WiFi network that is outside a list of expected/allowed networks. Due the the datatype that the WiFi network list is inside Forescout, we use a Regular Expression (RegEx) against the "WiFi Networks (Scan)" > Name" attribute that contains a list of all the allowable network names. Networks found not in the "WiFi Scan - SSID NOT: Matches Expression" condition list will be found as Rouge networks. Use the pipe symbol ( | ) between network names in the Regular Expression as an "OR".

"Corp|Corp Guest" means the networks "Corp" OR "Corp Guest" are allowed, all others are Rouge.

### P12/PFX Certificate Compliance
This policy uses the 'P12/PFX Certificates' data to show devices that have a PFX/P12 Certificate that is outside a list of expected/allowed certificates. Due the the datatype that the Certificate list is inside Forescout, we use a Regular Expression (RegEx) against the "P12/PFX Certificates" attribute that contains a list of all the allowable certificate filepaths. Certificates found not in the "ALL PFX/P12 Certificates - Matches Expression" condition list will be found as disallowed certificates. Use the pipe symbol ( | ) between Certificate paths in the Regular Expression as an "OR". Escape folder delimeters with an extra `\` (`\\`). Escape dots with a `\` (`\.`). Generally, it would be recommended to generate wildcard based paths using `.*`.

Examples:

- All files, no matter where they are, that END in "allowed.pfx": `.*allowed\.pfx`
- All files, no matter where they are, called "allowed.pfx": `.*\\allowed\.pfx`
- Specific filepath "C:\Program Files\Test\test.p12": `C:\\Program Files\\Test\\test\.p12`
- All files, no matter where they are, called either "allowed.pfx" or "allowed.p12": `.*\\allowed\.pfx|.*\\allowed\.p12`

"Corp|Corp Guest" means the networks "Corp" OR "Corp Guest" are allowed, all others are Rouge.

### GeoIP Location Compliance
This policy uses the GeoIP property to show devices that arenlt compliant with an expected GeoIP location. In this case it has simple logic to simply show devices that have an external IP address that is in the US as complaint, otherwise they are non-compliant. Adjust this logic to fit your network / segments / etc.

The idea behind this policy is to identify devices which may be using a VPN to avoid network restrictions or devices being used outside the expected areas (ie laptops being used in China/Russia).


# Misc

- The ACAS CAT 1/2/3 counts and Timestamp properties are Policy based resolution items -- they will not be resolved unless you have a policy using this attributes or add these attributes to the default Asset Inventory. The serial number attributes are dependent on external sources (scripts) updating these values via API.
- Resolving the number of CAT 1/2/3's for a host is done by logic inside this app. Examine the `acas_resolve.py` script to see how this is calculated for a host. If something is wrong in here, please branch this repo and make a merge request to fix the logic.
- The number of CAT 1/2/3's for a host should be automatically update when the `nessus_scan_results` attribute is updated. Note that in `property.conf` only the CAT 1 Count property has the trigger specified on it to recalculate on new/change, but all 3 are updated at the same time since the script `acas_resolve.py` script resolves all 3 counts at the same time since it is based on the same underlying attribute. There's no need to set the redo new/change flag on all 3 properties as this triples the workload.
