
source ./common/scripts/utils.sh
read_config
create_staging

# echo -e "\n_ creating a SPN..."
# az ad sp create-for-rbac --name fab-fuam-test --role "Contributor" --scopes /subscriptions/b1cd297b-e573-483f-ae53-1b8a08014127 --sdk-auth

# create a workspace
echo -e "\n_ creating a workspace..."
run_fab_command "create /${workspace_name}.Workspace -P capacityName=${capacity_name}"

# create a lakehouse
echo -e "\n_ creating a lakehouse..."
run_fab_command "create /${workspace_name}.Workspace/${lakehouse_name}.Lakehouse"

# create connections
echo -e "\n_ creating a connection..."
run_fab_command "create .connections/conn_pbi_service_api_admin.Connection -P connectionDetails.type=WebForPipeline,
connectionDetails.parameters.path=api.fabric.microsoft.com/v1/admin,
connectionDetails.parameters.audience=analysis.windows.net/powerbi/api,
credentialDetails.type=ServicePrincipal,
credentialDetails.tenantId=7ef11dbd-fb56-439b-9d64-47d2c9fc4dd9,
credentialDetails.servicePrincipalClientId=c689dab4-171b-4887-a327-4f6f85817b81,credentialDetails.servicePrincipalSecret=3Ax8Q~52f3NvnA~F7DyXcnEk7d2b86SHXppTodpa"

# echo -e "\n_ creating a ADLS Gen2 connection..."
# run_fab_command "create .connections/conn_fabric_service_api_admin.connection -P connectionDetails.type=WebForPipeline,connectionDetails.parameters.server=stfabdemos.dfs.core.windows.net,connectionDetails.parameters.path=fabdata,credentialDetails.type=SharedAccessSignature,credentialDetails.Token=$_sas_token"

# import notebook

# change default lakehouse

# run notebook
# 3Ax8Q~52f3NvnA~F7DyXcnEk7d2b86SHXppTodpa