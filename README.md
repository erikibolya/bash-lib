# Install Coreutils & Docker Script

## Overview
This project provides a Bash scripts to detect the user's operating system and install dependencies dynamically using pre-defined JSON mappings for package managers and package names.

## Features
- Supports multiple Linux distributions and BSD variants.
- Uses `awk` to parse JSON configuration files.
- Loads `bash-lib` core for additional functionality.
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
### Installing `bash-lib`
If `bash-lib` is not present, you can install it using:
```bash
# Install bash-lib
mkdir -p bash-lib && git clone https://github.com/erikibolya/bash-lib.git bash-lib
```

### Creating Your Script
After installing, create your script file:
```bash
# Create myscript.sh
nano myscript.sh
```

### Load library and specify dependencies
You can specify dependencies using:
```bash
. "/bash-lib/core.sh"
dependencies "pgclient"
```

### Load library scripts or define your own logic
You can specify dependencies using:
```bash
#delete previous backup
rm -f dumpall.sql

#run backup script
/bash-lib/scripts/postgres_backup.sh -h 127.0.0.1 -U postgres -W password -f dumpall.sql
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
Defines commands for each distribution:
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

