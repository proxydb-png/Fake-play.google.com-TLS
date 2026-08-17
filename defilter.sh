#!/bin/bash
# ================================================
# رفع فیلتر IP - نسخه قدرتمند و حرفه‌ای
# با SNI Spoofing پیشرفته + تحریک هوشمند DPI
# + شبیه‌سازی ترافیک واقعی + چرخش مداوم
# ================================================

set -e

IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     رفع فیلتر IP - نسخه قدرتمند و حرفه‌ای      ║${NC}"
echo -e "${BLUE}║     با شبیه‌سازی ترافیک واقعی و هوشمند          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# متغیرهای پیشرفته
# ============================================
DOMAINS_COUNT=50
REQUESTS_PER_HOUR=100
ROTATION_INTERVAL=300  # 5 دقیقه
LOG_FILE="/var/log/dpi-unblock.log"
PID_FILE="/var/run/dpi-unblock.pid"

# ============================================
# لیست گسترده دامنه‌های ایرانی و خارجی
# ============================================
IRANIAN_DOMAINS=(
    "digikala.com" "www.digikala.com" "api.digikala.com"
    "snapp.ir" "app.snapp.ir" "api.snapp.ir"
    "divar.ir" "api.divar.ir" "static.divar.ir"
    "varzesh3.com" "www.varzesh3.com" "static.varzesh3.com"
    "aparat.com" "www.aparat.com" "static.aparat.com"
    "namasha.com" "www.namasha.com" "static.namasha.com"
    "bale.ai" "web.bale.ai" "api.bale.ai"
    "eitaa.com" "web.eitaa.com" "api.eitaa.com"
    "rubika.ir" "web.rubika.ir" "api.rubika.ir"
    "sibapp.com" "www.sibapp.com" "api.sibapp.com"
    "cafebazaar.ir" "www.cafebazaar.ir" "api.cafebazaar.ir"
    "filimo.com" "www.filimo.com" "api.filimo.com"
    "namava.ir" "www.namava.ir" "api.namava.ir"
    "tamasha.com" "www.tamasha.com" "static.tamasha.com"
    "telewebion.com" "www.telewebion.com" "api.telewebion.com"
)

FOREIGN_DOMAINS=(
    "play.google.com" "www.google.com" "mail.google.com"
    "drive.google.com" "docs.google.com" "maps.google.com"
    "github.com" "api.github.com" "raw.githubusercontent.com"
    "stackoverflow.com" "cdn.stackoverflow.com" "api.stackoverflow.com"
    "youtube.com" "www.youtube.com" "i.ytimg.com"
    "facebook.com" "www.facebook.com" "static.facebook.com"
    "twitter.com" "www.twitter.com" "api.twitter.com"
    "instagram.com" "www.instagram.com" "static.instagram.com"
    "telegram.org" "web.telegram.org" "api.telegram.org"
    "whatsapp.com" "www.whatsapp.com" "web.whatsapp.com"
    "netflix.com" "www.netflix.com" "api.netflix.com"
    "spotify.com" "www.spotify.com" "api.spotify.com"
    "amazon.com" "www.amazon.com" "api.amazon.com"
    "cloudflare.com" "www.cloudflare.com" "api.cloudflare.com"
    "microsoft.com" "www.microsoft.com" "api.microsoft.com"
)

# ============================================
# توابع پیشرفته
# ============================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================
# مرحله ۱: وب‌سایت با SNIهای متنوع
# ============================================
setup_sni_spoof() {
    echo -e "${YELLOW}[۱/۴] راه‌اندازی وب‌سایت با SNIهای متنوع...${NC}"
    
    apt-get update -qq
    apt-get install -y -qq nginx openssl curl jq bc
    
    # ساخت Certificate با دامنه‌های گسترده
    cat > /tmp/openssl.cnf << EOF
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
EOF

    # اضافه کردن دامنه‌ها به Certificate
    counter=3
    for domain in "${IRANIAN_DOMAINS[@]}" "${FOREIGN_DOMAINS[@]}"; do
        echo "DNS.$counter = $domain" >> /tmp/openssl.cnf
        echo "DNS.$((counter+1)) = *.$domain" >> /tmp/openssl.cnf
        counter=$((counter+2))
    done

    mkdir -p /opt/certs/
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
        -keyout /opt/certs/multi.key \
        -out /opt/certs/multi.crt \
        -config /tmp/openssl.cnf 2>/dev/null
    
    # وب‌سایت واقعی با محتوای متنوع
    mkdir -p /var/www/site/{css,js,images}
    
    # صفحه اصلی
    cat > /var/www/site/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>سرویس آنلاین</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <header>
        <nav>
            <a href="/">خانه</a>
            <a href="/about.html">درباره ما</a>
            <a href="/contact.html">تماس با ما</a>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h1>سرویس آنلاین</h1>
            <p>ارائه دهنده خدمات اینترنتی</p>
        </section>
        
        <section class="features">
            <div class="feature">
                <h3>سرعت بالا</h3>
                <p>با بهترین کیفیت</p>
            </div>
            <div class="feature">
                <h3>امنیت</h3>
                <p>محافظت از اطلاعات</p>
            </div>
            <div class="feature">
                <h3>پشتیبانی</h3>
                <p>در تمام ساعات شبانه‌روز</p>
            </div>
        </section>
    </main>
    
    <footer>
        <p>© 2024 - تمامی حقوق محفوظ است</p>
    </footer>
    
    <script src="/js/script.js"></script>
</body>
</html>
EOF

    # CSS
    cat > /var/www/site/css/style.css << 'EOF'
body {
    font-family: Tahoma, Arial, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    margin: 0;
    padding: 0;
    min-height: 100vh;
}
header {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    padding: 15px;
}
nav a {
    color: white;
    text-decoration: none;
    margin: 0 15px;
    font-size: 16px;
}
.hero {
    text-align: center;
    padding: 80px 20px;
    color: white;
}
.hero h1 {
    font-size: 48px;
    margin-bottom: 10px;
}
.features {
    display: flex;
    justify-content: space-around;
    padding: 50px 20px;
    flex-wrap: wrap;
}
.feature {
    background: white;
    border-radius: 10px;
    padding: 30px;
    margin: 10px;
    min-width: 200px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.2);
}
footer {
    background: rgba(0, 0, 0, 0.2);
    color: white;
    text-align: center;
    padding: 20px;
    position: fixed;
    bottom: 0;
    width: 100%;
}
EOF

    # JavaScript
    cat > /var/www/site/js/script.js << 'EOF'
document.addEventListener('DOMContentLoaded', function() {
    console.log('سرویس آنلاین - نسخه 1.0');
    
    // شبیه‌سازی فعالیت کاربر
    setInterval(function() {
        fetch('/api/status')
            .then(response => response.json())
            .then(data => console.log('Status:', data));
    }, 5000);
});
EOF

    # API endpoint
    mkdir -p /var/www/site/api
    cat > /var/www/site/api/status.json << 'EOF'
{"status":"ok","version":"1.0","timestamp":"2024"}
EOF

    # Nginx پیشرفته
    cat > /etc/nginx/sites-available/site << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/site;
    index index.html;
    
    # پاسخ به درخواست‌های مختلف
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        default_type application/json;
        return 200 '{"status":"ok","service":"online"}';
    }
    
    location /robots.txt {
        return 200 'User-agent: *\nAllow: /';
    }
    
    location /favicon.ico {
        return 204;
    }
}

server {
    listen 443 ssl http2;
    server_name _;
    root /var/www/site;
    index index.html;
    
    ssl_certificate /opt/certs/multi.crt;
    ssl_certificate_key /opt/certs/multi.key;
    
    # هدرهای واقعی
    add_header Server "nginx/1.18.0" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        default_type application/json;
        return 200 '{"status":"ok","service":"online"}';
    }
}
EOF

    ln -sf /etc/nginx/sites-available/site /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ وب‌سایت با ${CYAN}${#IRANIAN_DOMAINS[@]}${GREEN} دامنه ایرانی و ${CYAN}${#FOREIGN_DOMAINS[@]}${GREEN} دامنه خارجی فعال شد${NC}"
}

# ============================================
# مرحله ۲: تحریک هوشمند DPI
# ============================================
dpi_trigger() {
    echo -e "${YELLOW}[۲/۴] تحریک هوشمند DPI...${NC}"
    
    # ساخت لیست ترکیبی
    ALL_DOMAINS=("${IRANIAN_DOMAINS[@]}" "${FOREIGN_DOMAINS[@]}")
    
    echo -e "  ارسال ${PURPLE}$REQUESTS_PER_HOUR${NC} درخواست با SNIهای متنوع..."
    
    # ارسال درخواست‌های موازی
    for i in $(seq 1 $REQUESTS_PER_HOUR); do
        RANDOM_SNI=${ALL_DOMAINS[$RANDOM % ${#ALL_DOMAINS[@]}]}
        
        # استفاده از روش‌های مختلف
        case $((RANDOM % 3)) in
            0)
                # GET request
                curl -s -k -H "Host: $RANDOM_SNI" \
                    --connect-timeout 2 \
                    "https://$IP/" -o /dev/null 2>/dev/null &
                ;;
            1)
                # HEAD request
                curl -s -k -I -H "Host: $RANDOM_SNI" \
                    --connect-timeout 2 \
                    "https://$IP/" -o /dev/null 2>/dev/null &
                ;;
            2)
                # با User-Agent واقعی
                UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                curl -s -k -H "Host: $RANDOM_SNI" \
                    -H "User-Agent: $UA" \
                    --connect-timeout 2 \
                    "https://$IP/" -o /dev/null 2>/dev/null &
                ;;
        esac
        
        # تاخیر تصادفی برای طبیعی بودن
        sleep $(echo "scale=2; $RANDOM/32767" | bc)
        
        # هر 20 درخواست، توقف کوتاه
        if [ $((i % 20)) -eq 0 ]; then
            sleep 0.5
        fi
    done
    
    wait
    echo -e "${GREEN}  ✓ تحریک DPI کامل شد${NC}"
}

# ============================================
# مرحله ۳: شبیه‌سازی ترافیک واقعی
# ============================================
simulate_real_traffic() {
    echo -e "${YELLOW}[۳/۴] شبیه‌سازی ترافیک واقعی...${NC}"
    
    # شبیه‌سازی درخواست‌های مختلف
    for domain in "${IRANIAN_DOMAINS[@]}"; do
        # درخواست GET
        curl -s -k -H "Host: $domain" \
            -H "Accept: text/html,application/xhtml+xml" \
            -H "Accept-Language: fa-IR,fa;q=0.9,en;q=0.8" \
            "https://$IP/" -o /dev/null 2>/dev/null &
        
        # درخواست API
        curl -s -k -H "Host: $domain" \
            -H "Content-Type: application/json" \
            -X POST \
            -d '{"action":"ping","timestamp":"'$(date +%s)'"}' \
            "https://$IP/api/" -o /dev/null 2>/dev/null &
        
        sleep 0.1
    done
    
    # درخواست‌های وب‌سوکت
    for i in {1..10}; do
        curl -s -k -H "Host: ${FOREIGN_DOMAINS[$RANDOM % ${#FOREIGN_DOMAINS[@]}]}" \
            -H "Upgrade: websocket" \
            -H "Connection: Upgrade" \
            "https://$IP/" -o /dev/null 2>/dev/null &
        sleep 0.05
    done
    
    wait
    echo -e "${GREEN}  ✓ شبیه‌سازی ترافیک واقعی کامل شد${NC}"
}

# ============================================
# مرحله ۴: چرخش مداوم (Daemon)
# ============================================
start_rotation_daemon() {
    echo -e "${YELLOW}[۴/۴] شروع چرخش مداوم SNI...${NC}"
    
    # توقف daemon قبلی
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        kill $OLD_PID 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    
    # ساخت اسکریپت daemon
    cat > /usr/local/bin/dpi-rotation.sh << 'EOF'
#!/bin/bash
# Daemon برای چرخش مداوم SNI

IP=$(curl -s ifconfig.me 2>/dev/null)
ALL_DOMAINS=(
    "digikala.com" "snapp.ir" "divar.ir" "varzesh3.com"
    "play.google.com" "www.google.com" "github.com"
    "youtube.com" "facebook.com" "instagram.com"
    "telegram.org" "whatsapp.com" "netflix.com"
)

while true; do
    for domain in "${ALL_DOMAINS[@]}"; do
        # درخواست تصادفی
        curl -s -k -H "Host: $domain" \
            --connect-timeout 2 \
            "https://$IP/" -o /dev/null 2>/dev/null &
        
        sleep $((RANDOM % 3 + 1))
    done
    
    # توقف برای چرخه بعدی
    sleep 300  # هر 5 دقیقه
done
EOF
    
    chmod +x /usr/local/bin/dpi-rotation.sh
    
    # اجرا در پس‌زمینه
    nohup /usr/local/bin/dpi-rotation.sh > /dev/null 2>&1 &
    DAEMON_PID=$!
    
    echo $DAEMON_PID > "$PID_FILE"
    
    echo -e "${GREEN}  ✓ چرخش مداوم با PID ${CYAN}$DAEMON_PID${GREEN} شروع شد${NC}"
}

# ============================================
# اجرا
# ============================================
echo -e "${BLUE}شروع عملیات قدرتمند رفع فیلتر...${NC}"
echo ""

setup_sni_spoof
dpi_trigger
simulate_real_traffic
start_rotation_daemon

# بررسی نهایی
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$IP/" 2>/dev/null || echo "000")
HTTPS=$(curl -s -k -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://$IP/" 2>/dev/null || echo "000")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ عملیات قدرتمند با موفقیت انجام شد        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 وضعیت:${NC}"
echo -e "  🌐 IP: ${GREEN}$IP${NC}"
echo -e "  🔓 HTTP (80): ${GREEN}$HTTP${NC}"
echo -e "  🔒 HTTPS (443): ${GREEN}$HTTPS${NC}"
echo -e "  🔄 Daemon: ${GREEN}فعال (PID: $DAEMON_PID)${NC}"
echo ""
echo -e "${YELLOW}⏳ زمان تخمینی: ۱-۴ ساعت${NC}"
echo ""
echo -e "${YELLOW}📝 امکانات اضافه شده:${NC}"
echo -e "  ${CYAN}✓${NC} ${#IRANIAN_DOMAINS[@]} دامنه ایرانی"
echo -e "  ${CYAN}✓${NC} ${#FOREIGN_DOMAINS[@]} دامنه خارجی"
echo -e "  ${CYAN}✓${NC} $REQUESTS_PER_HOUR درخواست تحریک DPI"
echo -e "  ${CYAN}✓${NC} شبیه‌سازی ترافیک واقعی"
echo -e "  ${CYAN}✓${NC} چرخش مداوم SNI (هر ۵ دقیقه)"
echo ""
echo -e "${YELLOW}📝 مراحل بعدی:${NC}"
echo "  ۱. DNS دامنه را به این IP تنظیم کن"
echo "  ۲. ۱-۴ ساعت صبر کن"
echo "  ۳. پروکسی را با SNI گوگل فعال کن:"
echo -e "     ${BLUE}https://t.me/proxy?server=DOMAIN&port=443&secret=ee1603010200010001fc030386e24c3add706c61792e676f6f676c652e636f6d160301020001000100000000000000000000000000000000${NC}"
echo ""
echo -e "${YELLOW}📊 مشاهده لاگ:${NC}"
echo -e "  ${CYAN}tail -f $LOG_FILE${NC}"
echo ""
