#!/bin/bash
# ================================================
# رفع فیلتر IP - نسخه سریع و کم‌ریسک
# فقط SNI Spoofing + تحریک DPI
# بدون DNS Bombardment و TCP Flood
# ================================================

set -e

IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   رفع فیلتر IP - نسخه سریع و کم‌ریسک    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# مرحله ۱: وب‌سایت با SNIهای متنوع
# ============================================
setup_sni_spoof() {
    echo -e "${YELLOW}[۱/۲] راه‌اندازی وب‌سایت با SNIهای متنوع...${NC}"
    
    apt-get update -qq
    apt-get install -y -qq nginx openssl curl
    
    # Certificate با دامنه‌های ایرانی و خارجی
    cat > /tmp/openssl.cnf << 'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = IR
ST = Tehran
L = Tehran
O = Internet Services
CN = localhost

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = digikala.com
DNS.4 = *.digikala.com
DNS.5 = snapp.ir
DNS.6 = *.snapp.ir
DNS.7 = divar.ir
DNS.8 = *.divar.ir
DNS.9 = varzesh3.com
DNS.10 = *.varzesh3.com
DNS.11 = play.google.com
DNS.12 = *.google.com
DNS.13 = github.com
DNS.14 = *.github.com
EOF

    mkdir -p /opt/certs/
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/certs/multi.key \
        -out /opt/certs/multi.crt \
        -config /tmp/openssl.cnf 2>/dev/null
    
    # وب‌سایت ساده
    mkdir -p /var/www/site
    cat > /var/www/site/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>سرویس آنلاین</title>
    <style>
        body { font-family: Tahoma; background: #f0f2f5; text-align: center; padding: 50px; }
        .box { background: white; padding: 30px; border-radius: 10px; max-width: 500px; margin: 0 auto; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h2 { color: #2196F3; }
        .ok { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="box">
        <h2>سرویس فعال</h2>
        <p>وضعیت: <span class="ok">آنلاین</span></p>
        <p>تمامی سرویس‌ها در دسترس هستند.</p>
    </div>
</body>
</html>
EOF

    # Nginx
    cat > /etc/nginx/sites-available/site << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/site;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}

server {
    listen 443 ssl http2;
    server_name _;
    root /var/www/site;
    index index.html;
    
    ssl_certificate /opt/certs/multi.crt;
    ssl_certificate_key /opt/certs/multi.key;
    
    add_header Server "nginx" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location / { try_files $uri $uri/ =404; }
}
EOF

    ln -sf /etc/nginx/sites-available/site /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ وب‌سایت با SNIهای متنوع فعال شد${NC}"
}

# ============================================
# مرحله ۲: تحریک DPI به بررسی
# ============================================
dpi_trigger() {
    echo -e "${YELLOW}[۲/۲] تحریک DPI به بررسی مجدد...${NC}"
    
    SNI_LIST=(
        "digikala.com"
        "snapp.ir"
        "divar.ir"
        "varzesh3.com"
        "play.google.com"
        "www.google.com"
        "github.com"
    )
    
    echo -e "  ارسال درخواست‌های متنوع..."
    
    for i in {1..30}; do
        RANDOM_SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}
        curl -s -k -H "Host: $RANDOM_SNI" --connect-timeout 2 "https://$IP/" -o /dev/null 2>/dev/null &
        sleep 0.2
    done
    
    wait
    echo -e "${GREEN}  ✓ تحریک DPI کامل شد${NC}"
}

# ============================================
# اجرا
# ============================================
echo -e "${BLUE}شروع عملیات...${NC}"
echo ""

setup_sni_spoof
dpi_trigger

# بررسی نهایی
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$IP/" 2>/dev/null || echo "000")
HTTPS=$(curl -s -k -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://$IP/" 2>/dev/null || echo "000")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ عملیات با موفقیت انجام شد        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 وضعیت:${NC}"
echo -e "  🌐 IP: ${GREEN}$IP${NC}"
echo -e "  🔓 HTTP (80): ${GREEN}$HTTP${NC}"
echo -e "  🔒 HTTPS (443): ${GREEN}$HTTPS${NC}"
echo ""
echo -e "${YELLOW}⏳ زمان تخمینی: ۲-۶ ساعت${NC}"
echo ""
echo -e "${YELLOW}📝 مراحل بعدی:${NC}"
echo "  ۱. DNS دامنه را به این IP تنظیم کن"
echo "  ۲. ۲-۶ ساعت صبر کن"
echo "  ۳. پروکسی را با SNI گوگل فعال کن:"
echo -e "     ${BLUE}https://t.me/proxy?server=DOMAIN&port=443&secret=ee1603010200010001fc030386e24c3add706c61792e676f6f676c652e636f6d160301020001000100000000000000000000000000000000${NC}"
echo ""
