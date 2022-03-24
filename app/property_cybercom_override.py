# Hold response to Forescout EyeExtend Connect
response = {
    "properties": {}
}

# Get parameter
cybercom = params["connect_ccri_disa_reporting_cybercom_cat_value"] # selected cybercom category

# Set USCYBERCOM Category
if cybercom:
    response["properties"]["connect_ccri_disa_reporting_cybercom_cat_override"] = cybercom
    response["properties"]["connect_ccri_disa_reporting_cybercom_cat_final"] = cybercom

response["succeeded"] = True
## DONE