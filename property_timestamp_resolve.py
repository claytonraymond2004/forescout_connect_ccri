import json
import urllib

# Hold response to Forescout EyeExtend Connect
response = {}

# Get parameter details from resolve script parameters -- what host are we resolving?
host_ip = params["ip"] # Host IP address

# Get Forescout OIM Web API Details (We connect to OIM to get data) from Connect App context
forescout_url = params["connect_ccri_forescout_url"]
forescout_jwt_token = params["connect_authorization_token"]

# Create request to get host data from Forescout
forescout_headers = {"Authorization": forescout_jwt_token}
forescout_request = urllib.request.Request(forescout_url + "/api/hosts/ip/" + host_ip + "/?fields=online", headers=forescout_headers)

logging.debug("Preparing to get host information for host: {}".format(host_ip))

try:
    # Make API request to Forescout Web API For host
    forescout_resp = urllib.request.urlopen(forescout_request, context=ssl_context) # To use the server validation feature, use the keyword 'ssl_context' in the http reqeust
    if forescout_resp.getcode() == 200:
        logging.debug("Received data from Forescout Web API")
        # Load response data
        host_data = json.loads(forescout_resp.read().decode('utf-8'))

        online = host_data['host']['fields']['online']

        if online:
            properties = {
                "connect_ccri_timestamp_online": online['timestamp']
            }

            # Return resolved properties to Connect
            response["properties"] = properties
    else:
       logging.error("Failed API Request to Forescout to get host data!")
       response["error"] = "Failed API request to Forescout Web API server!"

except Exception as e:
    logging.error("General Block Exception: {}".format(e))
    response["error"] = "Exception! This probably means this host has no online field. Check the debug logs for more info."