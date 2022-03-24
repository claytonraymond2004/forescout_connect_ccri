# Hold response to Forescout EyeExtend Connect
response = {
    "properties": {}
}

# Get parameters
groups = params["in-group"] # device groups; only provided if triggered off group change and calculaing guessed category
guess = params["connect_ccri_disa_reporting_cybercom_cat_guess"] # Guessed category; provided if guessed or overriden category sets/changes
override = params["connect_ccri_disa_reporting_cybercom_cat_override"] # Overridden category; provided if guessed or overriden category sets/changes

# Device category groups; for performing guess
mobile = ["P-Mobile", "P-Mobile Devices Manual Discover", "P-Mobile Devices Manual Discover", "C2C-Step1-Manual-Mobile Device", "C2C-Step1-Discovery-Mobile"]
user_support = ["P-Printers", "P-VoIP Devices", "P-Printers Manual Discover", "P-VoIP Manual Discover", "C2C-Step1-Manual-VOIP Device", "C2C-Step1-Manual-Printer Device", "C2C-Step1-Manual-VoIP Devices", "C2C-Step1-Manual-Discovery-Printers"]
workstations = ["P-Windows", "P-Linux/Unix", "P-macOS", "P-Windows Manual Discover", "P-Linux/Unix Manual Discover", "P-macOS Manual Discover", "C2C-Step1-Manual-MacOS Device", "C2C-Step1-Manual-Unix Device", "C2C-Step1-Manual-Windows Device", "C2C-Step1-Manual-CounterACT", "C2C-Step1-Manual-OOB", "C2C-Step1-Manual-MacOS", "C2C-Step1-Manual-Linux/Unix", "C2C-Step1-Manual-Windows"]
cps = ["P-OT Devices","P-OT Devices Manual Discover","C2C-Step1-CPS/CS","C2C-Step1-Manual-CPS/CS Device"]
iot = ["P-IoT", "P-IoT Devices Manual Discover", "C2C-Step1-IOT", "C2C-Step1-Manual-IOT Device"]

# If groups were provided, we're resolving the guess value
if groups:
    logging.debug(groups)
    # response["properties"]["connect_ccri_disa_reporting_cybercom_cat_guess"] = cybercom

# otherwise we're resolving the final value
else :
    if override :
        response["properties"]["connect_ccri_disa_reporting_cybercom_cat_final"] = override
    elif guess:
        response["properties"]["connect_ccri_disa_reporting_cybercom_cat_final"] = guess

response["succeeded"] = True
## DONE