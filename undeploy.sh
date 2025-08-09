#!/bin/bash

ORG="YOUR_ORG_NAME" # Replace with your organization name
token=$(gcloud auth print-access-token)

# Define the directory to store the lists of undeployed proxies
UNDEPLOYED_DIR="undeployed_proxies"
mkdir -p "$UNDEPLOYED_DIR"

# Function to install apigeecli
install_apigeecli() {
  echo "apigeecli tool not found. Attempting to install..."
  OS_TYPE=$(uname -s)

  if [[ "$OS_TYPE" == "Linux" ]]; then
    echo "Detected Linux. Installing apigeecli..."
    curl -sL https://apigee.github.io/apigeecli/install.sh | bash -
  elif [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "Detected macOS. Installing apigeecli..."
    curl -sL https://apigee.github.io/apigeecli/install.sh | bash -
  else
    echo "Unsupported OS for automatic apigeecli installation. Please install apigeecli manually."
    echo "Refer to: https://cloud.google.com/apigee/docs/api-platform/reference/apigeecli/install"
    exit 1
  fi

  if ! command -v apigeecli &> /dev/null; then
    echo "Error: apigeecli installation failed. Please check your internet connection or install manually."
    exit 1
  else
    echo "apigeecli installed successfully."
  fi
}

# Check if apigeecli is installed, if not, attempt to install
if ! command -v apigeecli &> /dev/null; then
  install_apigeecli
fi

if [ -z "$token" ]; then
  echo "Error: The 'token' variable is not set. Please ensure you have a valid Apigee access token."
  exit 1
fi

# Function to handle undeployment for a single environment
process_environment() {
  local ENV_NAME=$1
  local UNDEPLOYED_LIST_FILE="$UNDEPLOYED_DIR/undeployed_proxies_$ENV_NAME.json"

  echo "Starting undeployment process for environment: $ENV_NAME in organization: $ORG"

  echo "Fetching current deployments in '$ENV_NAME'..."
  DEPS=$(apigeecli environments deployments get --org="$ORG" --env="$ENV_NAME" --token="$token")

  if [[ -z "$DEPS" || "$DEPS" == "null" ]]; then
    echo "No deployments found in environment '$ENV_NAME'."
    echo "[]" > "$UNDEPLOYED_LIST_FILE"
    return 0
  fi

  echo "$DEPS" | jq '.deployments[] | {apiProxy, revision}' > "$UNDEPLOYED_LIST_FILE"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to process deployments with jq or save to $UNDEPLOYED_LIST_FILE. Check jq installation and JSON format."
    return 1
  fi

  echo "List of proxies to be undeployed saved to $UNDEPLOYED_LIST_FILE"

  jq -c '.[]' "$UNDEPLOYED_LIST_FILE" | while IFS= read -r deployment_obj_str; do
    PROXY=$(echo "$deployment_obj_str" | jq -r '.apiProxy')
    REV=$(echo "$deployment_obj_str" | jq -r '.revision')

    echo "Undeploying proxy: $PROXY, revision: $REV from environment: $ENV_NAME"
    apigeecli apis undeploy -o "$ORG" --token "$token" --name="$PROXY" --rev="$REV" --env="$ENV_NAME"
    if [ $? -eq 0 ]; then
      echo "Successfully undeployed proxy: $PROXY, revision: $REV"
    else
      echo "Error undeploying proxy: $PROXY, revision: $REV. Check the logs for details."
    fi
  done
}

# --- Main execution starts here ---

echo "Fetching all environments for organization: $ORG..."
# Use apigeecli to get all environments and store them in an array
ENVS=$(apigeecli environments list --org="$ORG" --token="$token" | jq -r '.[]')

if [ -z "$ENVS" ]; then
  echo "No environments found for organization '$ORG'."
  exit 0
fi

# Loop through each environment and process it
for env_to_process in $ENVS; do
  process_environment "$env_to_process"
  echo "--------------------------------------------------------"
done

echo "Undeployment process for all environments completed."
