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

create_staging(){
    echo -e "\n_ creating staging directory..."
    mkdir -p "$staging_dir"
    cp -r ./${demo_name}/workspace/* $staging_dir/
    echo "* Done"
}

read_config
create_staging

_stg_tmdl_expressions="$staging_dir/wwilakehouse.SemanticModel/definition/expressions.tmdl"
_stg_pip_json="$staging_dir/IngestDataFromSourceToLakehouse.DataPipeline/pipeline-content.json"

# create a domain
echo -e "\n_ creating a domain..."
run_fab_command "create /.domains/${domain_name}.Domain"
echo "* Done"

# create a workspace
echo -e "\n_ creating a workspace..."
run_fab_command "create /${workspace_name}.Workspace -P capacityName=${capacity_name}"
echo "* Done"

# create a lakehouse
echo -e "\n_ creating a lakehouse..."
run_fab_command "create /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -P schemasEnabled=${enable_lakehouse_schemas}"
echo "* Done"

# # create a connection
# echo -e "\n_ creating a connection..."
# run_fab_command "create .connections/conn3.Connection -P connectionDetails.type=HttpServer,connectionDetails.parameters.url=https://assetsprod.microsoft.com/en-us/wwi-sample-dataset.zip,credentialDetails.type=Anonymous,credentialDetails.singleSignOnType=None,credentialDetails.connectionEncryption=NotEncrypted,credentialDetails.skipTestConnection=false"
# echo "* Done"

# create a connection
echo -e "\n_ creating a connection..."
run_fab_command "create .connections/conn_stfabdemos.Connection -P .connections/example001.Connection -P connectionDetails.type=AzureBlobs,connectionDetails.parameters.account=stfabdemos,connectionDetails.parameters.domain=blob.core.windows.net/fabdata,credentialDetails.type=Anonymous"
echo "* Done"

echo -e "\n_ getting metadata..."
_connection_id=$(run_fab_command "get .connections/conn_stfabdemos.Connection -q id" | tr -d '\r')
_workspace_id=$(run_fab_command "get /${workspace_name}.Workspace -q id" | tr -d '\r')
_lakehouse_id=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q id" | tr -d '\r')
_lakehouse_conn_string=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q properties.sqlEndpointProperties.connectionString" | tr -d '\r')
_lakehouse_conn_id=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q properties.sqlEndpointProperties.id" | tr -d '\r')
echo " ___ > connection_id: $_connection_id"
echo " ___ > workspace_id: $_workspace_id"
echo "\___ > lakehouse_id: $_lakehouse_id"
echo "\___ > lakehouse_conn_string: $_lakehouse_conn_string"
echo " ___ > lakehouse_conn_id: $_lakehouse_conn_id"
echo "* Done"

# import items
echo -e "\n_ importing items..."

# # pipeline
echo -e "\n ___replacing pipeline metadata (rebind connection and lakehouse)..."
jq --arg workspace_id "$_workspace_id" \
   --arg lakehouse_id "$_lakehouse_id" \
   --arg connection_id "$_connection_id" \
   '.properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.workspaceId = $workspace_id |
    .properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.artifactId = $lakehouse_id |
    .properties.activities[].typeProperties.source.datasetSettings.externalReferences.connection = $connection_id' \
    "$_stg_pip_json" > "$_stg_pip_json.tmp" && mv "$_stg_pip_json.tmp" "$_stg_pip_json"
echo "* Done"

echo -e "\n___ importing a pipeline..."
run_fab_command "import -f /${workspace_name}.Workspace/IngestDataFromSourceToLakehouse.DataPipeline -i ${staging_dir}/IngestDataFromSourceToLakehouse.DataPipeline"
echo "* Done"

notebook
echo -e "\n___ importing a notebook..."
run_fab_command "import -f /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook -i ${staging_dir}/01 - Create Delta Tables.Notebook"
echo "* Done"

echo -e "\n___ replacing notebook metadata (rebind to lakehouse)..."
run_fab_command "set -f /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${lakehouse_name}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"
echo "* Done"

# notebook
echo -e "\n___ importing a notebook..."
run_fab_command "import -f /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook -i ${staging_dir}/02 - Data Transformation - Business Aggregates.Notebook"
echo "* Done"

echo -e "\n___ replacing notebook metadata (rebind to lakehouse)..."
run_fab_command "set -f /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${lakehouse_name}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"
echo "* Done"

echo -e "\n___ replacing report metadata (rebind to semantic model)..."
run_fab_command "set -f /${workspace_name}.Workspace/Profit Reporting.Report -q semanticModelId -i ${_semantic_model_id}"

shortcut
echo -e "\n_ creating a shortcut to ADLS Gen2..."
run_fab_command "ln /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse/Files/wwi-raw-data.Shortcut --type adlsGen2 -i \"{\"location\": \"https://stfabdemos.dfs.core.windows.net/\", \"subpath\": \"fabdata/WideWorldImportersDW\", \"connectionId\": \"4fc37846-29c0-46b4-81db-2539f0559c04\"}\" -f"

running jobs
echo -e "\n_ running jobs..."

echo -e "\n___ running pipeline..."
run_fab_command "job run /${workspace_name}.Workspace/IngestDataFromSourceToLakehouse.DataPipeline"
echo "* Done"

echo -e "\n___ running notebook..."
run_fab_command "job run /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook"
echo "* Done"

echo -e "\n___ running notebook..."
run_fab_command "job run /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook"
echo "* Done"

# semantic model
echo -e "\n_ replacing semantic model metadata (data sources)..."
echo $_stg_tmdl_expressions
content=$(cat "$_stg_tmdl_expressions")

old_string_1="XUO7C7SW7ONUHHLEI7JMT7CN3E-5NMTCG4VCUAELMP2UGNFR7CLCI.datawarehouse.fabric.microsoft.com"
old_string_2="5ec27d10-f4e8-402c-8707-6c54fe94ef5c"

content="${content//$old_string_1/$_lakehouse_conn_string}"
content="${content//$old_string_2/$_lakehouse_conn_id}"
echo "$content" > "$_stg_tmdl_expressions"
echo "* Done"

echo -e "\n___ importing a semantic model..."
run_fab_command "import -f /${workspace_name}.Workspace/wwilakehouse1.SemanticModel -i ${staging_dir}/wwilakehouse.SemanticModel"
echo "* Done"

 # report
_semantic_model_id=$(run_fab_command "get /${workspace_name}.Workspace/wwilakehouse1.SemanticModel -q id" | tr -d '\r')

echo -e "\n___ importing a report..."
run_fab_command "import -f /${workspace_name}.Workspace/Profit Reporting.Report -i ${staging_dir}/Profit Reporting.Report"
echo "* Done"


# azcopy from github to lakehouse

# load to table
# echo -e "\n_ loading dimension_customer table..."
# run_fab_command "table load /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse/Tables/dimension_customer --file /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse/Files/csv"
