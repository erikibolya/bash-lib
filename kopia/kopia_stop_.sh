#!/bin/bash

# Get the directory of the current script
current_dir="$(dirname "$0")"

# File to load
file_to_load="$current_dir/../install_docker.sh"

# Check if the file exists
if [ -f "$file_to_load" ]; then
    # Load the other script
    source "$file_to_load"
else
    echo "Error: File '$file_to_load' does not exist."
    exit 1
fi

rm -f /app/db_backups/postgres/dumpall.sql

PGPASSWORD=Xts80i2e2rr4jvO1 pg_dumpall -h 192.168.68.115 -U postgres > /app/db_backups/postgres/dumpall.sql