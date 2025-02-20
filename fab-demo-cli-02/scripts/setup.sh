#!/bin/bash

# fab cli
# demo: rti tutorial

source ./common/scripts/utils.sh
read_config
check_spn_auth

run_demo() {
    local postfix=$1

    create_staging
    create_workspace $postfix

    _workspace_name="${workspace_name}_${postfix}.Workspace"
    _lakehouse_names=("TestLH.Lakehouse" "default_lh.Lakehouse")
    _notebook_names=("Notebook_2.Notebook" "sample_NB.Notebook")
    _shortcut_names=("customer" "lineitem" "nation" "orders" "partsupp" "region" "supplier")
    _sem_model_name="my_semantic_model.SemanticModel"
    _adls_gen2_sas="sv=2022-11-02&ss=b&srt=sco&sp=rwdlacyx&se=2026-02-26T18:43:43Z&st=2025-02-20T10:43:43Z&spr=https&sig=jrx84L1RVt4erdXp19X6qfMKXNSeIPjrdpPCyvCgWMM%3D"
    
    echo -e "\n_ creating workspace identity..."
    run_fab_command "create /${_workspace_name}/.managedidentities/notused.managedidentity"

    echo -e "\n_ creating lakehouses..."
    for _lakehouse_name in "${_lakehouse_names[@]}"; do
        run_fab_command "create /${_workspace_name}/${_lakehouse_name} -P enableschemas=true" &
    done
    wait

    # connections
    echo -e "\n_ creating a ADLS Gen2 connection..."
    run_fab_command "create .connections/fabriccatdemowcus.connection -P connectionDetails.type=AzureDataLakeStorage,connectionDetails.parameters.server=fabriccatdemowcus.dfs.core.windows.net,connectionDetails.parameters.path=/,credentialDetails.type=SharedAccessSignature,credentialDetails.Token=$_adls_gen2_sas"

    # metadata
    _workspace_id=$(run_fab_command "get /${_workspace_name} -q id" | tr -d '\r')
    _lakehouse_test_id=$(run_fab_command "get /${_workspace_name}/TestLH.Lakehouse -q id" | tr -d '\r')
    _lakehouse_default_id=$(run_fab_command "get /${_workspace_name}/default_lh.Lakehouse -q id" | tr -d '\r')
    _connection_id_adlsgen2=$(run_fab_command "get .connections/fabriccatdemowcus.Connection -q id" | tr -d '\r')
    _connection_id_datapipelines="94c424db-aa6e-49ca-899e-d9c6baf16b44" # not able to create with workspace identity in prod
    _lakehouse_conn_string=$(run_fab_command "get /${_workspace_name}/default_lh.Lakehouse -q properties.sqlEndpointProperties.connectionString" | tr -d '\r')
    _lakehouse_conn_id=$(run_fab_command "get /${_workspace_name}/default_lh.Lakehouse -q properties.sqlEndpointProperties.id" | tr -d '\r')

    #shortcuts
    echo -e "\n_ creating shortcuts..."
    _lakehouse_name="default_lh.Lakehouse"
    for _shortcut_name in "${_shortcut_names[@]}"; do
        _path="tpch1tbdbx/${_shortcut_name}"
        run_fab_command "ln /${_workspace_name}/${_lakehouse_name}/Tables/dbo/${_shortcut_name}.Shortcut --type adlsGen2 -i \"{\"location\": \"https://fabriccatdemowcus.dfs.core.windows.net/\", \"subpath\": \"${_path}\", \"connectionId\": \"${_connection_id_adlsgen2}\"}\" -f"
    done
    wait

    # notebooks
    echo -e "\n_ importing notebook..."
    for _notebook_name in "${_notebook_names[@]}"; do
        if [ "$_notebook_name" = "Notebook_2.Notebook" ]; then
            _lakehouse_id=$_lakehouse_test_id
            _lakehouse_name="TestLH.Lakehouse"
        else
            _lakehouse_id=$_lakehouse_default_id
            _lakehouse_name="default_lh.Lakehouse"
        fi

        run_fab_command "import -f /${_workspace_name}/${_notebook_name} -i ${staging_dir}/${_notebook_name} --format .py"
        run_fab_command "set -f /${_workspace_name}/${_notebook_name} -q lakehouse -i '{\"known_lakehouses\": [{\"id\": \"${_lakehouse_id}\"}],\"default_lakehouse\": \"${_lakehouse_id}\",\"default_lakehouse_name\": \"${_lakehouse_name}\",\"default_lakehouse_workspace_id\": \"${_workspace_id}\"}'"
    done
    wait

    # pipelines
    _notebook_two_id=$(run_fab_command "get /${_workspace_name}/Notebook_2.Notebook -q id" | tr -d '\r')
    _notebook_sample_id=$(run_fab_command "get /${_workspace_name}/sample_NB.Notebook -q id" | tr -d '\r')


    # grand child pipelines
    echo -e "\n_ importing grandchild pipeline..."
    _pipeline_name="grand_child_pipeline.DataPipeline"
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "00000000-0000-0000-0000-000000000000" $_workspace_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "7d26fe91-9db0-8a49-4925-106bb33927f1" $_lakehouse_test_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "f34ab8f9-0970-9d43-43ea-1ae359ade59f" $_notebook_two_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "4f428544-930f-44a6-b0ee-12691f533347" $_connection_id_adlsgen2
    run_fab_command "import -f /${_workspace_name}/${_pipeline_name} -i ${staging_dir}/${_pipeline_name}"

    # child pipelines
    echo -e "\n_ importing child pipelines..."
    _pipeline_name="child_pipeline_1.DataPipeline"
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "00000000-0000-0000-0000-000000000000" $_workspace_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "f34ab8f9-0970-9d43-43ea-1ae359ade59f" $_notebook_two_id
    run_fab_command "import -f /${_workspace_name}/${_pipeline_name} -i ${staging_dir}/${_pipeline_name}"
    
    _pipeline_grandchild_id=$(run_fab_command "get /${_workspace_name}/grand_child_pipeline.DataPipeline -q id" | tr -d '\r')

    _pipeline_name="child_pipeline_2.DataPipeline"
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "00000000-0000-0000-0000-000000000000" $_workspace_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "f34ab8f9-0970-9d43-43ea-1ae359ade59f" $_notebook_two_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "53ee7809-31d8-bb79-4b90-e3703ef60edf" $_notebook_sample_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "0de88002-2df4-b937-4763-d99e672d3007" $_pipeline_grandchild_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "7a789297-d7da-4303-8055-f4f13d7f844c" $_connection_id_datapipelines
    run_fab_command "import -f /${_workspace_name}/${_pipeline_name} -i ${staging_dir}/${_pipeline_name}"

    # master pipeline
    _pipeline_child1_id=$(run_fab_command "get /${_workspace_name}/child_pipeline_1.DataPipeline -q id" | tr -d '\r')
    _pipeline_child2_id=$(run_fab_command "get /${_workspace_name}/child_pipeline_2.DataPipeline -q id" | tr -d '\r')

    echo -e "\n_ importing master pipeline..."
    _pipeline_name="master_pipeline.DataPipeline"
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "00000000-0000-0000-0000-000000000000" $_workspace_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "7d26fe91-9db0-8a49-4925-106bb33927f1" $_lakehouse_test_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "53ee7809-31d8-bb79-4b90-e3703ef60edf" $_notebook_sample_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "4f428544-930f-44a6-b0ee-12691f533347" $_connection_id_adlsgen2
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "7a789297-d7da-4303-8055-f4f13d7f844c" $_connection_id_datapipelines
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "7106a074-fbc6-ba6b-45d8-15c59e40d0b4" $_pipeline_child1_id
    replace_string_value_json "${_pipeline_name}/pipeline-content.json" "a8ea3d42-21b7-be46-4d2b-7089a103d1e8" $_pipeline_child2_id
    run_fab_command "import -f /${_workspace_name}/${_pipeline_name} -i ${staging_dir}/${_pipeline_name}"

    # semantic mode;
    echo -e "\n_ importing a semantic model..."
    #replace_semanticmodel_metadata $_sem_model_name $_lakehouse_conn_string $_lakehouse_conn_id
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "X6EPS4XRQ2XUDENLFV6NAEO3I4-33IPJ5D5JDAUHLXSUXVACW5B7A.msit-datawarehouse.fabric.microsoft.com" $_lakehouse_conn_string
    replace_string_value $_sem_model_name "definition/expressions.tmdl" "3c134e08-130e-4697-973d-e07182264ff6" $_lakehouse_conn_id
    run_fab_command "import -f /${_workspace_name}/${_sem_model_name} -i ${staging_dir}/${_sem_model_name}"

    # report
    _report_name="custom_report.Report"
    _semantic_model_id=$(run_fab_command "get /${_workspace_name}/${_sem_model_name} -q id" | tr -d '\r')
    replace_bypath_to_byconnection ${_report_name} $_semantic_model_id

    echo -e "\n_ importing a report..."
    run_fab_command "import -f /${_workspace_name}/${_report_name} -i ${staging_dir}/${_report_name}"
  
    _report_name="report_default_Sm.Report"
    _semantic_model_id=$(run_fab_command "get /${_workspace_name}/default_lh.SemanticModel -q id" | tr -d '\r')
    replace_bypath_to_byconnection ${_report_name} $_semantic_model_id

    echo -e "\n_ importing a report..."
    run_fab_command "import -f /${_workspace_name}/${_report_name} -i ${staging_dir}/${_report_name}"
}

run_demo "01"