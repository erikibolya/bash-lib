#!/bin/bash
set -e

source "${BASH_SOURCE%/*}/../core.sh"

dependencies "pgclient"

# Default values
DB_PORT="5432"
OUTPUT_PATH="./"
FILENAME=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="${FILENAME}.sql"

# Initialize variables
DB_HOST=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""

# Usage message
usage() {
    echo "Usage: $0 -h <host> [-p <port>] [-d <database>] -U <user> [-W <password>] [-o <output_path>] [-f <filename>]"
    echo ""
    echo "Required:"
    echo "  -h <host>         PostgreSQL host"
    echo "  -U <user>         Database user"
    echo ""
    echo "Optional:"
    echo "  -p <port>         PostgreSQL port (default: 5432)"
    echo "  -d <database>     Specific database name to backup (defaults to all databases)"
    echo "  -W <password>     Database password (will prompt if not provided)"
    echo "  -o <output_path>  Output path for the backup (default: ./)"
    echo "  -f <filename>     Filename for the backup (default: timestamped)"
    exit 1
}

# Parse command line options
while getopts ":h:p:d:U:W:o:f:" opt; do
    case $opt in
        h) DB_HOST="$OPTARG" ;;
        p) DB_PORT="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        U) DB_USER="$OPTARG" ;;
        W) DB_PASSWORD="$OPTARG" ;;
        o) OUTPUT_PATH="$OPTARG" ;;
        f) FILENAME="$OPTARG.sql" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check required arguments
if [[ -z "$DB_HOST" || -z "$DB_USER" ]]; then
    echo "Error: Missing required options"
    usage
fi

# Prompt for password if not provided
if [[ -z "$DB_PASSWORD" ]]; then
    read -s -p "Enter password for user $DB_USER: " DB_PASSWORD
    echo
fi

# Ensure output path exists
mkdir -p "$OUTPUT_PATH"

# Perform backup
if [[ -z "$DB_NAME" ]]; then
    cecho $BLUE "Backing up all databases on $DB_HOST:$DB_PORT into ${OUTPUT_PATH%/}/$FILENAME"
    if PGPASSWORD="$DB_PASSWORD" pg_dumpall -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -w > "${OUTPUT_PATH%/}/$FILENAME"; then
        cecho $GREEN "Backup completed successfully"
    else
        cecho $RED "Error: Backup failed"
    fi
else
    cecho $BLUE "Backing up database '$DB_NAME' on $DB_HOST:$DB_PORT into ${OUTPUT_PATH%/}/$FILENAME"
    if PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -w > "${OUTPUT_PATH%/}/$FILENAME"; then
        cecho $GREEN "Backup completed successfully"
    else
        cecho $RED "Error: Backup failed"
    fi
fi