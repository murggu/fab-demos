#!/bin/bash

# Get the abbreviation for a given item type
get_abbreviation() {
    local itemType=$1
    case $itemType in
        Capacity) echo "cap" ;;
        Connection) echo "conn" ;;
        Dashboard) echo "db" ;;
        Datamart) echo "dm" ;;
        DataPipeline) echo "pip" ;;
        Domain) echo "dom" ;;
        Environment) echo "env" ;;
        Eventhouse) echo "eh" ;;
        Eventstream) echo "es" ;;
        ExternalDataShare) echo "eds" ;;
        Gateway) echo "gw" ;;
        KQLDashboard) echo "kd" ;;
        KQLDatabase) echo "kdb" ;;
        KQLQueryset) echo "kqs" ;;
        Lakehouse) echo "lh" ;;
        ManagedIdentity) echo "mi" ;;
        ManagedPrivateEndpoint) echo "mpe" ;;
        MirroredDatabase) echo "mdb" ;;
        MLExperiment) echo "mle" ;;
        MLModel) echo "mlm" ;;
        Notebook) echo "nb" ;;
        PaginatedReport) echo "pr" ;;
        Reflex) echo "rfx" ;;
        Report) echo "rpt" ;;
        SemanticModel) echo "sm" ;;
        SparkJobDefinition) echo "sjd" ;;
        SparkPool) echo "sp" ;;
        Warehouse) echo "wh" ;;
        Workspace) echo "ws" ;;
        *) echo "unknown" ;;
    esac
}

# Get all abbreviations in a single line
get_all_abbreviations() {
    echo "Capacity=cap"
    echo "Connection=conn"
    echo "Dashboard=db"
    echo "Datamart=dm"
    echo "DataPipeline=pip"
    echo "Domain=dom"
    echo "Environment=env"
    echo "Eventhouse=eh"
    echo "Eventstream=es"
    echo "ExternalDataShare=eds"
    echo "Gateway=gw"
    echo "KQLDashboard=kd"
    echo "KQLDatabase=kdb"
    echo "KQLQueryset=kqs"
    echo "Lakehouse=lh"
    echo "ManagedIdentity=mi"
    echo "ManagedPrivateEndpoint=mpe"
    echo "MirroredDatabase=mdb"
    echo "MLExperiment=mle"
    echo "MLModel=mlm"
    echo "Notebook=nb"
    echo "PaginatedReport=pr"
    echo "Reflex=rfx"
    echo "Report=rpt"
    echo "SemanticModel=sm"
    echo "SparkJobDefinition=sjd"
    echo "SparkPool=sp"
    echo "Warehouse=wh"
    echo "Workspace=ws"
}

# # Example usage
# all_abbreviations=$(get_all_abbreviations)
# echo "All abbreviations: $all_abbreviations"

# # To get a specific abbreviation
# itemType="Notebook"
# abbreviation=$(get_abbreviation "$itemType")
# echo "Abbreviation for $itemType: $abbreviation"

# # Example of obtaining a notebook abbreviation from all_abbreviations
# declare -A abbreviations
# eval "abbreviations=($(get_all_abbreviations | sed 's/ / /g'))"
# notebook_abbreviation=${abbreviations["Notebook"]}
# echo "Abbreviation for Notebook from all_abbreviations: $notebook_abbreviation"
