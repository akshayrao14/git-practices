#!/bin/bash

# Function to start SSM session
start_ssm_session() {
  local env_name=$1
  local region=$2
  local target=$3
  local host=$4
  local remote_port=$5
  local local_port=$6
  
  aws ssm start-session \
    --region "$region" \
    --target "$target" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$host\"],\"portNumber\":[\"$remote_port\"],\"localPortNumber\":[\"$local_port\"]}" \
    > /dev/null 2>&1 &
}

# Function to validate and parse input
validate_and_parse() {
  local input=$1
  shift
  local valid_options=("$@")
  local result=()
  
  # Split by comma or space
  IFS=', ' read -ra PARTS <<< "$input"
  
  for part in "${PARTS[@]}"; do
    part=$(echo "$part" | xargs) # trim whitespace
    if [ -z "$part" ]; then
      continue
    fi
    
    # Check if part is valid
    local is_valid=false
    for valid in "${valid_options[@]}"; do
      if [ "$part" == "$valid" ]; then
        is_valid=true
        break
      fi
    done
    
    if [ "$is_valid" == false ]; then
      return 1
    fi
    
    # Add to result if not already present
    local already_added=false
    for existing in "${result[@]}"; do
      if [ "$existing" == "$part" ]; then
        already_added=true
        break
      fi
    done
    
    if [ "$already_added" == false ]; then
      result+=("$part")
    fi
  done
  
  if [ ${#result[@]} -eq 0 ]; then
    return 1
  fi
  
  echo "${result[@]}"
  return 0
}

run_ssm_flow() {
  MASTER_MODE=false
  
  # Prompt for AWS profile with default
  read -p $'\033[1;32mEnter AWS profile [rudram-tern]: \033[0m' AWS_PROFILE_INPUT
  
  if [ -z "$AWS_PROFILE_INPUT" ]; then
    AWS_PROFILE="rudram-tern"
  else
    AWS_PROFILE="$AWS_PROFILE_INPUT"
  fi
  
  export AWS_PROFILE
  echo ""
  
  # Prompt for environment - keep asking until valid input
  while true; do
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33mSTEP 1: Environment\033[0m"
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "  \033[0;32m• dev\033[0m  \033[0;32m• prod\033[0m  \033[0;32m• master\033[0m  \033[0;33mExamples:\033[0m \033[0;37mdev\033[0m | \033[0;37mdev,prod\033[0m | \033[0;37mmaster\033[0m"
    echo ""
    read -p $'\033[1;32mEnter: \033[0m' ENV_INPUT
    
    if [ -z "$ENV_INPUT" ]; then
      echo -e "\033[0;31mCannot be empty. \033[1;31mTry again BOSS.\033[0m"
      continue
    fi
    
    # Check for master mode - opens all sessions
    if [ "$ENV_INPUT" == "master" ]; then
      MASTER_MODE=true
      ENVS=("dev" "prod")
      CLIENTS=("ehs" "try" "medcare" "laasp")
      echo ""
      break
    fi
    
    ENVS_STR=$(validate_and_parse "$ENV_INPUT" "dev" "prod")
    if [ $? -ne 0 ]; then
      echo -e "\033[0;31mInvalid! Use: \033[0;33mdev\033[0m, \033[0;33mprod\033[0m, \033[0;33mmaster\033[0m, or \033[0;33mdev,prod\033[0m. \033[1;31mTry again BOSS.\033[0m"
      continue
    fi
    
    read -ra ENVS <<< "$ENVS_STR"
    echo ""
    break
  done

  # Skip client prompt if master mode was selected
  if [ "$MASTER_MODE" == false ]; then
    # Prompt for client name - keep asking until valid input
    while true; do
      echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      echo -e "\033[1;33mSTEP 2: Client\033[0m"
      echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      echo -e "  \033[0;32m• ehs\033[0m  \033[0;32m• try\033[0m  \033[0;32m• medcare\033[0m  \033[0;32m• laasp\033[0m  \033[0;33mExamples:\033[0m \033[0;37mehs\033[0m | \033[0;37mehs,try\033[0m | \033[0;37mehs,try,medcare,laasp\033[0m"
      echo ""
      read -p $'\033[1;32mEnter: \033[0m' CLIENT_INPUT
      
      if [ -z "$CLIENT_INPUT" ]; then
        echo -e "\033[0;31mCannot be empty. \033[1;31mTry again BOSS.\033[0m"
        continue
      fi
      
      CLIENTS_STR=$(validate_and_parse "$CLIENT_INPUT" "ehs" "try" "medcare" "laasp")
      if [ $? -ne 0 ]; then
        echo -e "\033[0;31mInvalid! Use: \033[0;33mehs\033[0m, \033[0;33mtry\033[0m, \033[0;33mmedcare\033[0m, \033[0;33mlaasp\033[0m, or comma-separated like \033[0;33mehs,try\033[0m. \033[1;31mTry again BOSS.\033[0m"
        continue
      fi
      
      read -ra CLIENTS <<< "$CLIENTS_STR"
      echo ""
      break
    done
  fi

  # Show what will start
  echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\033[1;33mSTEP 3: Will start:\033[0m"
  SESSION_NAMES=()
  for env in "${ENVS[@]}"; do
    for client in "${CLIENTS[@]}"; do
      full_env="${env}-${client}"
      case $full_env in
        dev-ehs) SESSION_NAMES+=("dev-ehs") ;;
        prod-ehs) SESSION_NAMES+=("prod-ehs") ;;
        prod-try) SESSION_NAMES+=("prod-try") ;;
        prod-medcare) SESSION_NAMES+=("prod-medcare") ;;
        dev-try) SESSION_NAMES+=("dev-try") ;;
        dev-medcare) SESSION_NAMES+=("dev-medcare") ;;
        prod-laasp) SESSION_NAMES+=("prod-laasp") ;;
      esac
    done
  done
  # Display all sessions side by side
  SESSION_DISPLAY=""
  for session in "${SESSION_NAMES[@]}"; do
    if [ -z "$SESSION_DISPLAY" ]; then
      SESSION_DISPLAY="  \033[1;35m$session\033[0m"
    else
      SESSION_DISPLAY="$SESSION_DISPLAY | \033[1;35m$session\033[0m"
    fi
  done
  echo -e "$SESSION_DISPLAY"
  echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo ""
  echo -e "\033[0;36mCheck browser bro for AWS auth 🌐\033[0m"
  echo ""

  aws sso login --profile "$AWS_PROFILE" > /dev/null 2>&1

  echo ""
  echo -e "\033[1;32mAll set! You're now connected to the DB via SSM.\033[0m"
  echo ""

  # Start all matching SSM sessions
  for env in "${ENVS[@]}"; do
    for client in "${CLIENTS[@]}"; do
      full_env="${env}-${client}"
      
      case $full_env in
        dev-ehs)
          start_ssm_session "dev-ehs" "me-central-1" "i-0d3580ca77bb79b63" \
            "development-tern.cvk8uawkw8t3.me-central-1.rds.amazonaws.com" "5501" "5501"
          ;;
        prod-ehs)
          start_ssm_session "prod-ehs" "me-central-1" "i-0d3580ca77bb79b63" \
            "production-tern.cvk8uawkw8t3.me-central-1.rds.amazonaws.com" "7702" "7702"
          ;;
        prod-try)
          start_ssm_session "prod-try" "ap-southeast-1" "i-0d974223dbd225881" \
            "tern-db-inst-1.claiowcas4kt.ap-southeast-1.rds.amazonaws.com" "5432" "6543"
          ;;
        prod-medcare)
          start_ssm_session "prod-medcare" "me-central-1" "i-0d3580ca77bb79b63" \
            "db-medcare-prod-instance.cvk8uawkw8t3.me-central-1.rds.amazonaws.com" "5432" "5432"
          ;;
        dev-try)
          start_ssm_session "dev-try" "ap-southeast-1" "i-03daf0f438214e7a1" \
            "dev-try-rds-1.claiowcas4kt.ap-southeast-1.rds.amazonaws.com" "5432" "5429"
          ;;
        dev-medcare)
          start_ssm_session "dev-medcare" "me-central-1" "i-0ce709700d5c49acd" \
            "dev-medcare-rds-1.cvk8uawkw8t3.me-central-1.rds.amazonaws.com" "5432" "5430"
          ;;
        prod-laasp)
          start_ssm_session "prod-laasp" "eu-west-2" "i-0dff9bf5ad5b24286" \
            "production-liverpool-rds.cex9rxkqqry8.eu-west-2.rds.amazonaws.com" "5432" "5432"
          ;;
      esac
    done
  done

  echo -e "\033[0;36mRunning in background. Press \033[1;33mCtrl+C\033[0m\033[0;36m to stop.\033[0m"
  echo ""

  # Wait for all background jobs
  wait
}

# Entry point
mode="$1"
shift || true

case "$mode" in
  ""|ssm)
    # Default: run DB/SSM flow
    run_ssm_flow "$@"
    ;;
  *)
    echo -e "\033[1;34mUsage:\033[0m"
    echo -e "  \033[0;32m./ssm.sh\033[0m           - start DB/SSM sessions"
    ;;
esac
