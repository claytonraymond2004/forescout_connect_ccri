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
forescout_request = urllib.request.Request(forescout_url + "/api/hosts/ip/" + host_ip + "/?fields=nessus_scan_results", headers=forescout_headers)

logging.debug("Preparing to get host information for host: {}".format(host_ip))

try:
    # Make API request to Forescout Web API For host
    forescout_resp = urllib.request.urlopen(forescout_request, context=ssl_context) # To use the server validation feature, use the keyword 'ssl_context' in the http reqeust
    if forescout_resp.getcode() == 200:
        logging.debug("Received data from Forescout Web API")
        # Load response data
        host_data = json.loads(forescout_resp.read().decode('utf-8'))

        # Check if response contains scan data
        nessus_scan_results = host_data.get('host', {}).get('fields', {}).get('nessus_scan_results', None)

        if nessus_scan_results:
            properties = {
                "connect_ccri_acas_cat1": 0,
                "connect_ccri_acas_cat2": 0,
                "connect_ccri_acas_cat3": 0
            }

            # Iterate through vulnerability list
            for vuln in nessus_scan_results:
                logging.debug("Evaluating vulnerability: {}".format(vuln))

                severity = vuln.get('value', {}).get('plugin_severity', {})
                xref = vuln.get('value', {}).get('Xref', {})

                # CAT 1
                if (severity == "severity_High") or (severity == 'severity_Critical') or ("IAVA" in xref) or ("IAVB" in xref) or ("IAVM" in xref):
                    properties['connect_ccri_acas_cat1'] += 1
                    logging.debug("CAT 1 Vulnerability!")

                # CAT 2
                elif severity == "severity_Medium":
                    properties['connect_ccri_acas_cat2'] += 1
                    logging.debug("CAT 2 Vulnerability!")

                # CAT 3
                elif severity == "severity_Low":
                    logging.debug("CAT 3 Vulnerability!")
                    properties['connect_ccri_acas_cat3'] += 1
                
                else:
                    logging.debug("Not a CAT Vulnerability!")

            # Return resolved properties to Connect
            response["properties"] = properties

        else:
            logging.error("No Tenable Scan data for host found! (nessus_scan_results is not found in Forescout Web API)")
            response["error"] = "No Tenable Scan data for host found! (nessus_scan_results is empty in Forescout Web API)"
            
    else:
       logging.error("Failed API Request to Forescout to get host data!")
       response["error"] = "Failed API request to Forescout Web API server!"

except Exception as e:
    logging.error("General Block Exception: {}".format(e))
    response["error"] = "Exception! This probably means this host has no nessus_scan_results. Check the debug logs for more info."