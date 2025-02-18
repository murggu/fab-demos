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
    _kql_querysets=("TutorialQueryset.KQLQueryset" "Tutorial_queryset.KQLQueryset")
    _sem_model_name="TutorialReport.SemanticModel"
    _report_name="TutorialReport.Report"

    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')

    # deploy eventhouse
    echo -e "\n_ importing an eventhouse..."
    run_fab_command "import -f /${_workspace_name}/${_eventhouse_name} -i ${staging_dir}/${_eventhouse_name}"
    _eventhouse_id=$(run_fab_command "get /${_workspace_name}/${_eventhouse_name} -q id" | tr -d '\r')

    replace_kql_parent_eventhouse $_kql_db_name $_eventhouse_id

    # deploy KQL database
    echo -e "\n_ importing a kql database..."
    run_fab_command "import -f /${_workspace_name}/${_kql_db_name} -i ${staging_dir}/${_kql_db_name}"
    _kql_db_id=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q id" | tr -d '\r')
    _cluster_uri=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q properties.queryServiceUri" | tr -d '\r')

    replace_eventstream_destination_eventhouse $_eventstream_name $_workspace_id $_kql_db_id

    # deploy eventstream
    echo -e "\n_ importing an eventstream..."
    run_fab_command "import -f /${_workspace_name}/${_eventstream_name} -i ${staging_dir}/${_eventstream_name}"

    replace_kqldashboard_datasource $_kql_dh_name $_workspace_id $_kql_db_id $_cluster_uri

    # deploy KQL dashboard
    echo -e "\n_ importing a kql dashboard..."
    run_fab_command "import -f /${_workspace_name}/${_kql_dh_name} -i ${staging_dir}/${_kql_dh_name}"

    # deploy KQL querysets (optional)
    echo -e "\n_ importing kql querysets..."
    for _query_set in "${_kql_querysets[@]}"; do
    (
        replace_kqlqueryset_connection $_query_set $_kql_db_id $_cluster_uri
        run_fab_command "import -f /${_workspace_name}/${_query_set} -i ${staging_dir}/${_query_set}"
    ) &
    done

    wait

    # deploy semantic model
    replace_string_value_on_table $_sem_model_name "Kusto Query Result" "https://trd-56czdt1je8qzxvd82u.z7.kusto.fabric.microsoft.com" $_cluster_uri
    replace_string_value_on_table $_sem_model_name "Kusto Query Result" "286d907e-8bc0-41ea-b41d-4b7188a7ebfd" $_kql_db_id

    echo -e "\n_ importing a semantic model..."
    run_fab_command "import -f /${_workspace_name}/${_sem_model_name} -i ${staging_dir}/${_sem_model_name}"

    _semantic_model_id=$(run_fab_command "get /${_workspace_name}/${_sem_model_name} -q id" | tr -d '\r')

    # deploy report
    echo -e "\n_ importing reports..."
    replace_bypath_to_byconnection $_report_name $_semantic_model_id
    run_fab_command "import -f /${_workspace_name}/${_report_name} -i ${staging_dir}/${_report_name}"
}

run_demo "rti03"