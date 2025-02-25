#!/bin/bash

# fab demo: lakehouse tutorial

# default parameters
capacity_name=""
spn_auth_enabled="false"
upn_objectid=""
postfix="05"

# static, do not change
workspace_name="_ws_fab_tutorial_lakehouse"
demo_name="fab-demo-tutorial-lakehouse"

source ./common/scripts/utils.sh
parse_args "$@"
check_spn_auth

run_demo() {

    # metadata 
    _workspace_name="${workspace_name}_${postfix}.Workspace"
    _lakehouse_name_no_ext="wwilakehouse"
    _lakehouse_name="${_lakehouse_name_no_ext}.Lakehouse"
    _pipeline_name="IngestDataFromSourceToLakehouse.DataPipeline"
    _notebook_names=("01 - Create Delta Tables.Notebook" "02 - Data Transformation - Business Aggregates.Notebook")
    _sem_model_name="wwilakehousesm.SemanticModel"
    _report_name="ProfitReporting.Report"
    _sas_token="sv=2022-11-02&ss=b&srt=co&sp=rlx&se=2026-12-31T18:59:36Z&st=2025-01-31T10:59:36Z&spr=https&sig=aL%2FIOiwz2AEj1fL9tRxH%2B4z%2FyfBl8qJ3KXinfPlaSEM%3D"

    # workspace
    create_staging
    EXIT_ON_ERROR=false
    create_workspace $postfix

    # lakehouse
    echo -e "\n_ creating a lakehouse..."
    run_fab_command "create /${_workspace_name}/${_lakehouse_name}"

    # connections
    echo -e "\n_ creating a Blob connection..."
    run_fab_command "create .connections/conn_stfabdemos_blob_${_workspace_name}.Connection -P .connections/example001.Connection -P connectionDetails.type=AzureBlobs,connectionDetails.parameters.account=stfabdemos,connectionDetails.parameters.domain=blob.core.windows.net/fabdata,credentialDetails.type=Anonymous"

    echo -e "\n_ creating a ADLS Gen2 connection..."
    run_fab_command "create .connections/conn_stfabdemos_adlsgen2_${_workspace_name}.connection -P connectionDetails.type=AzureDataLakeStorage,connectionDetails.parameters.server=stfabdemos.dfs.core.windows.net,connectionDetails.parameters.path=fabdata,credentialDetails.type=SharedAccessSignature,credentialDetails.Token=$_sas_token"

    _connection_id_blob=$(run_fab_command "get .connections/conn_stfabdemos_blob_${_workspace_name}.Connection -q id" | tr -d '\r')
    _connection_id_adlsgen2=$(run_fab_command "get .connections/conn_stfabdemos_adlsgen2_${_workspace_name}.Connection -q id" | tr -d '\r')
    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')
    _lakehouse_id=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q id" | tr -d '\r')
    _lakehouse_conn_string=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q properties.sqlEndpointProperties.connectionString" | tr -d '\r')
    _lakehouse_conn_id=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q properties.sqlEndpointProperties.id" | tr -d '\r')

    EXIT_ON_ERROR=true

    # items
    echo -e "\n_ deploying items..."

    # pipeline
    replace_pipeline_metadata $_pipeline_name $_workspace_id $_lakehouse_id $_connection_id_blob
    echo -e "\n___ importing a pipeline..."
    run_fab_command "import -f /${_workspace_name}/${_pipeline_name} -i ${staging_dir}/${_pipeline_name}"

    # notebooks
    echo -e "\n___ importing notebook..."
    for _notebook_name in "${_notebook_names[@]}"; do
        run_fab_command "import -f /${_workspace_name}/${_notebook_name} -i ${staging_dir}/${_notebook_name}"
        run_fab_command "set -f /${_workspace_name}/${_notebook_name} -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${_lakehouse_name_no_ext}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"
    done
    wait

    # shortcut
    echo -e "\n___ creating a shortcut to ADLS Gen2..."
    run_fab_command "ln /${_workspace_name}/${_lakehouse_name}/Files/wwi-raw-data.Shortcut --type adlsGen2 -i \"{\"location\": \"https://stfabdemos.dfs.core.windows.net/\", \"subpath\": \"fabdata/WideWorldImportersDW\", \"connectionId\": \"${_connection_id_adlsgen2}\"}\" -f"

    # running jobs
    echo -e "\n_ running jobs..."
    echo -e "\n___ running pipeline..."
    run_fab_command "job run /${_workspace_name}/${_pipeline_name}"

    echo -e "\n___ running notebook..."
    run_fab_command "job run /${_workspace_name}/01 - Create Delta Tables.Notebook"

    echo -e "\n___ running notebook..."
    run_fab_command "job run /${_workspace_name}/02 - Data Transformation - Business Aggregates.Notebook"

    # semantic model
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "XUO7C7SW7ONUHHLEI7JMT7CN3E-5NMTCG4VCUAELMP2UGNFR7CLCI.datawarehouse.fabric.microsoft.com" $_lakehouse_conn_string
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "5ec27d10-f4e8-402c-8707-6c54fe94ef5c" $_lakehouse_conn_id
    echo -e "\n___ importing a semantic model..."
    run_fab_command "import -f /${_workspace_name}/${_sem_model_name} -i ${staging_dir}/${_sem_model_name}"

    # report
    _semantic_model_id=$(run_fab_command "get /${_workspace_name}/${_sem_model_name} -q id" | tr -d '\r')
    replace_report_metadata ${_report_name} $_semantic_model_id

    echo -e "\n___ importing a report..."
    run_fab_command "import -f /${_workspace_name}/${_report_name} -i ${staging_dir}/${_report_name}"

    # open and clean up
    echo -e "\n_ opening workspace..."
    run_fab_command "open /${_workspace_name}"
    clean_up
}

run_demo