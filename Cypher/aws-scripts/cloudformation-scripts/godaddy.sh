#!/bin/bash

source config.sh


#For UI
curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_UI.$SUBDOMAIN" \
-H "Authorization: sso-key $API_KEY:$API_SECRET" \
-H "Content-Type: application/json" \
-d "[{\"data\": \"$IP_UI\", \"ttl\": 600}]"

#For Fast-api
curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_API.$SUBDOMAIN" \
-H "Authorization: sso-key $API_KEY:$API_SECRET" \
-H "Content-Type: application/json" \
-d "[{\"data\": \"$IP_API\", \"ttl\": 600}]"

# #For Airflow
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_AIRFLOW.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_Airflow\", \"ttl\": 600}]"

# #For Greylog
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_GREYLOG.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_Greylog\", \"ttl\": 600}]"

echo "All domain Setup Successfully"