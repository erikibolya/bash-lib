#!/bin/bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[0;37m'
RESET='\033[0m'  # Reset color

# Function to print colored messages
cecho() {
    local color=$1
    shift
    echo -e "${color}$*${RESET}"
}

# Function to check if a file exists
file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        cecho $YELLOW "WARNING: File '$file' not found." >&2
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        cecho $YELLOW "Warning: Command '$cmd' not found." >&2
        return 1
    fi
}


# Function to get the current directory
get_current_dir() {
    local dir
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    if [[ -z "$dir" ]]; then
        cecho $RED "Error: Unable to determine script directory." >&2
        return 1
    fi
    echo "$dir"
}

# Function to get the current distro type
get_distro_type() {
    local -A osInfo=(
        ["/etc/debian_version"]="debian"
        ["/etc/alpine-release"]="alpine"
        ["/etc/centos-release"]="centos"
        ["/etc/fedora-release"]="fedora"
        ["/etc/redhat-release"]="redhat"
        ["/etc/arch-release"]="arch"
        ["/etc/gentoo-release"]="gentoo"
        ["/etc/SuSE-release"]="suse"
    )

    for file in "${!osInfo[@]}"; do
        if [[ -f "$file" ]]; then
            echo "${osInfo[$file]}"
            return 0
        fi
    done
    cecho $RED "Error: Unknown distribution type." >&2
    return 1
}

# Function to load dependencies
dependencies() {
    update_package_lists || return 1
    local dependencies=("$@")
    local dependency=""
    local installers_path="$(get_current_dir)/installers"
    
    for dependency in "${dependencies[@]}"; do
        local file="$installers_path/install_$dependency.sh"
        if file_exists "$file"; then
            cecho $BLUE "Sourcing installer script: $file"
            source "$file"
        else
            package_install "$dependency" || { cecho $RED "Error: Failed to install dependency '$dependency'." >&2; return 1; }
        fi
    done
}

# Function to trim leading and trailing spaces or specific characters
trim() {
    local str="$1"
    local chars="${2:- }"
    
    # Trim leading chars
    while [[ "$str" == ["$chars"]* ]]; do
        str="${str#?}"
    done
    
    # Trim trailing chars
    while [[ "$str" == *["$chars"] ]]; do
        str="${str%?}"
    done
    
    printf '%s' "$str"
}

# Function to translate package names based on the distro
translate_package_name() {
    local package="$1"
    local distro="$2"
    local current_dir
    current_dir=$(get_current_dir) || return 1
    local json_file="$current_dir/package_mappings.json"
    
    if [[ ! -f "$json_file" ]]; then
        cecho $RED "Error: package_mappings.json not found in $current_dir" >&2
        return 1
    fi
    
    local value
    value=$(awk -v package="$package" -v distro="$distro" '
        BEGIN { 
            found = 0;
            value = ""
            }
        $1 ~ "\"" package "\":" { found = 1; next }
        found && $1 ~ "\"" distro "\":" {
            for (i = 2; i <= NF; i++) value = value " " $i;
            print value;
            exit
        }
    ' "$json_file")
    
    # Debugging output
    if [[ -z "$value" ]]; then
        cecho $YELLOW "Warning: No translation found for '$package' in distro '$distro'." >&2
        return 1
    fi

    # Trim leading and trailing spaces, commas, and quotes
    value=$(trim "$value" ",")
    value=$(trim "$value")
    value=$(trim "$value" '"')
    echo $value
}

# Get distro-specific command from JSON mapping
get_distro_specific_command() {
    local current_dir
    current_dir=$(get_current_dir)
    local json_file="$current_dir/commands_mappings.json"

    if [[ ! -f "$json_file" ]]; then
        cecho $RED "Error: commands_mappings.json not found in $current_dir" >&2
        return 1
    fi

    local command="$1"
    local distro="$2"

    # Read the JSON file and extract the command for the given distro
    local value
    value=$(awk -v command="$command" -v distro="$distro" '
        BEGIN { value = ""; command_found = 0 }
        $1 ~ "\"" command "\":" { command_found = 1; next }
        command_found && $1 ~ "\"" distro "\":" {
            for (i = 2; i <= NF; i++) {
                value = value " " $i;
            }
            print value
            exit
        }
    ' "$json_file")

    # Debugging output
    if [[ -z "$value" ]]; then
        cecho $YELLOW "Warning: No command found for '$command' in distro '$distro'." >&2
        return 1
    fi

    # Trim leading and trailing spaces, commas, and quotes
    value=$(trim "$value" ",")
    value=$(trim "$value")
    value=$(trim "$value" '"')
    echo $value
}

# Function to install a package
package_install() {
    local package
    local distro
    distro=$(get_distro_type) || return 1
    local install_command
    install_command=$(get_distro_specific_command "install" "$distro") || return 1

    package=$(translate_package_name $1 "$distro")

    if [[ -z "$install_command" ]]; then
        cecho $RED "Error: No install command found for distro '$distro'." >&2
        return 1
    fi
    
    cecho $BLUE "Installing package: $package using: $install_command"
    eval "$install_command $package" || { cecho $RED "Error: Failed to install package '$package'." >&2; return 1; }
}

# Upgrade packages
upgrade_packages() {
    local distro
    distro=$(get_distro_type)
    local upgrade_command
    upgrade_command=$(get_distro_specific_command "upgrade" "$distro")

    if [[ -n "$upgrade_command" ]]; then
        cecho $BLUE "Upgrading packages using $upgrade_command..."
        eval "$upgrade_command"
    else
        cecho $RED "Error: Unsupported distribution or package manager not found."
        return 1;
    fi
}

# Function to update package lists based on the detected distribution
update_package_lists() {
    local distro
    distro=$(get_distro_type) || return 1
    local update_command
    update_command=$(get_distro_specific_command "update" "$distro") || return 1
    cecho $BLUE "Updating package lists using: $update_command"
    eval -- "$update_command" || { cecho $RED "Error: Failed to update package lists." >&2; return 1; }
}

readonly CORE_DIR=$(get_current_dir)
