#!/bin/bash
# shellcheck disable=SC2269,SC2154

# Script Variables
ORG=$apigee_organisation
TOKEN=$1
env=$env
env_name_prefix=$env_name_prefix

  # Make the API call
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://apigee.googleapis.com/v1/organizations/${ORG}/sites" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'"${env_name_prefix^} Developer D-TRO Portal"'",
      "description": "'"This is the ${env_name_prefix^} Developer Portal for D-TRO"'"
    }')

  # Error checking and handling
  if [ "$RESPONSE" -eq 200 ]; then
    echo "Developer Portal for ${env_name_prefix^} successfully created in ${ORG}."
  elif [ "$RESPONSE" -eq 409 ]; then
    echo "Developer Portal for ${env_name_prefix^} already exists in ${ORG}."
  else
    echo "Failed to create developer portal in ${ORG}. HTTP response code: $RESPONSE"
  fi
