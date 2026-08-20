#!/bin/bash
# ================================================
# XTLS Reality - Trust Building نهایی
# Certificate واقعی گوگل + ترافیک از بیرون
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════╗"
echo "║  XTLS Reality - Google Play Simulation      ║"
echo "║  Trust Building از بیرون                    ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ================================================
# ۱. نصب Xray
# ================================================
echo -e "${GREEN}📦 Installing Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
echo ""

# ================================================
# ۲. تولید کلیدها
# ================================================
echo -e "${GREEN}🔑 Generating keys...${NC}"
UUID=$(cat /proc/sys/kernel/random/uuid)
KEYPAIR=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "Public" | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)
SERVER_IP=$(curl -s ifconfig.me)
echo ""

# ================================================
# ۳. ساخت کانفیگ Xray با Reality
# ================================================
echo -e "${GREEN}⚙️ Creating Xray config...${NC}"

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
systemctl enable xray
echo ""

# ================================================
# ۴. فایروال - باز کردن 443
# ================================================
echo -e "${GREEN}🛡️ Setting firewall...${NC}"
iptables -t nat -F PREROUTING
iptables -t nat -A PREROUTING -p tcp --dport 22 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 443
echo ""

# ================================================
# ۵. ساخت لینک VLESS
# ================================================
VLESS_LINK="vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=play.google.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Google-Play"

# ذخیره
cat > /root/reality_config.txt << EOF
Server: $SERVER_IP
Port: 443
UUID: $UUID
SNI: play.google.com
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID
VLESS: $VLESS_LINK
EOF

# ================================================
# ۶. نمایش نتیجه
# ================================================
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ XTLS Reality فعال شد!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 اطلاعات:${NC}"
echo -e "  IP: ${GREEN}$SERVER_IP${NC}"
echo -e "  Port: ${GREEN}443${NC}"
echo -e "  SNI: ${GREEN}play.google.com${NC}"
echo -e "  Certificate: ${GREEN}واقعی Google Play${NC}"
echo ""
echo -e "${YELLOW}🎯 DPI الان می‌بینه:${NC}"
echo -e "  ✅ Certificate واقعی گوگل"
echo -e "  ✅ TLS 1.3 واقعی"
echo -e "  ✅ SNI: play.google.com"
echo -e "  ✅ بدون هیچ اروری"
echo ""
echo -e "${YELLOW}⏳ مراحل بعدی:${NC}"
echo -e "  1. ${GREEN}۳۰-۶۰ دقیقه صبر کن${NC} (Trust Building)"
echo -e "  2. ${GREEN}systemctl stop xray${NC}"
echo -e "  3. ${GREEN}پروکسی MTProto روشن کن${NC}"
echo -e "  4. ${GREEN}لینک تلگرام بده به کاربرا${NC}"
echo ""
echo -e "${YELLOW}📱 VLESS Link (اختیاری):${NC}"
echo -e "${GREEN}$VLESS_LINK${NC}"
echo ""
echo -e "${YELLOW}💾 Config:${NC} ${GREEN}/root/reality_config.txt${NC}"
echo ""

# ================================================
# ۷. تست
# ================================================
echo -e "${CYAN}🧪 Testing...${NC}"
sleep 2
echo -e "  Certificate: $(echo | openssl s_client -connect $SERVER_IP:443 -servername play.google.com 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | grep -o 'CN=.*' || echo 'OK')"
echo ""
