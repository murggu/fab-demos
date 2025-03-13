#!/bin/bash

# fab demo: lakehouse tutorial

# default parameters
capacity_name=""
spn_auth_enabled="false"
upn_objectid=""
postfix="05"

# static, do not change
workspace_name="_ws_fab_tutorial_data_science"
demo_name="fab-demo-tutorial-data-science"

source ./scripts/utils.sh
parse_args "$@"
check_spn_auth

run_demo() {

    # metadata 
    _workspace_name="${workspace_name}_${postfix}.Workspace"
    _lakehouse_name_no_ext="tutdatascience"
    _lakehouse_name="${_lakehouse_name_no_ext}.Lakehouse"
    _notebook_names=("1-ingest-data.Notebook" "2-explore-cleanse-data.Notebook" "3-train-evaluate.Notebook" "4-predict.Notebook")
    _sem_model_name="bank-churn-predictions.SemanticModel"
    _report_name="bank-churn-predictions.Report"

    # workspace
    create_staging
    EXIT_ON_ERROR=false
    create_workspace $postfix

    # lakehouse
    echo -e "\n_ creating a lakehouse..."
    run_fab_command "create /${_workspace_name}/${_lakehouse_name}"

    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')
    _lakehouse_id=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q id" | tr -d '\r')
    _lakehouse_conn_string=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q properties.sqlEndpointProperties.connectionString" | tr -d '\r')
    _lakehouse_conn_id=$(run_fab_command "get /${_workspace_name}/${_lakehouse_name} -q properties.sqlEndpointProperties.id" | tr -d '\r')

    EXIT_ON_ERROR=true

    # items
    echo -e "\n_ deploying items..."

    # notebooks
    echo -e "\n___ importing notebook..."
    for _notebook_name in "${_notebook_names[@]}"; do
        run_fab_command "import -f /${_workspace_name}/${_notebook_name} -i ${staging_dir}/${_notebook_name}"
        run_fab_command "set -f /${_workspace_name}/${_notebook_name} -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${_lakehouse_name_no_ext}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"
    done
    wait

    # running jobs
    # echo -e "\n___ running notebook..."
    # run_fab_command "job run /${_workspace_name}/1-ingest-data.Notebook"

    # echo -e "\n___ running notebook..."
    # run_fab_command "job run /${_workspace_name}/2-explore-cleanse-data.Notebook"

    # echo -e "\n___ running notebook..."
    # run_fab_command "job run /${_workspace_name}/3-train-evaluate.Notebook"

    # echo -e "\n___ running notebook..."
    # run_fab_command "job run /${_workspace_name}/4-predict.Notebook"

    # semantic model
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "XUO7C7SW7ONUHHLEI7JMT7CN3E-PIPPMNTPQLHUDNRNHY4CWQJVXQ.datawarehouse.fabric.microsoft.com" $_lakehouse_conn_string
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "a22df860-cf94-446e-bbde-ac2ac1eaf0fe" $_lakehouse_conn_id
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