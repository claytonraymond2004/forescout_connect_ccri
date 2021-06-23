#!/usr/bin/python
# Script to be run as 'Run Script on CounterACT' Action on a rule filtering to Cisco IP phones running a webpage on :80
# 	Script expects parameters when run: cisco_phone.py {ip} <connect_api_ip> <connect_api_username> <connect_api_password>
# Should be paired with the 'ccri' app which creates the Serial Number property on devices

# Imports
import sys, os
import urllib, urllib2, httplib, json
import re

# Make sure IP address of device to check is provided and Connect CCRI App API ip/username/password provided
if len(sys.argv) != 5:
    print "Missing Arguments: ip_address api_ip api_username api_password"
    sys.exit(1) 

# Grab web page from device
try:
    phone_web_obj = urllib2.urlopen('http://%s' % str(sys.argv[1]))
    phone_web_content = phone_web_obj.read()
    phone_web_obj.close()

    # Search for serial number in HTML
    serial_number = re.search("Serial Number.+?(?=<B>)<B>([^\<]+)", phone_web_content)
    if serial_number:
        # Found serial number
        print serial_number.group(1)

        # Authenticate to Forescout Connect Web API
        try:
            url = 'https://%s/connect/v1/authentication/token' % sys.argv[2]
            data = json.dumps({ "username": "%s" % sys.argv[3], "password": "%s" % sys.argv[4], "app_name": "ccri", "expiration":"1"})
            req = urllib2.Request(url, data, {'Content-Type': 'application/json'})
            response = urllib2.urlopen(req)
            jwt = json.load(response)  
            token = jwt.get('data').get('token') # Bearer token to send in update call

            # POST to /hosts API To put data
            try: 
                url = 'https://%s/connect/v1/hosts' % sys.argv[2]
                data = json.dumps({ "ip":"%s" % str(sys.argv[1]), "properties":{ "connect_ccri_serialnumber":"%s" % serial_number.group(1) }})
                req = urllib2.Request(url, data, {'Authorization': "Bearer %s" % token, 'Content-Type': 'application/json', 'accept': 'application/json'})
                response = urllib2.urlopen(req)
                jwt = json.load(response)  
                token = jwt.get('data').get('token') # Bearer token to send in update call
            # Catch POST error
            except urllib2.HTTPError, e:
                print 'Forescout Connect API POST Data error: HTTPError = ' + str(e.code)
                sys.exit(1) 
            except urllib2.URLError, e:
                print 'Forescout Connect API POST Data error: URLError = ' + str(e.reason)
                sys.exit(1) 
            except httplib.HTTPException, e:
                print 'Forescout Connect API POST Data error: HTTPException'
                sys.exit(1)
            except Exception:
                import traceback
                print 'Forescout Connect API POST Data error: generic exception: ' + traceback.format_exc()
                sys.exit(1)
        
        # Catch autentication error
        except urllib2.HTTPError, e:
            print 'Forescout Connect API Auth error: HTTPError = ' + str(e.code)
            sys.exit(1) 
        except urllib2.URLError, e:
            print 'Forescout Connect API Auth error: URLError = ' + str(e.reason)
            sys.exit(1) 
        except httplib.HTTPException, e:
            print 'Forescout Connect API Auth error: HTTPException'
            sys.exit(1)
        except Exception:
            import traceback
            print 'Forescout Connect API Auth error: generic exception: ' + traceback.format_exc()
            sys.exit(1)

    else:
        print "Couldn't find Serial Number on page"
        sys.exit(1) 

# Catch errors
except urllib2.HTTPError, e:
    print 'Webpage scrape error: HTTPError = ' + str(e.code)
    sys.exit(1) 
except urllib2.URLError, e:
    print 'Webpage scrape error: URLError = ' + str(e.reason)
    sys.exit(1) 
except httplib.HTTPException, e:
    print 'Webpage scrape error: HTTPException'
    sys.exit(1)
except Exception:
    import traceback
    print 'Webpage scrape error: generic exception: ' + traceback.format_exc()
    sys.exit(1)