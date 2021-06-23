#!/bin/bash
# Script to be run as 'Run Script on CounterACT' Action on a rule filtering to Cisco IP phones running a webpage on :80
# 	Script expects parameters when run: cisco_phone.sh {ip} <connect_api_username> <connect_api_password>
# Should be paired with the 'script_based_property_creator' app which creates the Serial Number property on devices

##################################################################
#
#  GET DATA FROM PHONE
#
##################################################################

# Get phone Web page and scrape for Serial Number
webpage=$(curl http://$1 --max-time 5 --negotiate --anyauth -L -k -v --stderr -)
# Filter and get the Serial Number
serial=$(echo $webpage | grep -oP 'Serial Number.+?(?=<B>)<B>\K([^\<]+)(?=<\/B>)')
echo $serial

##################################################################
#
#  POST TO CONNECT APP API
#
##################################################################

# Get auth token
auth=$(curl -X POST "https://127.0.0.1/connect/v1/authentication/token" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"username\":\"$2\", \"password\":\"$3\", \"app_name\":\"ccri\", \"expiration\":\"1\"}")
token=$(echo $auth | grep -oP 'token": "\K([^"]+)')

# POST property to Forescout
curl -X POST "https://127.0.0.1/connect/v1/hosts" -H "accept: application/json" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "{ \"ip\":\"$1\", \"properties\":{ \"connect_ccri_serialnumber\":\"$serial\" }}"
