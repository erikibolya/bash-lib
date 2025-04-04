#!/bin/bash
set -e

dependencies "ca-certificates" "curl"

# Check if Docker is installed
if ! command_exists docker; then
    echo "Docker is not installed. Installing Docker..."

    # Update apt package index
    update_package_lists

    local distro_type=$(get_distro_type)

    if [ "$distro_type" = "debian" ]; then
        # Install necessary package to allow apt to use a repository over HTTPS
        package_install "apt-transport-https"
        package_install "software-properties-common"
    fi

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add Docker repository to apt sources
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Update apt package index
    update_package_lists

    # Install Docker CE (Community Edition)
    package_install "docker-ce"
    #sudo apt-get install -y docker-ce
    echo "Docker has been installed successfully."
else
    echo "Docker is already installed."
fi
