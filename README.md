# autosetup

**Automated server setup script for Ubuntu Linux.**

## Description

`autosetup-server` is a Bash script designed to automate the initial configuration of Ubuntu servers. It provides an interactive interface for selecting and configuring essential components such as SSH, firewall, Squid forward proxy, and Docker, with minimal user intervention.

> **Note:** Currently, only Ubuntu is supported. Compatibility with other distributions will be added in future releases.

> **Important note:** This script is currently in testing and may contain bugs. Please, use it with caution and at your own risk.

## Features

- Interactive configuration wizard
- Root user check
- SSH installation and configuration (with optional key generation)
- Firewall setup (nftables, Fail2Ban, UFW)
- Squid proxy installation and user setup
- Docker installation
- Step-by-step execution with checkpoints
- Logging of actions and errors

## Project Structure

```
autosetup-server/
│
├── main.sh                # Main script
├── modules/               # Bash modules for each component
│   ├── utils.sh
│   ├── ssh.sh
│   ├── firewall.sh
│   ├── squid.sh
│   ├── docker.sh
│   └── checkpoints.sh
└── etc/                   # Example configs for services
```

## Requirements

- Ubuntu 22+ Linux server
- Run as root

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/pavlusha5565/autosetup-server
   cd autosetup-server
   ```
2. Make the script executable:
   ```bash
   chmod +x main.sh
   ```

## Usage

Run the script as root:
```bash
sudo ./main.sh
```

Follow the interactive prompts to select components and enter configuration options. The script will perform all selected actions automatically.

## Modules

- **utils.sh** — Utility functions (logging, input)
- **ssh.sh** — SSH installation and configuration
- **firewall.sh** — nftables, Fail2Ban, UFW setup
- **squid.sh** — Squid proxy installation and configuration
- **docker.sh** — Docker installation
- **checkpoints.sh** — Execution checkpoints

## Example Configs

The `etc/` directory contains example configuration files for supported services. The script will use these as templates.

## Security

- Requires root privileges
- All actions are logged
- You can verify and check all scripts

## FAQ

**Q:** Can I run this on CentOS/AlmaLinux?
**A:** Currently, only Ubuntu is supported. Other distributions will be supported in future versions.

**Q:** How do I add a new component?
**A:** Create a module in `modules/` and add its call to `main.sh`.

## License

MIT

