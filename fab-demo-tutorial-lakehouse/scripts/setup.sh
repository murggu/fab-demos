#!/bin/bash

# fab cli
# demo: lakehouse tutorial

source ./common/scripts/utils.sh
read_config
check_spn_auth


run_demo(){
    local postfix=$1

    create_staging
    create_workspace $postfix

    create_staging

    lakehouse_name="wwilakehouse"
    _stg_tmdl_expressions="$staging_dir/wwilakehouse.SemanticModel/definition/expressions.tmdl"
    _stg_pip_json="$staging_dir/IngestDataFromSourceToLakehouse.DataPipeline/pipeline-content.json"
    _sas_token="sv=2022-11-02&ss=b&srt=co&sp=rlx&se=2026-12-31T18:59:36Z&st=2025-01-31T10:59:36Z&spr=https&sig=aL%2FIOiwz2AEj1fL9tRxH%2B4z%2FyfBl8qJ3KXinfPlaSEM%3D"
    _stg_report_json="$staging_dir/Profit Reporting.Report/definition.pbir"

    # create a domain
    echo -e "\n_ creating a domain..."
    run_fab_command "create /.domains/${domain_name}.Domain"

    # create a workspace
    echo -e "\n_ creating a workspace..."
    run_fab_command "create /${workspace_name}.Workspace -P capacityName=${capacity_name}"

    if [ "$enable_spn_auth" == "true" ]; then
        echo -e "\n_ assigning permissions to workspace..."
        run_fab_command "acl set -f /${workspace_name}.Workspace -I $upn_objectid -R admin"
    fi

    # create a lakehouse
    echo -e "\n_ creating a lakehouse..."
    run_fab_command "create /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse"

    # create a connection
    echo -e "\n_ creating a connection..."
    run_fab_command "create .connections/conn_stfabdemos_blob_${workspace_name}.Connection -P .connections/example001.Connection -P connectionDetails.type=AzureBlobs,connectionDetails.parameters.account=stfabdemos,connectionDetails.parameters.domain=blob.core.windows.net/fabdata,credentialDetails.type=Anonymous"

    echo -e "\n_ creating a ADLS Gen2 connection..."
    run_fab_command "create .connections/conn_stfabdemos_adlsgen2_${workspace_name}.connection -P connectionDetails.type=AzureDataLakeStorage,connectionDetails.parameters.server=stfabdemos.dfs.core.windows.net,connectionDetails.parameters.path=fabdata,credentialDetails.type=SharedAccessSignature,credentialDetails.Token=$_sas_token"

    echo -e "\n_ getting metadata..."
    _connection_id_blob=$(run_fab_command "get .connections/conn_stfabdemos_blob_${workspace_name}.Connection -q id" | tr -d '\r')
    _connection_id_adlsgen2=$(run_fab_command "get .connections/conn_stfabdemos_adlsgen2_${workspace_name}.Connection -q id" | tr -d '\r')
    _workspace_id=$(run_fab_command "get /${workspace_name}.Workspace -q id" | tr -d '\r')
    _lakehouse_id=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q id" | tr -d '\r')
    _lakehouse_conn_string=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q properties.sqlEndpointProperties.connectionString" | tr -d '\r')
    _lakehouse_conn_id=$(run_fab_command "get /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse -q properties.sqlEndpointProperties.id" | tr -d '\r')
    echo " ___ > connection_id_blob: $_connection_id_blob"
    echo " ___ > connection_id_adlsgen2: $_connection_id_adlsgen2"
    echo " ___ > workspace_id: $_workspace_id"
    echo "\___ > lakehouse_id: $_lakehouse_id"
    echo "\___ > lakehouse_conn_string: $_lakehouse_conn_string"
    echo " ___ > lakehouse_conn_id: $_lakehouse_conn_id"

    # import items
    echo -e "\n_ importing items..."

    # pipeline
    echo -e "\n ___replacing pipeline metadata (rebind connection and lakehouse)..."
    jq --arg workspace_id "$_workspace_id" \
    --arg lakehouse_id "$_lakehouse_id" \
    --arg connection_id "$_connection_id_blob" \
    '.properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.workspaceId = $workspace_id |
        .properties.activities[].typeProperties.sink.datasetSettings.linkedService.properties.typeProperties.artifactId = $lakehouse_id |
        .properties.activities[].typeProperties.source.datasetSettings.externalReferences.connection = $connection_id' \
        "$_stg_pip_json" > "$_stg_pip_json.tmp" && mv "$_stg_pip_json.tmp" "$_stg_pip_json"
    echo "* Done"

    echo -e "\n___ importing a pipeline..."
    run_fab_command "import -f /${workspace_name}.Workspace/IngestDataFromSourceToLakehouse.DataPipeline -i ${staging_dir}/IngestDataFromSourceToLakehouse.DataPipeline"

    # notebook
    echo -e "\n___ importing a notebook..."
    run_fab_command "import -f /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook -i ${staging_dir}/01 - Create Delta Tables.Notebook"

    echo -e "\n___ replacing notebook metadata (rebind to lakehouse)..."
    run_fab_command "set -f /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${lakehouse_name}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"

    # notebook
    echo -e "\n___ importing a notebook..."
    run_fab_command "import -f /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook -i ${staging_dir}/02 - Data Transformation - Business Aggregates.Notebook"

    echo -e "\n___ replacing notebook metadata (rebind to lakehouse)..."
    run_fab_command "set -f /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${lakehouse_name}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"

    # shortcut
    echo -e "\n_ creating a shortcut to ADLS Gen2..."
    run_fab_command "ln /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse/Files/wwi-raw-data.Shortcut --type adlsGen2 -i \"{\"location\": \"https://stfabdemos.dfs.core.windows.net/\", \"subpath\": \"fabdata/WideWorldImportersDW\", \"connectionId\": \"${_connection_id_adlsgen2}\"}\" -f"

    # running jobs
    echo -e "\n_ running jobs..."

    echo -e "\n___ running pipeline..."
    run_fab_command "job run /${workspace_name}.Workspace/IngestDataFromSourceToLakehouse.DataPipeline"

    echo -e "\n___ running notebook..."
    run_fab_command "job run /${workspace_name}.Workspace/01 - Create Delta Tables.Notebook"

    echo -e "\n___ running notebook..."
    run_fab_command "job run /${workspace_name}.Workspace/02 - Data Transformation - Business Aggregates.Notebook"

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
    echo $_semantic_model_id

    echo -e "\n ___ replacing report metadata (rebind to semantic model)..."
    jq --arg semantic_model_id "$_semantic_model_id" \
    '.datasetReference.byConnection.pbiModelDatabaseName = $semantic_model_id' \
        "$_stg_report_json" > "$_stg_report_json.tmp" && mv "$_stg_report_json.tmp" "$_stg_report_json"
    echo "* Done"

    echo -e "\n___ importing a report..."
    run_fab_command "import -f /${workspace_name}.Workspace/Profit Reporting.Report -i ${staging_dir}/Profit Reporting.Report"
    echo "* Done"
    
}

run_demo "lh01"
