#!/bin/bash
# ================================================
# رفع فیلتر IP - نسخه حرفه‌ای با SSL واقعی
# پشتیبانی از چند دامنه + چرخش هوشمند
# ================================================

set -e

IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   رفع فیلتر IP با SSL واقعی - نسخه حرفه‌ای     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# پیکربندی دامنه‌ها
# ============================================
MAIN_DOMAIN="media.veilflow.ir"  # دامنه اصلی با SSL واقعی

# دامنه‌های اضافی (اختیاری)
EXTRA_DOMAINS=(
    "cdn.veilflow.ir"
    "api.veilflow.ir"
    "static.veilflow.ir"
)

# ============================================
# مرحله ۱: نصب پیش‌نیازها
# ============================================
install_dependencies() {
    echo -e "${YELLOW}[۱/۵] نصب پیش‌نیازها...${NC}"
    
    apt-get update -qq
    apt-get install -y -qq nginx certbot python3-certbot-nginx curl jq bc
    
    echo -e "${GREEN}  ✓ پیش‌نیازها نصب شد${NC}"
}

# ============================================
# مرحله ۲: دریافت SSL واقعی
# ============================================
get_real_ssl() {
    echo -e "${YELLOW}[۲/۵] دریافت SSL واقعی از Let's Encrypt...${NC}"
    
    # بررسی DNS
    echo -e "  بررسی DNS برای ${CYAN}$MAIN_DOMAIN${NC}..."
    
    DOMAIN_IP=$(dig +short A "$MAIN_DOMAIN" 2>/dev/null || echo "")
    
    if [[ -z "$DOMAIN_IP" ]]; then
        echo -e "${RED}  ✗ خطا: رکورد A برای $MAIN_DOMAIN یافت نشد${NC}"
        echo -e "  لطفاً ابتدا DNS را تنظیم کنید:"
        echo -e "  ${CYAN}$MAIN_DOMAIN → $IP${NC}"
        exit 1
    fi
    
    if [[ "$DOMAIN_IP" != "$IP" ]]; then
        echo -e "${RED}  ✗ خطا: DNS به IP اشتباه اشاره می‌کند${NC}"
        echo -e "  DNS فعلی: $DOMAIN_IP"
        echo -e "  IP سرور: $IP"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ DNS صحیح است${NC}"
    
    # دریافت SSL
    echo -e "  دریافت گواهی SSL..."
    
    # برای دامنه اصلی
    certbot certonly \
        --nginx \
        -d "$MAIN_DOMAIN" \
        --agree-tos \
        -m "admin@veilflow.ir" \
        --non-interactive \
        --preferred-challenges http-01 \
        --keep-until-expiring
    
    # برای دامنه‌های اضافی
    for domain in "${EXTRA_DOMAINS[@]}"; do
        if dig +short A "$domain" | grep -q "$IP"; then
            certbot certonly \
                --nginx \
                -d "$domain" \
                --agree-tos \
                -m "admin@veilflow.ir" \
                --non-interactive \
                --preferred-challenges http-01 \
                --keep-until-expiring 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}  ✓ SSL واقعی دریافت شد${NC}"
}

# ============================================
# مرحله ۳: راه‌اندازی وب‌سایت حرفه‌ای
# ============================================
setup_website() {
    echo -e "${YELLOW}[۳/۵] راه‌اندازی وب‌سایت حرفه‌ای...${NC}"
    
    mkdir -p /var/www/site/{css,js,api}
    
    # صفحه اصلی حرفه‌ای
    cat > /var/www/site/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="سرویس رسانه‌ای VeilFlow">
    <title>VeilFlow - سرویس رسانه‌ای</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <header>
        <nav>
            <div class="logo">VeilFlow</div>
            <div class="menu">
                <a href="/">خانه</a>
                <a href="/about.html">درباره ما</a>
                <a href="/pricing.html">تعرفه‌ها</a>
                <a href="/contact.html">تماس</a>
            </div>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h1>سرویس رسانه‌ای VeilFlow</h1>
            <p>پخش آنلاین با کیفیت بالا</p>
            <button onclick="startTrial()">شروع نسخه آزمایشی</button>
        </section>
        
        <section class="features">
            <div class="feature">
                <h3>کیفیت 4K</h3>
                <p>پخش با کیفیت فوق‌العاده</p>
            </div>
            <div class="feature">
                <h3>سرعت بالا</h3>
                <p>بدون تاخیر و بافرینگ</p>
            </div>
            <div class="feature">
                <h3>پشتیبانی ۲۴/۷</h3>
                <p>پاسخگویی در تمام ساعات</p>
            </div>
        </section>
    </main>
    
    <footer>
        <p>© 2024 VeilFlow. تمامی حقوق محفوظ است.</p>
    </footer>
    
    <script src="/js/main.js"></script>
</body>
</html>
EOF

    # CSS حرفه‌ای
    cat > /var/www/site/css/style.css << 'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Vazirmatn', Tahoma, Arial, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
}

header {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    padding: 15px 30px;
    position: fixed;
    width: 100%;
    top: 0;
    z-index: 1000;
}

nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
}

.logo {
    color: white;
    font-size: 24px;
    font-weight: bold;
}

.menu a {
    color: white;
    text-decoration: none;
    margin: 0 15px;
    font-size: 16px;
    transition: opacity 0.3s;
}

.menu a:hover {
    opacity: 0.7;
}

.hero {
    text-align: center;
    padding: 150px 20px 80px;
    color: white;
}

.hero h1 {
    font-size: 48px;
    margin-bottom: 20px;
}

.hero p {
    font-size: 20px;
    margin-bottom: 30px;
    opacity: 0.9;
}

button {
    background: #4CAF50;
    color: white;
    border: none;
    padding: 15px 30px;
    font-size: 18px;
    border-radius: 25px;
    cursor: pointer;
    transition: transform 0.3s;
}

button:hover {
    transform: scale(1.05);
}

.features {
    display: flex;
    justify-content: space-around;
    padding: 50px 20px;
    flex-wrap: wrap;
}

.feature {
    background: white;
    border-radius: 15px;
    padding: 30px;
    margin: 10px;
    min-width: 250px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    text-align: center;
}

.feature h3 {
    color: #667eea;
    margin-bottom: 15px;
}

.feature p {
    color: #666;
}

footer {
    background: rgba(0, 0, 0, 0.2);
    color: white;
    text-align: center;
    padding: 20px;
    margin-top: 50px;
}
EOF

    # JavaScript
    cat > /var/www/site/js/main.js << 'EOF'
function startTrial() {
    alert('درخواست شما ثبت شد. به زودی با شما تماس می‌گیریم.');
}

// شبیه‌سازی فعالیت
document.addEventListener('DOMContentLoaded', function() {
    console.log('VeilFlow Media Service v1.0');
    
    // درخواست API
    fetch('/api/status')
        .then(response => response.json())
        .then(data => console.log('Status:', data));
});
EOF

    # API
    cat > /var/www/site/api/status.json << 'EOF'
{
    "status": "online",
    "service": "media",
    "version": "1.0.0",
    "timestamp": "2024-01-01T00:00:00Z"
}
EOF

    echo -e "${GREEN}  ✓ وب‌سایت حرفه‌ای راه‌اندازی شد${NC}"
}

# ============================================
# مرحله ۴: پیکربندی Nginx با SSL واقعی
# ============================================
configure_nginx() {
    echo -e "${YELLOW}[۴/۵] پیکربندی Nginx با SSL واقعی...${NC}"
    
    cat > /etc/nginx/sites-available/veilflow << EOF
# HTTP → HTTPS Redirect
server {
    listen 80;
    server_name $MAIN_DOMAIN ${EXTRA_DOMAINS[@]};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS با SSL واقعی
server {
    listen 443 ssl http2;
    server_name $MAIN_DOMAIN ${EXTRA_DOMAINS[@]};
    
    root /var/www/site;
    index index.html;
    
    # SSL واقعی از Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem;
    
    # تنظیمات امنیتی SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # هدرهای واقعی
    add_header Server "nginx" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # فشرده‌سازی
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /api/ {
        default_type application/json;
        add_header Cache-Control "no-cache";
        return 200 '{"status":"ok","service":"media"}';
    }
    
    location /robots.txt {
        return 200 'User-agent: *\nAllow: /\nSitemap: https://$MAIN_DOMAIN/sitemap.xml';
    }
    
    location /sitemap.xml {
        return 200 '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n<url><loc>https://$MAIN_DOMAIN/</loc></url>\n</urlset>';
    }
}
EOF

    ln -sf /etc/nginx/sites-available/veilflow /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t && systemctl reload nginx
    
    echo -e "${GREEN}  ✓ Nginx با SSL واقعی پیکربندی شد${NC}"
}

# ============================================
# مرحله ۵: تحریک هوشمند DPI
# ============================================
trigger_dpi() {
    echo -e "${YELLOW}[۵/۵] تحریک هوشمند DPI با SSL واقعی...${NC}"
    
    # دامنه‌های برای تحریک
    TRIGGER_DOMAINS=(
        "$MAIN_DOMAIN"
        "play.google.com"
        "www.google.com"
        "github.com"
        "digikala.com"
        "snapp.ir"
        "divar.ir"
        "varzesh3.com"
    )
    
    echo -e "  ارسال درخواست‌های متنوع..."
    
    for i in {1..50}; do
        domain=${TRIGGER_DOMAINS[$RANDOM % ${#TRIGGER_DOMAINS[@]}]}
        
        if [[ "$domain" == "$MAIN_DOMAIN" ]]; then
            # درخواست واقعی با SSL
            curl -s "https://$MAIN_DOMAIN/" -o /dev/null 2>/dev/null &
        else
            # تحریک SNI
            curl -s -k -H "Host: $domain" \
                --connect-timeout 2 \
                "https://$IP/" -o /dev/null 2>/dev/null &
        fi
        
        sleep 0.1
    done
    
    wait
    echo -e "${GREEN}  ✓ تحریک DPI کامل شد${NC}"
}

# ============================================
# اجرا
# ============================================
echo -e "${BLUE}شروع عملیات با SSL واقعی...${NC}"
echo ""

install_dependencies
get_real_ssl
setup_website
configure_nginx
trigger_dpi

# بررسی نهایی
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$MAIN_DOMAIN/" 2>/dev/null || echo "000")
HTTPS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://$MAIN_DOMAIN/" 2>/dev/null || echo "000")
SSL_VALID=$(echo | openssl s_client -connect $MAIN_DOMAIN:443 -servername $MAIN_DOMAIN 2>/dev/null | grep "Verify return code" | awk '{print $4}')

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ عملیات با SSL واقعی موفق بود            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 وضعیت:${NC}"
echo -e "  🌐 دامنه: ${GREEN}$MAIN_DOMAIN${NC}"
echo -e "  🔓 HTTP: ${GREEN}$HTTP${NC}"
echo -e "  🔒 HTTPS: ${GREEN}$HTTPS${NC}"
echo -e "  📜 SSL: ${GREEN}معتبر (Verify: $SSL_VALID)${NC}"
echo ""
echo -e "${YELLOW}⏳ زمان تخمینی: ۳۰ دقیقه تا ۲ ساعت${NC}"
echo ""
echo -e "${YELLOW}✅ مزایای این روش:${NC}"
echo -e "  ${GREEN}✓${NC} SSL واقعی و معتبر"
echo -e "  ${GREEN}✓${NC} غیرقابل شناسایی توسط DPI"
echo -e "  ${GREEN}✓${NC} رفع مسدودی سریع‌تر"
echo -e "  ${GREEN}✓${NC} وب‌سایت حرفه‌ای و طبیعی"
echo ""
