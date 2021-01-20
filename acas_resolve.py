import json

# To obtain the ACAS scan data that is needed to make calculations, add the 'nessus_scan_results' CounterACT host property
# as a dependency to each property on 'property.conf'. Any property added as a dependency will be resolved (or attempted to be resolved)
# by CounterACT and will be in the 'params' dictionary for any property with that dependency. 
nessus_scan_results = json.loads(params["nessus_scan_results"])

# All responses from scripts must contain the JSON object 'response'. Host property resolve scripts will need to populate a
# 'properties' JSON object within the JSON object 'response'. The 'properties' object will be a key, value mapping between the
# CounterACT property name and the value of the property.
response = {}
properties = {
    "connect_ccri_acas_cat1": 0,
    "connect_ccri_acas_cat2": 0,
    "connect_ccri_acas_cat3": 0
}

# Function to evaluate a vuln if it is cat 1/2/3 and count
def eval_vuln(vuln):
    logging.debug("Evaluating vulnerability")
    logging.debug(vuln)
    if (vuln['plugin_severity'] == "severity_High") or (vuln['plugin_severity'] == 'severity_Critical') or ("IAVA" in vuln['Xref']) or ("IAVB" in vuln['Xref']) or ("IAVM" in vuln['Xref']):
        properties.connect_ccri_acas_cat1 += 1
    elif vuln['plugin_severity'] == "severity_Medium":
        properties.connect_ccri_acas_cat2 += 1
    elif vuln['plugin_severity'] == "severity_Low":
        properties.connect_ccri_acas_cat3 += 1

# Depending on if given list of vulns or a single vuln, process accordingly
if isinstance(nessus_scan_results, dict):
    logging.debug("nessus_scan_results is a single item")
    eval_vuln(nessus_scan_results)
elif isinstance(nessus_scan_results, list):
    logging.debug("nessus_scan_results is a list of results")
    for vuln in nessus_scan_results:
        eval_vuln(vuln)
else:
    logging.debug("nessus_scan_results is not defined")
    properties = None

# Return to resolver to create property in Forescout
response["properties"] = properties
