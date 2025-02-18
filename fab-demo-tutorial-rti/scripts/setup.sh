#!/bin/bash

# fab cli
# demo: rti tutorial

source ./common/scripts/utils.sh
read_config
check_spn_auth

run_demo(){
    local postfix=$1

    create_staging
    create_workspace $postfix

    _workspace_name="${workspace_name}_${postfix}.Workspace"
    _eventhouse_name="Tutorial.EventHouse"
    _kql_db_name="Tutorial.KQLDatabase"
    _eventstream_name="TutorialEventStream.EventStream"
    _kql_dh_name="TutorialDashboard.KQLDashboard"

    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')

    # Deploy eventhouse
    echo -e "\n_ importing an eventhouse..."
    run_fab_command "import -f /${_workspace_name}/${_eventhouse_name} -i ${staging_dir}/${_eventhouse_name}"
    _eventhouse_id=$(run_fab_command "get /${_workspace_name}/${_eventhouse_name} -q id" | tr -d '\r')

    replace_kql_parent_eventhouse $_kql_db_name $_eventhouse_id

    # Deploy KQL database
    echo -e "\n_ importing a kql database..."
    run_fab_command "import -f /${_workspace_name}/${_kql_db_name} -i ${staging_dir}/${_kql_db_name}"
    _kql_db_id=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q id" | tr -d '\r')
    _cluster_uri=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q properties.queryServiceUri" | tr -d '\r')
    

    replace_eventstream_destination_eventhouse $_eventstream_name $_workspace_id $_kql_db_id

    # Deploy eventstream
    echo -e "\n_ importing an eventstream..."
    run_fab_command "import -f /${_workspace_name}/${_eventstream_name} -i ${staging_dir}/${_eventstream_name}"

    replace_kqldashboard_datasource $_kql_dh_name $_workspace_id $_kql_db_id $_cluster_uri

    # Deploy KQL dashboard
    echo -e "\n_ importing a kql dashboard..."
    run_fab_command "import -f /${_workspace_name}/${_kql_dh_name} -i ${staging_dir}/${_kql_dh_name}"

    # TODO: add additional kqlqueryset, powerbi report and semantic model
}

run_demo "rti01"