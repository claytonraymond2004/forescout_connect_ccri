# To obtain the ACAS scan data that is needed to make calculations, add the 'nessus_scan_results' CounterACT host property
# as a dependency to each property on 'property.conf'. Any property added as a dependency will be resolved (or attempted to be resolved)
# by CounterACT and will be in the 'params' dictionary for any property with that dependency. 
nessus_scan_results = params["nessus_scan_results"]

# All responses from scripts must contain the JSON object 'response'. Host property resolve scripts will need to populate a
# 'properties' JSON object within the JSON object 'response'. The 'properties' object will be a key, value mapping between the
# CounterACT property name and the value of the property.
response = {}
properties = {
    "connect_ccri_acas_cat1": 0,
    "connect_ccri_acas_cat2": 0,
    "connect_ccri_acas_cat1": 0
}

# Didn't get vuln data, return nothing, Irresolvable
if not nessus_scan_results:
    response["properties"] = None
else
    # Iterate through each nessus scan result and increment count
    for vuln in nessus_scan_results:
        if (vuln.value.plugin_severity == "severity_High") or (vuln.value.plugin_severity == 'severity_Critical') or ("IAVA" in vuln.value.Xref) or ("IAVB" in vuln.value.Xref) or ("IAVM" in vuln.value.Xref)
            properties.connect_ccri_acas_cat1 += 1
        else if vuln.value.plugin_severity == "severity_Medium":
            properties.connect_ccri_acas_cat2 += 1
        else if vuln.value.plugin_severity == "severity_Low":
            properties.connect_ccri_acas_cat3 += 1
    # Return to resolver to create property in Forescout
    response["properties"] = properties
