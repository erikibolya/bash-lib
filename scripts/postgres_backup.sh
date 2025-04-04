#!/bin/bash
set -e;

source "${BASH_SOURCE%/*}/../core.sh";

dependencies "pgclient";

# init variable
DB_HOST=
DB_PORT=
DB_NAME=
DB_USER=
DB_PASSWORD=
OUTPUT_PATH=
FILENAME=

# Default values
DB_PORT="5432";
OUTPUT_PATH="./";
FILENAME=$(date +"%Y-%m-%d_%H-%M-%S");


# Usage message
usage() {
    echo "Usage: $0 -h <host> [-p <port>] [-d <database>] -U <user> [-W <password>] -o <output_path> -f <filename>"
    echo "Options:"
    echo "  -h <host>         PostgreSQL host"
    echo "  -p <port>         PostgreSQL port (default is 5432)"
    echo "  -d <database>     Database name (optional)"
    echo "  -U <user>         Database user"
    echo "  -W <password>     Database password (optional)"
    echo "  -o <output_path>  Output path for the backup (default is ./)"
    echo "  -f <filename>     Filename for the backup (default is current date in format %Y-%m-%d_%H-%M-%S)"
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
        f) FILENAME="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required options are provided
if [[ -z $DB_HOST || -z $DB_USER || -z $OUTPUT_PATH ]]; then
    echo "Error: Missing required options"
    usage
fi

# Prompt for password if not provided as argument
if [[ -z $DB_PASSWORD ]]; then
    read -s -p "Enter password for user $DB_USER: " DB_PASSWORD
fi




# Backup command
if [ -z $DB_NAME ]; then
    cecho $BLUE "Backing up whole database on $DB_HOST:$DB_PORT";
    PGPASSWORD="$DB_PASSWORD" pg_dumpall -h $DB_HOST -p $DB_PORT -U $DB_USER -w > "$OUTPUT_PATH$FILENAME"
else
    cecho $BLUE "Backing up database $DB_NAME on $DB_HOST:$DB_PORT";
    PGPASSWORD="$DB_PASSWORD" pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -w > "$OUTPUT_PATH$FILENAME"
fi

# Check if backup was successful
if [ $? -eq 0 ]; then
    cecho $GREEN "Backup completed successfully"
else
    cecho $RED "Error: Backup failed"
fi