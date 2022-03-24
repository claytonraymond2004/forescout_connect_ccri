import json
import urllib

# Hold response to Forescout EyeExtend Connect
response = {
    "properties": {}
}

## NOTE: For whatever reason, Connect won't pass the in-group property to this script. Workaround using Web API call

# Get parameters
groups_params = params.get("in-group") # device groups; only provided if triggered off group change and calculaing guessed category
host_ip = params["ip"] # Host IP address -- what host are we resolving?
# Get Forescout OIM Web API Details (We connect to OIM to get data) from Connect App context
forescout_url = params["connect_ccri_forescout_url"]
forescout_jwt_token = params["connect_authorization_token"]

# Device category groups; for performing guess
mobile = ["P-Mobile", "P-Mobile Devices Manual Discover", "P-Mobile Devices Manual Discover", "C2C-Step1-Manual-Mobile Device", "C2C-Step1-Discovery-Mobile"]
network_support = ["P-Printers", "P-VoIP Devices", "P-Printers Manual Discover", "P-VoIP Manual Discover", "C2C-Step1-Manual-VOIP Device", "C2C-Step1-Manual-Printer Device", "C2C-Step1-Manual-VoIP Devices", "C2C-Step1-Manual-Discovery-Printers"]
workstations = ["P-Windows", "P-Linux/Unix", "P-macOS", "P-Windows Manual Discover", "P-Linux/Unix Manual Discover", "P-macOS Manual Discover", "C2C-Step1-Manual-MacOS Device", "C2C-Step1-Manual-Unix Device", "C2C-Step1-Manual-Windows Device", "C2C-Step1-Manual-CounterACT", "C2C-Step1-Manual-OOB", "C2C-Step1-Manual-MacOS", "C2C-Step1-Manual-Linux/Unix", "C2C-Step1-Manual-Windows"]
infrastructure = ["P-Network Devices", "P-Network Devices Manual Discover", "C2C-Step1-Manual-Network Device", "C2C-Step1-Discovery-Storage", "C2C-Step1-Discovery-Network Devices"]
cps_cs = ["P-OT Devices","P-OT Devices Manual Discover","C2C-Step1-CPS/CS","C2C-Step1-Manual-CPS/CS Device"]
iot = ["P-IoT", "P-IoT Devices Manual Discover", "C2C-Step1-IOT", "C2C-Step1-Manual-IOT Device"]

# Create request to get host data from Forescout
forescout_headers = {"Authorization": forescout_jwt_token}
forescout_request = urllib.request.Request(forescout_url + "/api/hosts/ip/" + host_ip + "/?fields=in-group", headers=forescout_headers)

logging.debug("Preparing to get host information for host: {}".format(host_ip))

try:
    # Make API request to Forescout Web API For host
    forescout_resp = urllib.request.urlopen(forescout_request, context=ssl_context) # To use the server validation feature, use the keyword 'ssl_context' in the http reqeust
    if forescout_resp.getcode() == 200:
        logging.debug("Received data from Forescout Web API")
        # Load response data
        host_data = json.loads(forescout_resp.read().decode('utf-8'))

        groups_web = host_data.get('host', {}).get('fields', {}).get('in-group', None)

        if groups_web:
            guess = None;
            # Parse list of group objects to just list of group.value (a string)
            groups_web_vals = [ val['value'] for val in groups_web ]

            # Check if 
            if any(item in groups_web_vals for item in mobile):
                guess = "mobile"
            elif any(item in groups_web_vals for item in network_support):
                guess = "network_support"
            elif any(item in groups_web_vals for item in workstations):
                guess = "workstations"
            elif any(item in groups_web_vals for item in infrastructure):
                guess = "infrastructure"
            elif any(item in groups_web_vals for item in cps_cs):
                guess = "cps_cs"
            elif any(item in groups_web_vals for item in iot):
                guess = "iot"
            
            if guess:
                response["properties"]["connect_ccri_disa_reporting_cybercom_cat_guess"] = guess
            else:
                response["error"] = "Failed to guess USCYBERCOM Device Category"

        else:
            logging.error("No Group data for host found! (in-group is not found in Forescout Web API)")
            response["error"] = "No Group data for host found, cannot guess USCYBERCOM Category! (in-group is not found in Forescout Web API)"

    else:
       logging.error("Failed API Request to Forescout to get host data!")
       response["error"] = "Failed API request to Forescout Web API server!"

except Exception as e:
    logging.error("General Block Exception: {}".format(e))
    response["error"] = "Exception! Check the debug logs for more info."