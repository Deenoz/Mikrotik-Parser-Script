# Mikrotik-Parser-Script

A simple bash script to resolve DNS names into IP addresses and add them to a MikroTik address list via SSH.

## Overview

This script:
- Resolves domain names to their corresponding IP addresses (A records).
- Filters out invalid or duplicate IPs.
- Adds the resulting IPs to a specified address list on a MikroTik router using SSH.

Useful for automating firewall address lists, such as for blocking or allowing specific domains.

## Requirements

The following tools must be installed on the machine running the script:

- `sshpass` — for SSH password authentication.
- `dig` (from `dnsutils` or `bind-utils`) — for DNS resolution.
- `bash` — script interpreter.

### Install dependencies (Debian/Ubuntu):

```bash
sudo apt update && sudo apt install sshpass dnsutils -y
