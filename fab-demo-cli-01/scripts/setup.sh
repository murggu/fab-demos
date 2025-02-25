#!/bin/bash

# fab demo: sample 01

# default parameters
capacity_name=""
spn_auth_enabled="false"
upn_objectid=""
postfix="05"

# static, do not change
workspace_name="_ws_fab_demo_cli_01"
demo_name="fab-demo-cli-01"

source ./common/scripts/utils.sh
parse_args "$@"
check_spn_auth


run_demo() {

}

run_demo