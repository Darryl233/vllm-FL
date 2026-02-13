#!/bin/bash
# Test configuration loading script
# Extracts test configuration and groups tests by task
# Usage: source load_config.sh && load_config <subset_name> [config_file] [config_key]

set -euo pipefail

load_config() {
    local UNIT_NAME=$1
    local CONFIG_FILE="${2:-.github/configs/unit.yml}"
    local CONFIG_KEY="${3:-unit-conf}"

    if [ -z "$UNIT_NAME" ]; then
        echo "❌ Error: No subset name provided."
        return 1
    fi

    echo "Loading configuration for: $CONFIG_FILE"
    echo "Loading configuration for subset: $UNIT_NAME"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Extract CI/CD configuration from .github/configs using yq
    echo "Extracting configuration from $CONFIG_FILE"
    DEPTH_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".$CONFIG_KEY.$UNIT_NAME.depth" "$CONFIG_FILE")
    IGNORE_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".$CONFIG_KEY.$UNIT_NAME.ignore" "$CONFIG_FILE")
    DESELECT_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".$CONFIG_KEY.$UNIT_NAME.deselect" "$CONFIG_FILE")
    PATH_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".$CONFIG_KEY.$UNIT_NAME.path" "$CONFIG_FILE")

    echo "DEPTH_JSON: $DEPTH_JSON"
    echo "IGNORE_JSON: $IGNORE_JSON"
    echo "DESELECT_JSON: $DESELECT_JSON"
    echo "PATH_JSON: $PATH_JSON"

    # Validate required fields
    if [ -z "$DEPTH_JSON" ] || [ -z "$IGNORE_JSON" ] || [ -z "$DESELECT_JSON" ]; then
        echo "❌ Error: One or more required fields are missing in config '$UNIT_NAME'."
        return 1
    fi

    if [ "$DEPTH_JSON" = "all" ]; then
        DEPTH=$(find "tests" -type d | awk -F/ '{print NF-1}' | sort -nr | head -n 1)
    else
        DEPTH="$DEPTH_JSON"
    fi

    # Determine test directory: explicit path > source_dir special case > tests/$UNIT_NAME
    local TEST_DIR
    if [ "$PATH_JSON" != "null" ] && [ -n "$PATH_JSON" ]; then
        TEST_DIR="$PATH_JSON"
    elif [ "$UNIT_NAME" = "source_dir" ]; then
        TEST_DIR="tests"
    else
        TEST_DIR="tests/$UNIT_NAME"
    fi

    TEST_FILES=$(find "$TEST_DIR" -mindepth 1 -maxdepth $DEPTH -type f -name "test_*.py" | tr '\n' ',' | sed 's/,/ /g; s/ $//')

    if [ $(echo $IGNORE_JSON | jq 'length') -gt 0 ]; then
        IGNORE=$(echo $IGNORE_JSON | jq -r '.[] | "--ignore=\(.)"' | tr '\n' ' ')
    else
        IGNORE="pass"
    fi

    if [ $(echo $DESELECT_JSON | jq 'length') -gt 0 ]; then
        DESELECT=$(echo $DESELECT_JSON | jq -r '.[] | "--deselect=\(.)"' | tr '\n' ' ')
    else
        DESELECT="pass"
    fi

    echo "ignore=$IGNORE" >> $GITHUB_OUTPUT
    echo "deselect=$DESELECT" >> $GITHUB_OUTPUT
    echo "test_files=$TEST_FILES" >> $GITHUB_OUTPUT
}
