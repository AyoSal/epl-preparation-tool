#!/bin/bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#!/bin/bash

# Configuration variables
ENV="{YOUR APIGEE ENVIRONMENT}"
ORG="{YOUR APIGEE ORG  NAME}"

# Input file for the proxies to redeploy
DEPLOYMENT_FILE="undeployed_proxies.json"

# Get access token
token=$(gcloud auth print-access-token)

echo "Starting redeployment process for environment: $ENV in organization: $ORG"

# Ensure the apigeecli tool is installed and the token is valid
if ! command -v apigeecli &> /dev/null; then
    echo "Error: apigeecli tool not found. Please install it."
    exit 1
fi

if [ -z "$token" ]; then
    echo "Error: The 'token' variable is not set. Please ensure you have a valid Apigee access token."
    exit 1
fi

# Ensure the deployments file exists
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "Error: Deployment file '$DEPLOYMENT_FILE' not found. Please ensure it's a valid JSON array."
    exit 1
fi

# Read deployments from the JSON file and redeploy each one
jq -c '.[] | {apiProxy, revision}' "$DEPLOYMENT_FILE" | while IFS= read -r deployment_obj_str; do
    # Extract proxy name and revision from the JSON object
    PROXY=$(echo "$deployment_obj_str" | jq -r '.apiProxy')
    REV=$(echo "$deployment_obj_str" | jq -r '.revision')

    echo "Redeploying proxy: $PROXY, revision: $REV to environment: $ENV"
    # Note: The 'deploy' command will look for the bundle locally. 
    # This script assumes the proxy bundle for the specified revision is available.
    apigeecli apis deploy -o "$ORG" --token "$token" --name="$PROXY" --rev="$REV" --env="$ENV"
    if [ $? -eq 0 ]; then
        echo "Successfully redeployed proxy: $PROXY, revision: $REV"
    else
        echo "Error redeploying proxy: $PROXY, revision: $REV. Check the logs for details."
    fi
done

echo "Redeployment process completed."
