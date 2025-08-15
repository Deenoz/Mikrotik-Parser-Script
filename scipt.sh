#!/bin/bash

# Настройки
DOMAIN_LIST_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst"
ADDRESS_LIST_NAME="listname"
MIKROTIK_HOST="rb_ip"
MIKROTIK_USER="user"
MIKROTIK_SSH_PORT="22"
MIKROTIK_PASS="psswd"


# Временные файлы
TMP_DOMAINS="/tmp/domains.lst"
TMP_SCRIPT="/tmp/mikrotik-update.rsc"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Обновление address-list для MikroTik ===${NC}"

# Загрузка списка доменов
echo -e "${YELLOW}Скачиваем список доменов...${NC}"
if ! curl -s -o "$TMP_DOMAINS" "$DOMAIN_LIST_URL"; then
    echo -e "${RED}Ошибка: Не удалось скачать список доменов.${NC}"
    exit 1
fi

# убираем комментарии и пустые строки
DOMAINS=()
while IFS= read -r line; do
    domain=$(echo "$line" | sed 's/#.*//' | xargs)
    if [[ -n "$domain" && "$domain" != *":"* ]]; then
        DOMAINS+=("$domain")
    fi
done < "$TMP_DOMAINS"

echo -e "${GREEN}Найдено доменов: ${#DOMAINS[@]}${NC}"

# Резолвим IP-адреса
IPS=()
for domain in "${DOMAINS[@]}"; do
    # Используем Google DNS (8.8.8.8) для резолва
    ip=$(dig +short "$domain" @8.8.8.8 A | head -n1)
    if [[ -n "$ip" ]]; then
        echo "Резолв: $domain -> $ip"
        IPS+=("$ip")
    else
        echo -e "${RED}Не удалось резолвить: $domain${NC}"
    fi
    # Задержка, чтобы не перегружать DNS
    sleep 0.1
done

# Уникальные IP
readarray -t UNIQUE_IPS < <(printf '%s\n' "${IPS[@]}" | sort -u)

echo -e "${GREEN}Уникальных IP найдено: ${#UNIQUE_IPS[@]}${NC}"

# Генерируем скрипт для MikroTik
cat > "$TMP_SCRIPT" << EOF
# Автоматически сгенерировано: $(date)
# Обновление address-list "$ADDRESS_LIST_NAME"

# Удаляем старые записи
/ip firewall address-list remove [find list="$ADDRESS_LIST_NAME"]

# Добавляем новые IP
EOF

for ip in "${UNIQUE_IPS[@]}"; do
    echo "/ip firewall address-list add list=\"$ADDRESS_LIST_NAME\" address=$ip comment=\"ip-$ip\"" >> "$TMP_SCRIPT"
done

echo -e "${YELLOW}Скрипт для MikroTik сохранён: $TMP_SCRIPT${NC}"

# Отправить на MikroTik через SSH
echo -e "${YELLOW}Отправить команды на MikroTik ($MIKROTIK_HOST) через SSH? (y/n)${NC}"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Отправляем команды на MikroTik...${NC}"
    sshpass -p "$MIKROTIK_PASS" ssh -p "$MIKROTIK_SSH_PORT" -o StrictHostKeyChecking=no "$MIKROTIK_USER@$MIKROTIK_HOST" -T < "$TMP_SCRIPT"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN} Address-list '$ADDRESS_LIST_NAME' успешно обновлён на MikroTik.${NC}"
    else
        echo -e "${RED} Ошибка при подключении к MikroTik.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Вы можете вручную выполнить команды из файла: $TMP_SCRIPT${NC}"
fi

# Очистка
rm -f "$TMP_DOMAINS"
rm -f "$TMP_SCRIPT"  

echo -e "${GREEN}Готово.${NC}"