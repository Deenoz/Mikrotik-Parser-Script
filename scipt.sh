#!/bin/bash

# Settings
DOMAIN_LIST_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst"
ADDRESS_LIST_NAME="listname"
MIKROTIK_HOST="rb_ip"
MIKROTIK_USER="user"
MIKROTIK_SSH_PORT="22"
MIKROTIK_PASS="psswd"

# Temporary files
TMP_DOMAINS="/tmp/domains.lst"
TMP_SCRIPT="/tmp/mikrotik-update.rsc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Updating address-list for MikroTik ===${NC}"

# Download domain list
echo -e "${YELLOW}Downloading domain list...${NC}"
if ! curl -s -o "$TMP_DOMAINS" "$DOMAIN_LIST_URL"; then
    echo -e "${RED}Error: Failed to download domain list.${NC}"
    exit 1
fi

# Remove comments and empty lines
DOMAINS=()
while IFS= read -r line; do
    domain=$(echo "$line" | sed 's/#.*//' | xargs)
    if [[ -n "$domain" && "$domain" != *":"* ]]; then
        DOMAINS+=("$domain")
    fi
done < "$TMP_DOMAINS"

echo -e "${GREEN}Domains found: ${#DOMAINS[@]}${NC}"

# Resolve IP addresses
IPS=()
for domain in "${DOMAINS[@]}"; do
    # Use Google DNS (8.8.8.8) for resolution
    ip=$(dig +short "$domain" @8.8.8.8 A | head -n1)
    if [[ -n "$ip" ]]; then
        echo "Resolving: $domain -> $ip"
        IPS+=("$ip")
    else
        echo -e "${RED}Failed to resolve: $domain${NC}"
    fi
    # Delay to avoid overwhelming DNS
    sleep 0.1
done

# Get unique IPs
readarray -t UNIQUE_IPS < <(printf '%s\n' "${IPS[@]}" | sort -u)

echo -e "${GREEN}Unique IPs found: ${#UNIQUE_IPS[@]}${NC}"

# Generate MikroTik script
cat > "$TMP_SCRIPT" << EOF
# Automatically generated: $(date)
# Updating address-list "$ADDRESS_LIST_NAME"

# Remove old entries
/ip firewall address-list remove [find list="$ADDRESS_LIST_NAME"]

# Add new IPs
EOF

for ip in "${UNIQUE_IPS[@]}"; do
    echo "/ip firewall address-list add list=\"$ADDRESS_LIST_NAME\" address=$ip comment=\"ip-$ip\"" >> "$TMP_SCRIPT"
done

echo -e "${YELLOW}MikroTik script saved: $TMP_SCRIPT${NC}"

# Send commands to MikroTik via SSH
echo -e "${YELLOW}Send commands to MikroTik ($MIKROTIK_HOST) via SSH? (y/n)${NC}"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Sending commands to MikroTik...${NC}"
    sshpass -p "$MIKROTIK_PASS" ssh -p "$MIKROTIK_SSH_PORT" -o StrictHostKeyChecking=no "$MIKROTIK_USER@$MIKROTIK_HOST" -T < "$TMP_SCRIPT"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Address-list '$ADDRESS_LIST_NAME' successfully updated on MikroTik.${NC}"
    else
        echo -e "${RED}Error connecting to MikroTik.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}You can manually run the commands from file: $TMP_SCRIPT${NC}"
fi

# Cleanup
rm -f "$TMP_DOMAINS"
rm -f "$TMP_SCRIPT"

echo -e "${GREEN}Done.${NC}"
