#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

source "${BASH_SOURCE%/*}/../core.sh";

dependencies "docker-ce";

# Usage message
usage() {
    echo "Usage: $0 -c <container>"
    echo "Options:"
    echo "  -c <container>    Container name or id"
    exit 1
}

# Parse command line options
while getopts ":c:" opt; do
    case $opt in
        h) CONTAINER="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required options are provided
if [[ -z $CONTAINER ]]; then
    echo "Error: Missing required options"
    usage
fi

docker stop $CONTAINER

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Docker container succesfully stopped"
else
    echo "Error: Failed to stop container"
fi