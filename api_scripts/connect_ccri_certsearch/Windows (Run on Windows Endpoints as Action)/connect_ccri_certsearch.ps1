<#
.SYNOPSIS
    Search for .pfx and .p12 files on a computer

.DESCRIPTION
    Uses Windows search to find .p12 and .pfx files on a computer for DoD Policy purposes. Can optionally fall back to slower disk search if Windows Search Index service fails.

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

.SWITCH fallback
    Fallback to slower disk search if Windows Search Index fails, default is false
#>

Param(
    [string]$ip = $(throw "-ip is required."),
    [string]$api = $(throw "-api is required."),
    [string]$username = $(throw "-username is required."),
    [string]$password = $(throw "-password is required."),
    [switch]$insecure = $false,
    [switch]$fallback = $false
)

function Search-FileIndex {
<#
.PARAMETER Path
Absoloute or relative path. Has to be in the Search Index for results to be presented.
.PARAMETER Pattern
File name or pattern to search for. Defaults to *.*. Aliased to Filter to ergonomically match Get-ChildItem.
.PARAMETER Text
Free text to search for in the files defined by the pattern.
.PARAMETER Recurse
Add the parameter to perform a recursive search. Default is false.
.PARAMETER AsFSInfo
Add the parameter to return System.IO.FileSystemInfo objects instead of String objects.
.SYNOPSIS
Uses the Windows Search index to search for files.
.DESCRIPTION
Uses the Windows Search index to search for files. SQL Syntax documented at https://msdn.microsoft.com/en-us/library/windows/desktop/bb231256(v=vs.85).aspx Based on https://blogs.msdn.microsoft.com/mediaandmicrocode/2008/07/13/microcode-windows-powershell-windows-desktop-search-problem-solving/ 
.OUTPUTS
By default array of strings per file found with full path.
If the AsFSInfo switch is set, one array of System.IO.FileSystemInfo objects per file found is returned.
#>
    [CmdletBinding()]
    param (  
        [Parameter(ValueFromPipeline = $true)]
        [string]$Path,
        [Parameter(Mandatory=$false,ParameterSetName="FullText")]
        [Parameter(Mandatory=$false)]
        [alias("Filter")] 
        [string]$Pattern = "*.*",
        [Parameter(Mandatory=$false,ParameterSetName="FullText")]
        [string]$Text = $null,
        [Parameter(Mandatory=$false)]
        [switch]$Recurse = $false,
        [Parameter(Mandatory=$false)]
        [switch]$AsFSInfo = $false
    )

    if($Path -eq ""){
        $Path = $PWD;
    } 

    $pattern = $pattern -replace "\*", "%"
    $path = $path.Replace('\','/')

    if ((Test-Path -Path Variable:fsSearchCon) -eq $false)
    {
        $global:fsSearchCon = New-Object -ComObject ADODB.Connection
        $global:fsSearchRs = New-Object -ComObject ADODB.Recordset
    }

    Try {
        $fsSearchCon.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")
    } catch {
        Write-Debug "fsSearchCon already open!"
    }

    [string]$queryString = "SELECT System.ItemPathDisplay FROM SYSTEMINDEX WHERE System.ITEMNAME LIKE '" + $pattern + "' "
    if ([System.String]::IsNullOrEmpty($Text) -eq $false){
        $queryString += "AND FREETEXT('" + $Text + "') "
    }

    if ($Recurse){
        $queryString += "AND SCOPE='file:" + $path + "'"
    }
    else {
        $queryString += "AND DIRECTORY='file:" + $path + "'"
    }

    $queryString += " ORDER BY System.ItemPathDisplay"

    $fsSearchRs.Open($queryString, $fsSearchCon)
    # return
    While(-Not $fsSearchRs.EOF){
        if ($AsFSInfo){
            # Return a FileSystemInfo object 
            [System.IO.FileSystemInfo]$(Get-Item -LiteralPath ($fsSearchRs.Fields.Item("System.ItemPathDisplay").Value) -Force)
        }
        else {
            $fsSearchRs.Fields.Item("System.ItemPathDisplay").Value
        }
        $fsSearchRs.MoveNext()
    }
    $fsSearchRs.Close()
    $fsSearchCon.Close()
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
if ($insecure -eq $true) {
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# Get list of all (local) filesystems for search
$drives = @()
try {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object -Property DisplayRoot -notlike '\\*'
} catch {
    Write-Error "Error getting list of disks"
    exit
}

# Search Windows Search index for .pfx and .p12 files on each found drive, If Search-FileIndex fails, fallback to iterative Get-ChildItem method
$certList = @()
Foreach ($drive in $drives) {
    try {
        Write-Debug "Trying Windows Search index"
        $certList += Search-FileIndex -Path "$($drive.Root)" -Recurse -Pattern "*.pfx"
        $certList += Search-FileIndex -Path "$($drive.Root)" -Recurse -Pattern "*.p12"
    } catch {
        if ($fallback) {
            Write-Debug "Errow while querying Windows Search Index, using Get-ChildItem. $_"
            try {
                $certList += Get-ChildItem -Path "$($drive.Root)" -Include *.pfx,*.p12 -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)" }
            } catch {
                Write-Error "Error searching disk for files"
                exit
            }
        } else {
            exit
        }
    }
}
ConvertTo-Json -Compress $certList

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
        $body = "{ `"ip`": `"$ip`", `"properties`":{ `"connect_ccri_certsearch`": $(ConvertTo-Json -Compress $certList) }}"
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
