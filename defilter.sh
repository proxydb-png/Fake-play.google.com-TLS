#!/bin/bash
# ================================================
# رفع فیلتر سریع - نسخه حملات DPI
# ================================================

set -e

IP=$(curl -s ifconfig.me)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║     رفع فیلتر IP - حمله به DPI          ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# مرحله ۱: انفجار DNS (DNS Bombardment)
# ============================================
dns_bombard() {
    echo -e "${YELLOW}[۱/۴] انفجار DNS - بمباران resolverها${NC}"
    
    # لیست دامنه‌های ایرانی پرترافیک
    DOMAINS=(
        "digikala.com"
        "snapp.ir"
        "tapsi.ir"
        "divar.ir"
        "torob.com"
        "namava.ir"
        "filimo.com"
        "aparat.com"
        "bama.ir"
        "sheypoor.com"
        "esam.ir"
        "varzesh3.com"
        "tabnak.ir"
        "khabaronline.ir"
        "yjc.ir"
        "farsnews.ir"
        "isna.ir"
        "irna.ir"
        "mehrnews.com"
        "tasnimnews.com"
    )
    
    # نصب ابزارها
    apt-get install -y -qq dnsutils parallel 2>/dev/null || true
    
    # بمباران DNS
    for i in {1..50}; do
        RANDOM_DOMAIN=${DOMAINS[$RANDOM % ${#DOMAINS[@]}]}
        dig +short A $RANDOM_DOMAIN @8.8.8.8 > /dev/null 2>&1 &
        dig +short AAAA $RANDOM_DOMAIN @1.1.1.1 > /dev/null 2>&1 &
        dig +short MX $RANDOM_DOMAIN @9.9.9.9 > /dev/null 2>&1 &
        dig +short TXT $RANDOM_DOMAIN @208.67.222.222 > /dev/null 2>&1 &
    done
    
    wait
    echo -e "${GREEN}  ✓ بمباران DNS کامل شد${NC}"
}

# ============================================
# مرحله ۲: مهندسی اجتماعی DPI با SNI Spoofing
# ============================================
sni_spoof() {
    echo -e "${YELLOW}[۲/۴] مهندسی اجتماعی DPI - جعل SNI${NC}"
    
    # نصب Nginx سریع
    apt-get install -y -qq nginx openssl 2>/dev/null || true
    
    # ساخت Certificate با ۲۰ دامنه ایرانی
    cat > /tmp/openssl.cnf << 'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = IR
ST = Tehran
L = Tehran
O = Local Service
CN = *.ir

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = digikala.com
DNS.2 = *.digikala.com
DNS.3 = snapp.ir
DNS.4 = *.snapp.ir
DNS.5 = divar.ir
DNS.6 = *.divar.ir
DNS.7 = namava.ir
DNS.8 = *.namava.ir
DNS.9 = varzesh3.com
DNS.10 = *.varzesh3.com
DNS.11 = tabnak.ir
DNS.12 = *.tabnak.ir
DNS.13 = farsnews.ir
DNS.14 = *.farsnews.ir
DNS.15 = isna.ir
DNS.16 = *.isna.ir
DNS.17 = yjc.ir
DNS.18 = *.yjc.ir
DNS.19 = aparat.com
DNS.20 = *.aparat.com
EOF

    mkdir -p /opt/certs/
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/certs/multi-iran.key \
        -out /opt/certs/multi-iran.crt \
        -config /tmp/openssl.cnf 2>/dev/null
    
    # کانفیگ Nginx با پاسخ‌های واقعی
    cat > /etc/nginx/sites-available/iran-spoof << 'NGINXEOF'
# پاسخ‌های واقعی از سایت‌های ایرانی
map $ssl_server_name $response_body {
    default '{"status":"ok","server":"nginx"}';
    
    "digikala.com"     '<html><head><title>دیجی‌کالا</title></head><body><h1>Digikala</h1></body></html>';
    "www.digikala.com" '<html><head><title>دیجی‌کالا</title></head><body><h1>Digikala</h1></body></html>';
    
    "snapp.ir"         '{"status":"available","service":"snapp"}';
    "www.snapp.ir"     '{"status":"available","service":"snapp"}';
    
    "divar.ir"         '<html><head><title>دیوار</title></head><body>Divar</body></html>';
    "www.divar.ir"     '<html><head><title>دیوار</title></head><body>Divar</body></html>';
    
    "varzesh3.com"     '<html><head><title>ورزش سه</title></head><body>Varzesh3</body></html>';
    "www.varzesh3.com" '<html><head><title>ورزش سه</title></head><body>Varzesh3</body></html>';
}

map $ssl_server_name $content_type {
    default "application/json";
    "digikala.com"     "text/html; charset=utf-8";
    "www.digikala.com" "text/html; charset=utf-8";
    "divar.ir"         "text/html; charset=utf-8";
    "www.divar.ir"     "text/html; charset=utf-8";
    "varzesh3.com"     "text/html; charset=utf-8";
    "www.varzesh3.com" "text/html; charset=utf-8";
}

server {
    listen 443 ssl;
    listen 80;
    
    ssl_certificate /opt/certs/multi-iran.crt;
    ssl_certificate_key /opt/certs/multi-iran.key;
    
    # تغییر SNI
    if ($ssl_server_name != "") {
        set $sni $ssl_server_name;
    }
    if ($sni = "") {
        set $sni "digikala.com";
    }
    
    location / {
        add_header Content-Type $content_type;
        return 200 $response_body;
    }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/iran-spoof /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || true
    echo -e "${GREEN}  ✓ SNI Spoofing فعال شد${NC}"
}

# ============================================
# مرحله ۳: سونامی TCP (TCP SYN Flood)
# ============================================
tcp_flood() {
    echo -e "${YELLOW}[۳/۴] ایجاد ترافیک سنگین - فریب DPI${NC}"
    
    # ۱۰۰۰ اتصال TCP سریع
    for i in {1..1000}; do
        (
            timeout 1 bash -c "echo >/dev/tcp/8.8.8.8/443" 2>/dev/null
            timeout 1 bash -c "echo >/dev/tcp/1.1.1.1/443" 2>/dev/null
            timeout 1 bash -c "echo >/dev/tcp/4.2.2.4/53" 2>/dev/null
        ) &
    done
    wait
    echo -e "${GREEN}  ✓ سونامی TCP کامل شد${NC}"
}

# ============================================
# مرحله ۴: تحریک DPI به بررسی مجدد
# ============================================
dpi_trigger() {
    echo -e "${YELLOW}[۴/۴] تحریک DPI به ارزیابی مجدد IP${NC}"
    
    # ۵۰ درخواست HTTPS با SNIهای مختلف
    SNI_LIST=(
        "digikala.com"
        "snapp.ir"
        "divar.ir"
        "varzesh3.com"
        "play.google.com"
        "www.google.com"
        "github.com"
        "stackoverflow.com"
    )
    
    for i in {1..50}; do
        RANDOM_SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}
        curl -s -k -H "Host: $RANDOM_SNI" \
            --connect-timeout 2 \
            "https://$IP/" -o /dev/null 2>/dev/null &
        
        # ترکیب HTTP و HTTPS
        curl -s -H "Host: $RANDOM_SNI" \
            --connect-timeout 2 \
            "http://$IP/" -o /dev/null 2>/dev/null &
    done
    
    wait
    
    # پینگ از سمت سرور
    for target in 8.8.8.8 1.1.1.1 4.2.2.4; do
        ping -c 10 -i 0.2 $target > /dev/null 2>&1 &
    done
    wait
    
    echo -e "${GREEN}  ✓ تحریک DPI کامل شد${NC}"
}

# ============================================
# اجرای موازی مراحل
# ============================================
echo -e "${YELLOW}شروع عملیات...${NC}"
echo ""

# اجرای همزمان
dns_bombard &
PID1=$!

sni_spoof &
PID2=$!

sleep 2
tcp_flood &
PID3=$!

wait $PID1 $PID2 $PID3

dpi_trigger

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ عملیات رفع فیلتر کامل شد         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 IP: ${GREEN}$IP${NC}"
echo ""
echo -e "${YELLOW}⏳ ۳۰ دقیقه صبر کنید...${NC}"
echo -e "${YELLOW}🔗 سپس پروکسی را تست کنید:${NC}"
echo -e "   https://t.me/proxy?server=$IP&port=443&secret=ee..."
echo ""
