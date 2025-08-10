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
export ENV="{YOUR APIGEE ENVIRONMENT}" # Replace with your environment name
export ORG="{YOUR APIGEE ORG NAME}" # Replace with your organization name
export PROXIES_FILE="undeployed_proxies.json" # The name of the JSON file containing the proxies to deploy

echo "Starting deployment process for proxies listed in '$PROXIES_FILE' to environment: $ENV in organization: $ORG"

# Function to install apigeecli
install_apigeecli() {
        echo "🔄 Installing apigeecli ..."
        curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
        export PATH=$HOME/.apigeecli/bin:$PATH
        echo "✅ apigeecli installed."
}

# Call the function to ensure apigeecli is installed and in the PATH
install_apigeecli

# Check if the proxies file exists and is not empty
if [ ! -s "$PROXIES_FILE" ]; then
    echo "❌ Error: The file '$PROXIES_FILE' does not exist or is empty. No proxies to deploy."
    exit 1
fi

echo "Reading proxies from '$PROXIES_FILE'..."

# Use a more robust jq command to handle potential formatting issues and ensure proper parsing
jq -r '.deployments[]? | (.apiProxy + " " + .revision)' "$PROXIES_FILE" | while read -r PROXY REV; do
    
    # Check if the variables are empty and skip if they are
    if [ -z "$PROXY" ] || [ -z "$REV" ]; then
        echo "Skipping an empty or malformed line in the input."
        continue
    fi

    # Get a fresh token before each API call to avoid expiration issues
    token=$(gcloud auth print-access-token)

    echo "Attempting to deploy proxy: $PROXY, revision: $REV to environment: $ENV"

    # Perform the deployment
    apigeecli apis deploy \
        -o "$ORG" \
        --token "$token" \
        --name="$PROXY" \
        --rev="$REV" \
        --env="$ENV" \
        --override # Use this flag to replace an already deployed revision

    if [ $? -eq 0 ]; then
        echo "✅ Successfully deployed proxy: $PROXY, revision: $REV to environment: $ENV"
    else
        echo "❌ Error deploying proxy: $PROXY, revision: $REV."
        echo "Please check the logs for more details."
    fi
done

echo "Deployment process finished."
