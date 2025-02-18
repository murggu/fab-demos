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

check_spn_auth() {
    if [ "$enable_spn_auth" == "true" ]; then
        # use env variables or github secrets
        export FAB_CLIENT_ID
        export FAB_CLIENT_SECRET
        export FAB_TENANT_ID

        run_fab_command "auth login -u $FAB_CLIENT_ID -p $FAB_CLIENT_SECRET --tenant $FAB_TENANT_ID"
    fi
}

replace_kql_parent_eventhouse() {
    local kql_db_name=$1
    local eventhouse_id=$2
    local _stg_json="$staging_dir/$kql_db_name/DatabaseProperties.json"

    jq --arg _eventhouse_id "$eventhouse_id" \
    '.parentEventhouseItemId = $_eventhouse_id' \
        "$_stg_json" > "$_stg_json.tmp" && mv "$_stg_json.tmp" "$_stg_json"
}

replace_eventstream_destination_eventhouse() {
    local eventstream_name=$1
    local workspace_id=$2
    local kql_db_id=$3
    local _stg_json="$staging_dir/$eventstream_name/eventstream.json"

    jq --arg _workspace_id "$workspace_id" \
    --arg _kql_db_id "$kql_db_id" \
    '.destinations[0].properties.workspaceId = $_workspace_id |
    .destinations[0].properties.itemId = $_kql_db_id' \
    "$_stg_json" > "$_stg_json.tmp" && mv "$_stg_json.tmp" "$_stg_json"
}

replace_kqldashboard_datasource() {
    local kql_dh_name=$1
    local workspace_id=$2
    local kql_db_id=$3
    local cluster_uri=$4
    local _stg_json="$staging_dir/$kql_dh_name/RealTimeDashboard.json"

    jq --arg _workspace_id "$workspace_id" \
    --arg _kql_db_id "$kql_db_id" \
    --arg _cluster_uri "$cluster_uri" \
    '.dataSources[0].database = $_kql_db_id |
    .dataSources[0].clusterUri = $_cluster_uri |
    .dataSources[0].workspace = $_workspace_id' \
    "$_stg_json" > "$_stg_json.tmp" && mv "$_stg_json.tmp" "$_stg_json"
}

# fab specific

create_workspace(){
    local suffix=$1
    echo -e "\n_ creating a workspace..."
    run_fab_command "create /${workspace_name}_${suffix}.Workspace -P capacityName=${capacity_name}"

    if [ "$enable_spn_auth" == "true" ]; then
        echo -e "\n_ spn deployment; assigning permissions to workspace user..."
        run_fab_command "acl set -f /${workspace_name}_${suffix}.Workspace -I $upn_objectid -R admin"
    fi
}
