#!/bin/bash
# ================================================
# XTLS Reality + Trust Building کامل
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  XTLS Reality - Complete Setup           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# ۱. نصب
# ================================================
echo -e "${GREEN}[۱/۷] Installing packages...${NC}"
apt-get update -qq
apt-get install -y -qq unzip curl openssl > /dev/null 2>&1

if [ ! -f /usr/local/bin/xray ]; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
fi
echo -e "${GREEN}✅ Done${NC}"

# ================================================
# ۲. کلیدها
# ================================================
echo -e "${GREEN}[۲/۷] Generating keys...${NC}"
UUID=$(cat /proc/sys/kernel/random/uuid)
KEYPAIR=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk -F': ' '{print $2}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk -F': ' '{print $2}')
SHORT_ID=$(openssl rand -hex 8)
SERVER_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}✅ Done${NC}"

# ================================================
# ۳. کانفیگ Xray
# ================================================
echo -e "${GREEN}[۳/۷] Creating Xray config...${NC}"

cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "play.google.com:443",
          "serverNames": ["play.google.com"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

systemctl restart xray
systemctl enable xray > /dev/null 2>&1
echo -e "${GREEN}✅ Done${NC}"

# ================================================
# ۴. Trust Building از بیرون (سرور ایران)
# ================================================
echo -e "${GREEN}[۴/۷] Setting up Trust Building...${NC}"

echo -e "${YELLOW}برای Trust Building از بیرون، این کارها رو بکن:${NC}"
echo ""
echo -e "${CYAN}روی سرور ایران (یا هر سرور دیگه) اینو اجرا کن:${NC}"
echo ""
echo -e "${GREEN}cat > /opt/trust.sh << 'EOF'${NC}"
echo -e "#!/bin/bash"
echo -e "TARGET=\"$SERVER_IP\""
echo -e "while true; do"
echo -e "    curl -s -k \"https://\$TARGET\" \\\\"
echo -e "        --resolve \"play.google.com:443:\$TARGET\" \\\\"
echo -e "        -H \"Host: play.google.com\" \\\\"
echo -e "        -o /dev/null 2>/dev/null"
echo -e "    sleep 10"
echo -e "done"
echo -e "EOF"
echo -e "chmod +x /opt/trust.sh"
echo -e "nohup /opt/trust.sh &"
echo -e "${NC}"
echo ""
echo -e "${GREEN}✅ Trust Building آماده شد${NC}"

# ================================================
# ۵. Trust Building محلی (اختیاری)
# ================================================
echo -e "${GREEN}[۵/۷] Starting local trust...${NC}"

cat > /usr/local/bin/trust-local.sh << EOF
#!/bin/bash
while true; do
    curl -s -k "https://$SERVER_IP" \
        --resolve "play.google.com:443:$SERVER_IP" \
        -H "Host: play.google.com" \
        -o /dev/null 2>/dev/null &
    sleep \$((RANDOM % 30 + 15))
done
EOF

chmod +x /usr/local/bin/trust-local.sh
nohup /usr/local/bin/trust-local.sh > /dev/null 2>&1 &
echo -e "${GREEN}✅ Done${NC}"

# ================================================
# ۶. ذخیره
# ================================================
echo -e "${GREEN}[۶/۷] Saving config...${NC}"

cat > /root/reality_config.txt << EOF
Server: $SERVER_IP
Port: 443
UUID: $UUID
SNI: play.google.com
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID
VLESS: vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=play.google.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Google-Play
EOF

echo -e "${GREEN}✅ Done${NC}"

# ================================================
# ۷. تست
# ================================================
echo -e "${GREEN}[۷/۷] Testing...${NC}"
sleep 2
CERT=$(echo | openssl s_client -connect $SERVER_IP:443 -servername play.google.com 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | grep -o 'CN=.*')

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Complete!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  IP: ${GREEN}$SERVER_IP${NC}"
echo -e "  Port: ${GREEN}443${NC}"
echo -e "  SNI: ${GREEN}play.google.com${NC}"
echo -e "  Certificate: ${GREEN}$CERT${NC}"
echo ""
echo -e "${YELLOW}📋 بعد از ۳۰-۶۰ دقیقه:${NC}"
echo -e "  ${CYAN}systemctl stop xray${NC}"
echo -e "  ${CYAN}# پروکسی MTProto روشن کن${NC}"
echo ""
echo -e "${YELLOW}💾 Config:${NC} /root/reality_config.txt"
echo ""
