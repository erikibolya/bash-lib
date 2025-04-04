#!/bin/bash

# Check if the date command exists
if ! command -v date &> /dev/null; then
    echo "date command not found. Attempting to install..."
    
    # Debian/Ubuntu
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install coreutils
    
    # Red Hat/CentOS/Fedora
    elif command -v yum &> /dev/null; then
        sudo yum install coreutils
    
    # Arch Linux
    elif command -v pacman &> /dev/null; then
        sudo pacman -Syu coreutils
    
    # Alpine Linux
    elif command -v apk &> /dev/null; then
        sudo apk update
        sudo apk add coreutils
    
    # OpenSUSE
    elif command -v zypper &> /dev/null; then
        sudo zypper install coreutils
    
    # Gentoo
    elif command -v emerge &> /dev/null; then
        sudo emerge sys-apps/coreutils
    
    else
        echo "Unable to determine package manager. Manual installation of coreutils required."
        exit 1
    fi

    # Check again if date command is available after installation
    if ! command -v date &> /dev/null; then
        echo "Installation failed. Unable to find date command."
        exit 1
    fi
fi