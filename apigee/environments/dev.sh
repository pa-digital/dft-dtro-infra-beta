#!/bin/bash

echo "dev"
echo "env=dev" >> $GITHUB_ENV
echo "workload_identity_service_account=${service_account}" >> $GITHUB_ENV
echo "apigee_organisation=${apigee_organisation}" >> $GITHUB_ENV
echo "APIGEECLI_DEBUG=true" >> $GITHUB_ENV