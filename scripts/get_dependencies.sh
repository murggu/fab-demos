#!/bin/bash

# Define manual IDs in an array
manual_ids=(
    "workspace_id:00"
    "fuam_fabric_conn_id:01"
    "fuam_pbi_conn_id:02"
    "fuam_lakehouse_id:03"
)

deployment_order=()

# Extract logical IDs from manual_ids
for entry in "${manual_ids[@]}"; do
    IFS=':' read -r _ logicalid <<< "$entry"
    deployment_order+=("$logicalid")
done

# Function to recursively list relevant files
list_files_recursive() {
    find "$1" -type f \( -name "*.py" -o -name "*.json" -o -name "*.pbir" -o -name "*.platform" \) ! -name "report.json"
}

# Function to extract GUIDs from a file
extract_guids() {
    grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$1" | sort -u | grep -v '00000000-0000-0000-0000-000000000000'
}

# Function to get logical ID from JSON file
get_logical_id() {
    jq -r '.config.logicalId // empty' "$1" 2>/dev/null
}

# Function to process files
process_files() {
    base_path="$1"
    declare -A folder_map
    folder_order=(".Lakehouse" ".Notebook" ".DataPipeline" ".SemanticModel" ".Report")
    
    declare -A folder_map  # Ensure it's associative

    for suffix in "${folder_order[@]}"; do
        find "$base_path" -type d -name "*$suffix" | while read -r root; do
            item_name=$(basename "$root")
            logical_id=""
            guids=()

            while IFS= read -r file; do
                if [[ "$file" == *.platform ]]; then
                    logical_id=$(get_logical_id "$file")
                else
                    mapfile -t extracted_guids < <(extract_guids "$file")
                    guids+=("${extracted_guids[@]}")
                fi
            done < <(list_files_recursive "$root")

            folder_map["$item_name"]="{\"logical_id\": \"$logical_id\", \"guids\": [${guids[*]}]}"
        done
    done

    # Convert the associative array to JSON format
    json_result="{"
    for key in "${!folder_map[@]}"; do
        json_result+="\"$key\": ${folder_map[$key]},"
    done
    json_result="${json_result%,}}"  # Remove the trailing comma and close the JSON object

    echo "$json_result"
}

# Process files in the given path
base_path="$(dirname "$0")/../fab-demo-tutorial-lakehouse/workspace"
json_result=$(process_files "$base_path")

# Print the JSON result
echo "$json_result"





# echo "Processed Items: ${processed_items[@]}"

# echo "Deployment Order: ${deployment_order[@]}"
# echo "Total Processed Items: ${#processed_items[@]}"

# diff=$(( ${#deployment_order[@]} - ${#manual_ids[@]} ))
# if [[ "$diff" -ne "${#processed_items[@]}" ]]; then
#     echo "Warning: The deployment order does not match the number of items processed."
# fi

# # Write deployment order to JSON
# config_folder="$(dirname "$0")/../config"
# mkdir -p "$config_folder"
# json_file_path="$config_folder/deployment_order.json"

# echo '{ "manual": [], "automatic": [] }' | jq '.' > "$json_file_path"

# echo "Deployment order written to $json_file_path"