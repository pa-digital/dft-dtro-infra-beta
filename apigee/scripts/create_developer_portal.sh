#!/bin/bash

# Script Variables
ORG=$apigee_organisation
TOKEN=$1
env=$env


  # Construct the description
  DESCRIPTION="This is the ${env} Developer Portal for D-TRO"

  # Make the API call
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://apigee.googleapis.com/v1/organizations/${ORG}/sites" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'"${env} Developer D-TRO Portal"'",
      "description": "'"${DESCRIPTION}"'"
    }')

  # Error checking and handling
  if [ "$RESPONSE" -eq 200 ]; then
    echo "Developer Portal successfully created in ${env}."
  elif [ "$RESPONSE" -eq 409 ]; then
    echo "Developer Portal already exists in ${env}."
  else
    echo "Failed to create developer portal in ${env}. HTTP response code: $RESPONSE"
  fi