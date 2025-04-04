# Install Coreutils & Docker Script

## Overview
This project provides a Bash script to detect the user's operating system and install `coreutils` or `docker-ce` dynamically using pre-defined JSON mappings for package managers and package names.

## Features
- Supports multiple Linux distributions and BSD variants.
- Uses `awk` to parse JSON configuration files.
- Allows specifying dependencies dynamically.
- Ensures compatibility with major package managers.

## Supported Distributions
- Debian (Ubuntu, etc.)
- Alpine Linux
- CentOS / RedHat
- Fedora
- Arch Linux
- Gentoo
- openSUSE
- macOS (Homebrew)
- FreeBSD, OpenBSD, NetBSD

## Usage
### Prerequisites
- Ensure `bash-lib` is available and loaded.
- Clone the repository and load the core library:
  ```bash
  # Load bash-lib core
  . "../bash-lib/core.sh"
  ```

### Specifying Dependencies
You can specify dependencies using:
```bash
# Specify dependencies
dependencies "pgclient"
```

### Running the Script
```bash
chmod +x install.sh
./install.sh
```

## Provided Functions
This script provides several helper functions for package management:

| Function                     | Description                                      |
|------------------------------|--------------------------------------------------|
| `update_package_lists`       | Updates the package lists for the package manager. |
| `upgrade_packages`           | Upgrades all installed packages.                 |
| `package_install`            | Installs a specified package.                     |
| `get_distro_specific_command`| Retrieves the install command for the current OS. |
| `translate_package_name`     | Translates a package name to the OS-specific version. |
| `get_distro_type`            | Detects the current distribution type.           |

## Configuration Files
### `commands_mappings.json`
Defines installation commands for each distribution:
```json
{
    "install": {
        "debian": "apt-get install -y",
        "alpine": "apk --update add",
        "centos": "yum install -y",
        "fedora": "dnf install -y",
        "arch": "pacman -S --noconfirm"
    }
}
```

### `package_mappings.json`
Defines package names for different distributions:
```json
{
    "docker-ce": {
        "debian": "docker-ce",
        "alpine": "docker-cli docker-engine docker-compose-cli",
        "centos": "docker-ce"
    },
    "ca-certificates": {
        "debian": "ca-certificates",
        "alpine": "ca-certificates"
    },
    "curl": {
        "debian": "curl",
        "alpine": "curl"
    }
}
```

## Contributing
1. Fork the repository
2. Create a new branch (`feature/your-feature`)
3. Commit changes
4. Push to the branch
5. Open a pull request

## License
This project is licensed under the MIT License.

