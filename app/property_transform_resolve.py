import re

# Hold response to Forescout EyeExtend Connect
response = {
    "properties": {}
}

# Get parameter details with included host properties
host_dns = params["hostname"] # Host IP address

##################################################
# Do transforms
##################################################

# DNS to NetBIOS style hostname
nbthostname = re.search("(.+?)(?=\.)", host_dns)
if nbthostname:
    response["properties"]["connect_ccri_transforms_dns_to_nbhost"] = nbthostname.group(1)


## DONE