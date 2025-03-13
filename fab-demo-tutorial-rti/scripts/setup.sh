#!/bin/bash

# fab demo: rti tutorial

# default parameters
capacity_name=""
spn_auth_enabled="false"
upn_objectid=""
postfix="19"

# static, do not change
workspace_name="fab_tutorial_rti"
demo_name="fab-demo-tutorial-rti"

source ./scripts/utils.sh
parse_args "$@"
check_spn_auth

run_demo() {

    # metadata 
    _workspace_name="${abbreviations["Workspace"]}_${workspace_name}_${postfix}.Workspace"
    _eventhouse_name="Tutorial.Eventhouse"
    _kql_db_name="Tutorial.KQLDatabase"
    _eventstream_name="TutorialEventstream.Eventstream"
    _kql_dh_name="TutorialDashboard.KQLDashboard"
    _kql_querysets=("TutorialQueryset.KQLQueryset" "Tutorial_queryset.KQLQueryset")
    _sem_model_name="TutorialReport.SemanticModel"
    _report_name="TutorialReport.Report"

    # workspace
    create_staging
    EXIT_ON_ERROR=false
    create_workspace $postfix
    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')

    # eventhouse
    EXIT_ON_ERROR=true
    import_eventhouse $_workspace_name $_eventhouse_name
    _eventhouse_id=$(run_fab_command "get /${_workspace_name}/${_eventhouse_name} -q id" | tr -d '\r')

    # kql database
    import_kql_database $_workspace_name $_kql_db_name $_eventhouse_id
    _kql_db_id=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q id" | tr -d '\r')
    _cluster_uri=$(run_fab_command "get /${_workspace_name}/${_kql_db_name} -q properties.queryServiceUri" | tr -d '\r')

    # eventstream
    import_eventstream $_workspace_name $_eventstream_name $_workspace_id $_kql_db_id

    # kql dashboard
    import_kql_dashboard $_workspace_name $_kql_dh_name $_workspace_id $_kql_db_id $_cluster_uri

    # kql querysets
    for _query_set in "${_kql_querysets[@]}"; do
        import_kql_queryset $_workspace_name $_query_set $_kql_db_id $_cluster_uri #&
    done
    # wait

    # change DQ source values for semantic model
    replace_string_value $_sem_model_name "definition/tables/Kusto Query Result.tmdl" "https://trd-56czdt1je8qzxvd82u.z7.kusto.fabric.microsoft.com" $_cluster_uri
    replace_string_value $_sem_model_name "definition/tables/Kusto Query Result.tmdl" "286d907e-8bc0-41ea-b41d-4b7188a7ebfd" $_kql_db_id

    # semantic model
    import_semantic_model $_workspace_name $_sem_model_name
    _semantic_model_id=$(run_fab_command "get /${_workspace_name}/${_sem_model_name} -q id" | tr -d '\r')

    # report
    import_powerbi_report $_workspace_name $_report_name $_semantic_model_id

    # open and clean up
    open_workspace $_workspace_name
    clean_up_staging
}

run_demo