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
ENV="{YOUR APIGEE ENVIRONMENT}"
ORG="{YOUR APIGEE ORG NAME}"
token=$(gcloud auth print-access-token)
UNDEPLOYMENT_MANIFEST="undeployed_proxies.json"

echo "Starting undeployment process for environment: $ENV in organization: $ORG"

# Ensure the apigeecli tool is installed and the token is valid
if ! command -v apigeecli &> /dev/null; then
    echo "Error: apigeecli tool not found. Please install it."
    exit 1
fi

if [ -z "$token" ]; then
    echo "Error: The 'token' variable is not set. Please ensure you have a valid Apigee access token."
    exit 1
fi

DEPS=$(apigeecli environments deployments get --org="$ORG" --env="$ENV" --token="$token")

if [[ -z "$DEPS" ]]; then
    echo "No deployments found in environment '$ENV'."
    exit 0
fi
# Store the list of deployments in a JSON file before undeploying
echo "$DEPS" | jq -c '.deployments[] | {apiProxy, revision}' | jq -s '.' > "$UNDEPLOYMENT_MANIFEST"


echo "$DEPS" | jq -c '.deployments[] | {apiProxy, revision}' | while IFS= read -r deployment_obj_str; do
    # Use jq again to extract values from the line (which is a mini JSON object)
    PROXY=$(echo "$deployment_obj_str" | jq -r '.apiProxy')
    REV=$(echo "$deployment_obj_str" | jq -r '.revision')

    echo "Undeploying proxy: $PROXY, revision: $REV from environment: $ENV"
    apigeecli apis undeploy -o "$ORG" --token "$token" --name="$PROXY" --rev="$REV" --env="$ENV"
    if [ $? -eq 0 ]; then
        echo "Successfully undeployed proxy: $PROXY, revision: $REV"
    else
        echo "Error undeploying proxy: $PROXY, revision: $REV. Check the logs for details."
    fi
done

echo "Undeployment process completed."
