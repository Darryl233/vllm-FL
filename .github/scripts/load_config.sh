#!/bin/bash
# Unit configuration loading script
# Extracts unit configuration and groups tests by task
# Usage: source load_config.sh && load_config <unit_name>

set -euo pipefail

load_config() {
    local CONFIG_FILE=".github/configs/unit.yml"
    local UNIT_NAME=$1

    if [ -z "$UNIT_NAME" ]; then
        echo "❌ Error: No unit name provided."
        return 1
    fi

    echo "Loading configuration for: $CONFIG_FILE"
    echo "Loading configuration for unit: $UNIT_NAME"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: Unit configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Extract CI/CD configuration from .github/configs using yq
    echo "Extracting configuration from $CONFIG_FILE"
    DEPTH_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".unit-conf.$UNIT_NAME.depth" "$CONFIG_FILE")
    IGNORE_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".unit-conf.$UNIT_NAME.ignore" "$CONFIG_FILE")
    DESELECT_JSON=$(/usr/local/bin/yq -r  -o=json -I=0 ".unit-conf.$UNIT_NAME.deselect" "$CONFIG_FILE")

    echo "DEPTH_JSON: $DEPTH_JSON"
    echo "IGNORE_JSON: $IGNORE_JSON"
    echo "DESELECT_JSON: $DESELECT_JSON"

    # Validate required fields
    if [ -z "$DEPTH_JSON" ] || [ -z "$IGNORE_JSON" ] || [ -z "$DESELECT_JSON" ]; then
        echo "❌ Error: One or more required fields are missing in unit config '$UNIT_NAME'."
        return 1
    fi

    if [ "$DEPTH_JSON" = "all" ]; then
        DEPTH=$(find "tests" -type d | awk -F/ '{print NF-1}' | sort -nr | head -n 1)
    else
        DEPTH="$DEPTH_JSON"
    fi

    TEST_FILES=$(find "tests/$UNIT_NAME" -mindepth 1 -maxdepth $DEPTH -type f -name "test_*.py" | tr '\n' ',' | sed 's/,/ /g; s/ $//')

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
