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

replace_bypath_to_byconnection() {
    local report_name=$1
    local semantic_model_id=$2
    local _stg_report_json="$staging_dir/$report_name/definition.pbir"

    jq --arg _semantic_model_id "$semantic_model_id" \
        '.datasetReference.byPath = null | .datasetReference.byConnection = {
        "connectionString": "Data Source=powerbi://api.powerbi.com/v1.0/myorg/mkdir;Initial Catalog=r3;Integrated Security=ClaimsToken",
        "pbiServiceModelId": null,
        "pbiModelVirtualServerName": "sobe_wowvirtualserver",
        "pbiModelDatabaseName": $_semantic_model_id,
        "name": "EntityDataSource",
        "connectionType": "pbiServiceXmlaStyleLive"
    }' "$_stg_report_json" > "$_stg_report_json.tmp" && mv "$_stg_report_json.tmp" "$_stg_report_json"
}

replace_kqlqueryset_connection() {
    local kql_qs_name=$1
    local kql_db_id=$2
    local cluster_uri=$3
    local _stg_json="$staging_dir/$kql_qs_name/RealTimeQueryset.json"

    jq --arg _kql_db_id "$kql_db_id" \
    --arg _cluster_uri "$cluster_uri" \
    '(.payload.connections["1866773671"].connectionString = $_cluster_uri |
        .payload.connections["1866773671"].initialCatalog = $_kql_db_id) |
    walk(if type == "string" then gsub("88a7ebfd-4b71-b41d-41ea-8bc0286d907e"; $_kql_db_id) else . end)' \
    "$_stg_json" > "$_stg_json.tmp" && mv "$_stg_json.tmp" "$_stg_json"
}

replace_string_value() {
    local semmodel_name=$1
    local path=$2
    local old_string=$3
    local new_string=$4
    local _stg_semmodel_tmdl="$staging_dir/$semmodel_name/$path"

    if [[ -f "$_stg_semmodel_tmdl" ]]; then
        sed -i "s|$old_string|$new_string|g" "$_stg_semmodel_tmdl"
    fi
}

replace_pipeline_metadata() {
    local pipeline_name=$1
    local workspace_id=$2
    local lakehouse_id=$3
    local connection_id_blob=$4
    local _stg_pip_json="$staging_dir/$pipeline_name/pipeline-content.json"

    jq --arg _workspace_id "$workspace_id" \
    --arg _lakehouse_id "$lakehouse_id" \
    --arg _connection_id "$connection_id_blob" \
    '.properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.workspaceId = $_workspace_id |
        .properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.artifactId = $_lakehouse_id |
        .properties.activities[].typeProperties.source.datasetSettings.externalReferences.connection = $_connection_id' \
        "$_stg_pip_json" > "$_stg_pip_json.tmp" && mv "$_stg_pip_json.tmp" "$_stg_pip_json"
}

replace_semanticmodel_metadata() {
    local sem_model_name=$1
    local lakehouse_conn_string=$2
    local lakehouse_conn_id=$3
    local _stg_tmdl_expressions="$staging_dir/$sem_model_name/definition/expressions.tmdl"

    content=$(cat "$_stg_tmdl_expressions")

    old_string_1="XUO7C7SW7ONUHHLEI7JMT7CN3E-5NMTCG4VCUAELMP2UGNFR7CLCI.datawarehouse.fabric.microsoft.com"
    old_string_2="5ec27d10-f4e8-402c-8707-6c54fe94ef5c"

    content="${content//$old_string_1/$lakehouse_conn_string}"
    content="${content//$old_string_2/$lakehouse_conn_id}"
    echo "$content" > "$_stg_tmdl_expressions"
}

replace_report_metadata() {
    local report_name=$1
    local semantic_model_id=$2
    local _stg_report_json="$staging_dir/$report_name/definition.pbir"
    echo $_stg_report_json

    jq --arg _semantic_model_id "$semantic_model_id" \
    '.datasetReference.byConnection.pbiModelDatabaseName = $_semantic_model_id' \
        "$_stg_report_json" > "$_stg_report_json.tmp" && mv "$_stg_report_json.tmp" "$_stg_report_json"
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
