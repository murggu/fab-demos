#!/bin/bash

CONFIG_FILE="$(dirname "$0")/../config.yml"

# functions

read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found at $CONFIG_FILE"
        exit 1
    fi

    while IFS=": " read -r key value; do
        # Remove any \r characters and extra spaces
        key=$(echo "$key" | tr -d '\r' | xargs)
        value=$(echo "$value" | tr -d '\r' | tr -d '"' | xargs)

        # Skip empty lines and comments
        if [[ ! "$key" =~ ^# && -n "$key" ]]; then
            export "$key"="$value"
        fi
    done < "$CONFIG_FILE"
}

run_fab_command() {
  local command=$1
  fab -c "${command}"
}

create_staging()  {
    echo -e "\n_ creating staging directory..."
    mkdir -p "$staging_dir"
    cp -r ./${demo_name}/workspace/* $staging_dir/
    echo "* Done"
}

# fab specific
# TODO