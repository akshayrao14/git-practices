#!/usr/bin/env bash

# Source the bash formatting library
# shellcheck source=/dev/null
if ! source "$(dirname "${BASH_SOURCE[0]}")/bash_formatting.sh"; then
    echo "Error: Failed to source bash_formatting.sh" >&2
    exit 1
fi

# Check if running in CI environment
if [[ "$CONTINUOUS_INTEGRATION" == *"true"* ]]; then
    echo -e "\nSkipping .env downloader for CI environment..."
    exit 0
fi

# Check if download is skipped
if [[ "$SKIP_DL_ENV" == *"true"* ]]; then
    echo -e "\nSkipping .env downloader as SKIP_DL_ENV is set..."
    exit 0
fi

echo -e "${LOW_INTENSITY_TEXT}Checking AWS SSO login...${RESET_FORMATTING}"

# Check if AWS_PROFILE is set
if [ -z "$AWS_PROFILE" ]; then
    echo -e "${YELLOW}AWS_PROFILE environment variable is not set.${RESET_FORMATTING}"
    echo -e "${YELLOW}Run: ${BOLD}export AWS_PROFILE=<aws-sso-profile>${RESET_FORMATTING}${YELLOW} and try again.${RESET_FORMATTING}"
    exit 1
fi

# Function to check AWS CLI version
check_aws_cli_version() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${RESET_FORMATTING}"
        echo -e "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check AWS CLI version (v2 required for SSO)
    AWS_CLI_VERSION=$(aws --version 2>&1 | awk -F'[/. ]' '{print $2}')
    if [ "$AWS_CLI_VERSION" -lt 2 ]; then
        echo -e "${YELLOW}AWS CLI v2 or later is required for SSO.${RESET_FORMATTING}"
        echo -e "Please upgrade your AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
}

# Check AWS CLI installation and version
check_aws_cli_version

# Function to get AWS account ID
get_aws_account_id() {
    aws sts get-caller-identity --query "Account" --profile "$AWS_PROFILE" 2>&1 | tr -d '"'
}

# Check AWS connectivity and get account ID
SSO_ACCOUNT=$(get_aws_account_id)

# Check for connectivity issues
if [[ "$SSO_ACCOUNT" == *"not connect"* ]] || [[ "$SSO_ACCOUNT" == *"Unable to locate credentials"* ]]; then
    echo -e "${RED}AWS Error: $SSO_ACCOUNT${RESET_FORMATTING}"
    echo -e "${YELLOW}Please check your internet connection and AWS credentials.${RESET_FORMATTING}"
    exit 1
fi

# Check if we need to log in to SSO
if [ ${#SSO_ACCOUNT} -ne 12 ]; then
    echo -e "${YELLOW}Attempting to configure AWS SSO...${RESET_FORMATTING}"
    if ! aws sso login --profile "${AWS_PROFILE}"; then
        echo -e "${RED}Failed to log in to AWS SSO.${RESET_FORMATTING}"
        exit 1
    fi
    
    # Refresh account ID after login
    SSO_ACCOUNT=$(get_aws_account_id)
fi

# Final validation of AWS account ID
if [ ${#SSO_ACCOUNT} -ne 12 ]; then
    echo -e "${BLINK_RED}ERROR: Invalid AWS account ID: $SSO_ACCOUNT${RESET_FORMATTING}"
    echo -e "${YELLOW}Please configure AWS SSO by running:${RESET_FORMATTING}"
    echo -e "  ${GREEN}aws configure sso --profile ${AWS_PROFILE}${RESET_FORMATTING}"
    exit 1
fi

echo -e "${GREEN}AWS SSO configuration is valid. Account ID: $SSO_ACCOUNT${RESET_FORMATTING}"