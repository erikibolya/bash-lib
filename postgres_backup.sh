#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 -h <host> -p <port> -d <database> -U <user> [-W <password>] -o <output_path>"
    echo "Options:"
    echo "  -h <host>         PostgreSQL host"
    echo "  -p <port>         PostgreSQL port"
    echo "  -d <database>     Database name"
    echo "  -U <user>         Database user"
    echo "  -W <password>     Database password (optional)"
    echo "  -o <output_path>  Output path with filename for the backup"
    exit 1
}

# Parse command line options
while getopts ":h:p:d:U:W:o:" opt; do
    case $opt in
        h) DB_HOST="$OPTARG" ;;
        p) DB_PORT="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        U) DB_USER="$OPTARG" ;;
        W) DB_PASSWORD="$OPTARG" ;;
        o) OUTPUT_PATH="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required options are provided
if [[ -z $DB_HOST || -z $DB_PORT || -z $DB_NAME || -z $DB_USER || -z $OUTPUT_PATH ]]; then
    echo "Error: Missing required options"
    usage
fi

# Prompt for password if not provided as argument
if [[ -z $DB_PASSWORD ]]; then
    read -s -p "Enter password for user $DB_USER: " DB_PASSWORD
fi

# Timestamp for backup file
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# Backup command
PGPASSWORD="$DB_PASSWORD" pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -w > $OUTPUT_PATH

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Backup of database $DB_NAME completed successfully"
else
    echo "Error: Backup of database $DB_NAME failed"
fi