<#
.SYNOPSIS
    Gets information from Forescout API and saves to .csv; explodes array fields into multiple rows

.DESCRIPTION
    Powershell GUI wizard to get info from Forescout API and save it to a file

.PARAMETER api
    IP address of the Forescout Web API

.PARAMETER username
    Username for the Web API

.PARAMETER password
    Password for the Web API
    
.SWITCH inseucre
    Will ignore certificate validation to Forescout Web API
#>

Param(
    [string]$api = $null,
    [string]$username = $null,
    [string]$password = $null,
    [switch]$insecure = $false,
    [switch]$asCsv = $false,
    [string]$savePath = $null,
    [string]$matchRuleId = $null,
    [string]$fields = $null

)

# Ask for Web API info if not provided
If(!$api) {
    $api = Read-Host "Forescout Web API IP / DNS Name"
}

If($insecure -eq $false) {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Ignores untrusted certificates."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Respects certificate trust settings."

    $insecurePrompt =  $host.UI.PromptForChoice("Certificate Validation" , "Ignore Web API Certificate errors?" , ($yes, $no), 1)
}

# Get Credential from user if not provided
If ($username -and $password) {
    [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
    [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)
} else {
    $Credential = $host.ui.PromptForCredential("Web API Credentials", "Please enter credentials for the Forescout Web API", $username, "")
}

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
if ($insecure -eq $true -or $insecurePrompt -eq 0) {
    Write-Host "Disabling certificate validation"
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# Get Forescout Web API Token
try {
    Write-Host "Authenticating with Forescout API"
    $body = @{username=$Credential.Username
              password=$Credential.GetNetworkCredential().Password
    }
    $token = Invoke-WebRequest -Method POST -Uri "https://$api/api/login" -body $body -ContentType "application/x-www-form-urlencoded"
} catch {
    # Error authenticating
    Write-Error "Forescout Web API Auth Error"
    Write-Error $_
    Exit
}


# Ask user which policy they want to match on, get policy list from API
If ([string]::IsNullOrEmpty($matchRuleId)) {
    try {
        Write-Host "Getting list of Forescout Policies"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $token)
        $headers.Add("Accept", "application/hal+json")
        $policies = Invoke-RestMethod "https://$api/api/policies" -Headers $headers
    } catch {
        # Error POSTing Data
        Write-Error "Forescout Web API Error getting policies"
        Write-Error $_
    }

    $rules = @()
    foreach ($policy in $policies.policies) {
       foreach ($rule in $policy.rules) {
            $rules += [PSCustomObject]@{
                id = $rule.ruleId
                policy_name = $policy.name
                policy_description = $policy.description
                rule_name = $rule.name
                rule_description =  $rule.description
            }
       }
    }
    $selectedRules = $rules | Sort-Object -Property policy_name,rule_name | Out-GridView -PassThru -Title "Select sub-rules to filter host list by (multiple selection allowed)"
    $matchRuleId = $($selectedRules | ForEach-Object { $_.id }) -join ","
    Write-Host "Filtering to hosts matching ruleId(s): $matchRuleId"
}


# Ask user which host fields they want to export, get field list from API
If ([string]::IsNullOrEmpty($fields)) {
    # Get Forescout List of Properties
    try {
        Write-Host "Getting list of available Forescout Host Properties"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $token)
        $headers.Add("Accept", "application/hal+json")
        $hostfields = Invoke-RestMethod "https://$api/api/hostfields" -Headers $headers
    } catch {
        # Error POSTing Data
        Write-Error "Forescout Web API Error getting host fields"
        Write-Error $_
    }

    $fieldList = @()
    foreach ($field in $hostfields.hostFields) {
       $fieldList += [PSCustomObject]@{
            name = $field.name
            label = $field.label
            description = $field.description
            type = $field.type
        }
    }
    $selectedFields = $fieldList | Sort-Object -Property label | Out-GridView -PassThru -Title "Select fields to retrieve (multiple selection allowed)"
    $fields = $($selectedFields | ForEach-Object { $_.name }) -join ","
    Write-Host "Filtering host fields to: $fields"
}

# Get list of hosts matching selected policy
try {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $token)
    $headers.Add("Accept", "application/hal+json")
    $hostQuery = "https://$api/api/hosts"
    If (![string]::IsNullOrEmpty($matchRuleId)) {
        $hostQuery += "?matchRuleId=$matchRuleId"
    }
    $hosts = Invoke-RestMethod $hostQuery -Headers $headers
    Write-Host "Found $($hosts.hosts.length) host(s) matching Rule"
} catch {
    # Error POSTing Data
    Write-Error "Forescout Web API Error getting list of hosts matching policy"
    Write-Error $_
}

# Save stuff if data found
If($hosts.hosts.length -gt 0) {

    # Ask save method
    If($asCsv -eq $false) {
        $csv = New-Object System.Management.Automation.Host.ChoiceDescription "&CSV", `
        "Save in CSV format"

        $json = New-Object System.Management.Automation.Host.ChoiceDescription "&JSON", `
        "Save in JSON Format"

        $saveMethod = $host.UI.PromptForChoice("Save Format" , "How do you want to save the data?" , ($csv, $json), 0)
        If($saveMethod -eq 0) {
            Write-Host "Will format data as CSV"
            $asCsv = $true
        } else {
            Write-Host "Will format data as JSON Array"
        }
    }

    # Ask where to save file
    If ([string]::IsNullOrEmpty($savePath)) {
        $saveFilter = 'JSON (*.json)|*.json'
        If($asCsv) {
            $saveFilter = 'CSV (*.csv)|*.csv'
        }
        Add-Type -AssemblyName System.Windows.Forms
        $saveBrowser = New-Object System.Windows.Forms.SaveFileDialog -Property @{
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter = $saveFilter
        }
        $saveResult = $saveBrowser.ShowDialog()
        If($saveResult -eq "OK") {
            $savePath = $saveBrowser.FileName
            Write-Host "Will save data to: $($saveBrowser.FileName)"
        } else {
            Write-Host "Will write data to console"
        }
    }

    # Get data about each host
    Write-Host "Getting data for each found host"
    $data = @();
    $propertyList = "ip", "mac", "id"; # Store complete list of all properties that we collect for CSV export (header row)
    $count = 0;
    foreach ($hostMatch in $hosts.hosts) {
        $count++;
        # Get list of hosts matching selected policy
        try {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Authorization", $token)
            $headers.Add("Accept", "application/hal+json")
            # When Forescout API is fixed, change to use object_id instead of IP
            If($hostMatch.ip) {
                $hostQuery = "https://$api/api/hosts/ip/$($hostMatch.ip)?fields=$fields,"
            } else {
                $hostQuery = "https://$api/api/hosts/mac/$($hostMatch.mac)?fields=$fields,"
            }
            If (![string]::IsNullOrEmpty($fields)) {
                $hostQuery += "?fields=$fields"
            }
            $hostInfo = Invoke-RestMethod $hostQuery -Headers $headers
            Write-Host "$([math]::Round($count/$hosts.hosts.length*100))% - Got selected fields for host (id=$($hostMatch.hostId), ip=$($hostMatch.ip), mac=$($hostMatch.mac))"
        } catch {
            # Error POSTing Data
            Write-Error "Forescout Web API Error getting host info for (id=$($hostMatch.hostId), ip=$($hostMatch.ip), mac=$($hostMatch.mac))"
            Write-Error $_
        }

        # Add host inforation to array
        If($asCsv) {
            # if we are exporting as CSV, process each property on hosts to make a row for each property
            $hostInfo.host.fields.psobject.Members | where-object membertype -like 'noteproperty' | ForEach-Object {

                # Process data and explode out into rows with each field if CSV
                $row = [PSCustomObject]@{
                    ip = $hostInfo.host.ip
                    mac = $hostInfo.host.mac
                    id = $hostInfo.host.id
                }

                # If property value is an array, we make more rows!
                If($_.Value -is [array]) {

                    # Remember name of property we're exploding
                    $prop_name = $_.Name

                    # Loop through each value in the array
                    $_.Value | ForEach-Object {
                    
                        # Make a copy of the host row, each array value gets a clean copy of it
                        $hostCopy = $row.PsObject.Copy()
                        $hostCopy | Add-Member -NotePropertyName "$prop_name.timestamp" -NotePropertyValue $_.timestamp
                        $propertyList += "$prop_name.timestamp"

                        # Check if value is object or string
                        If($_.value.GetType().Name -eq "PSCustomObject") {

                            # Explode objects into multiple columns
                            $objMembers = $_.value.psobject.Members | where-object membertype -like 'noteproperty'
                            foreach ($member in $objMembers) {
                                $hostCopy | Add-Member -NotePropertyName "$prop_name.value.$($member.name)" -NotePropertyValue $member.value
                                $propertyList += "$prop_name.value.$($member.name)"
                            }

                        } else {

                            # Add value as column
                            $hostCopy | Add-Member -NotePropertyName "$prop_name.value" -NotePropertyValue $_.value
                            $propertyList += "$prop_name.value"
                        }
                        $data += $hostCopy
                    }

                # Property is single value, break out value(s) into multiple columns
                } else {

                    $row | Add-Member -NotePropertyName "$($_.Name).timestamp" -NotePropertyValue $_.Value.timestamp
                    $propertyList += "$($_.Name).timestamp"

                    # Check if value is object or string
                    If($_.Value.value.GetType().Name -eq "PSCustomObject") {

                        # Explode objects into multiple columns
                        $objMembers = $_.Value.value.psobject.Members | where-object membertype -like 'noteproperty'
                        foreach ($member in $objMembers) {
                            $row | Add-Member -NotePropertyName "$($_.Name).value.$($member.name)" -NotePropertyValue $member.value
                            $propertyList += "$($_.Name).value.$($member.name)"
                        }

                    } else {

                        # Add value as column
                        $row | Add-Member -NotePropertyName "$($_.Name).value" -NotePropertyValue $_.Value.value
                        $propertyList += "$($_.Name).value"
                    }

                    # Add row
                    $data += $row
                }
            }
    
        } else {
            # Save as JSON data
            $data += $hostInfo.host
        }
    }

    If($asCsv) {
        If($savePath) {
            Write-Host "Saving data to file!"
            $data | Select-Object $($propertyList | select-object -unique) | Export-Csv -Path $savePath -NoTypeInformation
            Write-Host "Saved data to file!"
        } else {
            $data | Select-Object $($propertyList | select-object -unique) | ConvertTo-Csv -NoTypeInformation
        }
    } else {
        If($savePath) {
            Write-Host "Saving data to file!"
            $data | ConvertTo-Json -Depth 4 | Out-File $savePath
            Write-Host "Saved data to file!"
        } else {
            $data | ConvertTo-Json -Depth 4
        }
    }
} else {
    Write-Host "No hosts found, nothing to save!"
}