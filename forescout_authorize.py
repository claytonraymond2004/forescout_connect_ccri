import json
import urllib.request

# CONFIGURATION
# All server configuration fields will be available in the 'params' dictionary.
url = params["connect_ccri_forescout_url"] # Server URL
username = params["connect_ccri_forescout_username"] # OIM Username
password = params["connect_ccri_forescout_password"] # OIM Password

# Making an API call to get the JWT token
headers = {"Content-Type": "application/x-www-form-urlencoded"}
data = {"username": username, "password": password}
request = urllib.request.Request(url + "/api/login", headers=headers, data=bytes(urllib.parse.urlencode(data), encoding="utf-8"))

# To use the server validation feature, use the keyword 'ssl_context' in the http reqeust
response = {} # respones to forecout EyeExtend Connect
try:
    # Make API request
    resp = urllib.request.urlopen(request, context=ssl_context)
    # If we are authorized return to EyeExtend Connect
    if resp.getcode() == 200:
        logging.info("Received new Forescout OIM Web API JWT")
        response["token"] = resp.read().decode('utf-8')
    else:
        logging.error("Failed to get new Forescout OIM Web API JWT")
        response["token"] = ""
except:
    response["token"] = ""