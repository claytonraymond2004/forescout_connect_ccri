# Hold response to Forescout EyeExtend Connect
response = {
    "properties": {}
}

# Get parameters
guess = params.get("connect_ccri_disa_reporting_cybercom_cat_guess") # Guessed category
override = params.get("connect_ccri_disa_reporting_cybercom_cat_override") # Overridden category

# Set override value if present, otherwise use gGuess
if override :
    response["properties"]["connect_ccri_disa_reporting_cybercom_cat_final"] = override
else :
    response["properties"]["connect_ccri_disa_reporting_cybercom_cat_final"] = guess

response["succeeded"] = True
## DONE