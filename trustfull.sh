#!/bin/bash
# ================================================
# Advanced DPI Bypass - Interactive Domain Setup
# ================================================

# رنگ‌ها
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# پاک کردن صفحه
clear

# ================================================
# نمایش بنر
# ================================================
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║     Advanced DPI Bypass Setup Wizard         ║"
    echo "║     Google Play Simulation Server            ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ================================================
# دریافت دامنه از کاربر
# ================================================
get_domain() {
    echo -e "${YELLOW}📝 Domain Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Please enter your domain name${NC}"
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  • myserver.com"
    echo -e "  • vpn.example.net"
    echo -e "  • myserver.duckdns.org"
    echo -e "  • proxy.mooo.com"
    echo ""
    
    while true; do
        read -p "$(echo -e "${BLUE}Enter your domain: ${NC}")" DOMAIN
        
        # حذف فاصله‌های اضافی
        DOMAIN=$(echo "$DOMAIN" | tr -d '[:space:]')
        
        # بررسی خالی نبودن
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}❌ Domain cannot be empty!${NC}"
            echo ""
            continue
        fi
        
        # حذف http:// یا https:// اگر وارد شده
        DOMAIN=$(echo "$DOMAIN" | sed -E 's|^https?://||')
        
        # حذف مسیرهای اضافی
        DOMAIN=$(echo "$DOMAIN" | cut -d'/' -f1)
        
        # بررسی فرمت دامنه
        if [[ ! $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "${RED}❌ Invalid domain format!${NC}"
            echo -e "${YELLOW}   Domain should be like: example.com${NC}"
            echo ""
            continue
        fi
        
        # نمایش دامنه وارد شده
        echo ""
        echo -e "${GREEN}✅ Domain entered: ${CYAN}$DOMAIN${NC}"
        echo ""
        
        # تایید نهایی
        read -p "$(echo -e "${YELLOW}Is this correct? (y/n): ${NC}")" confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            break
        fi
        echo ""
    done
    
    # ذخیره دامنه
    echo "$DOMAIN" > /opt/dpi_domain.txt
    echo -e "${GREEN}✓ Domain saved: $DOMAIN${NC}"
    echo ""
}

# ================================================
# دریافت ایمیل (اختیاری)
# ================================================
get_email() {
    echo -e "${YELLOW}📧 Email Configuration (Optional)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Enter your email for Let's Encrypt notifications${NC}"
    echo -e "${GREEN}Or press Enter to skip${NC}"
    echo ""
    
    read -p "$(echo -e "${BLUE}Email: ${NC}")" EMAIL
    
    if [ -z "$EMAIL" ]; then
        EMAIL=""
        echo -e "${YELLOW}⚠️  No email provided, using --register-unsafely-without-email${NC}"
    else
        # بررسی فرمت ایمیل
        if [[ $EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "${GREEN}✅ Email: $EMAIL${NC}"
        else
            echo -e "${RED}❌ Invalid email format! Using no email...${NC}"
            EMAIL=""
        fi
    fi
    echo ""
}

# ================================================
# نمایش خلاصه تنظیمات
# ================================================
show_summary() {
    echo -e "${YELLOW}📋 Configuration Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Domain:${NC} ${GREEN}$DOMAIN${NC}"
    if [ ! -z "$EMAIL" ]; then
        echo -e "${WHITE}Email:${NC} ${GREEN}$EMAIL${NC}"
    else
        echo -e "${WHITE}Email:${NC} ${YELLOW}Not provided${NC}"
    fi
    echo -e "${WHITE}Server IP:${NC} ${GREEN}$(curl -s ifconfig.me)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Proceed with setup? (y/n): ${NC}")" proceed
    if [[ ! $proceed =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup cancelled!${NC}"
        exit 1
    fi
    echo ""
}

# ================================================
# نصب پیش‌نیازها
# ================================================
install_requirements() {
    echo -e "${GREEN}📦 Installing required packages...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    apt-get update -qq
    
    PACKAGES="nginx certbot python3-certbot-nginx curl wget dnsutils"
    
    for pkg in $PACKAGES; do
        echo -e "${YELLOW}  Installing $pkg...${NC}"
        apt-get install -y -qq $pkg > /dev/null 2>&1
    done
    
    echo -e "${GREEN}✅ All packages installed!${NC}"
    echo ""
}

# ================================================
# بررسی DNS
# ================================================
check_dns() {
    echo -e "${GREEN}📡 Checking DNS Configuration...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -1)
    
    echo -e "${WHITE}Domain:${NC} ${CYAN}$DOMAIN${NC}"
    echo -e "${WHITE}Domain IP:${NC} ${YELLOW}$DOMAIN_IP${NC}"
    echo -e "${WHITE}Server IP:${NC} ${YELLOW}$SERVER_IP${NC}"
    
    if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✅ DNS is correctly configured!${NC}"
    else
        echo -e "${RED}⚠️  DNS Mismatch Detected!${NC}"
        echo -e "${YELLOW}   Your domain is not pointing to this server.${NC}"
        echo -e "${YELLOW}   Please update your DNS settings:${NC}"
        echo -e "${CYAN}   Type: A Record${NC}"
        echo -e "${CYAN}   Host: @${NC}"
        echo -e "${CYAN}   Value: $SERVER_IP${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}Continue anyway? (y/n): ${NC}")" continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            echo -e "${RED}Setup aborted!${NC}"
            exit 1
        fi
    fi
    echo ""
}

# ================================================
# دریافت گواهی SSL
# ================================================
get_ssl_certificate() {
    echo -e "${GREEN}🔐 Obtaining SSL Certificate...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -z "$EMAIL" ]; then
        certbot --nginx -d $DOMAIN \
            --non-interactive \
            --agree-tos \
            --email $EMAIL \
            --redirect > /dev/null 2>&1
    else
        certbot --nginx -d $DOMAIN \
            --non-interactive \
            --agree-tos \
            --register-unsafely-without-email \
            --redirect > /dev/null 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSL Certificate obtained successfully!${NC}"
        echo -e "${CYAN}   Location: /etc/letsencrypt/live/$DOMAIN/${NC}"
        
        # تنظیم تمدید خودکار
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -
        echo -e "${GREEN}✅ Auto-renewal configured (daily at 3 AM)${NC}"
    else
        echo -e "${RED}❌ Failed to obtain SSL certificate!${NC}"
        echo -e "${YELLOW}Common issues:${NC}"
        echo -e "  1. Port 80 must be open"
        echo -e "  2. DNS must point to this server"
        echo -e "  3. Domain must be registered"
        echo ""
        read -p "$(echo -e "${YELLOW}Retry? (y/n): ${NC}")" retry
        if [[ $retry =~ ^[Yy]$ ]]; then
            get_ssl_certificate
        else
            exit 1
        fi
    fi
    echo ""
}

# ================================================
# تنظیم Nginx
# ================================================
setup_nginx() {
    echo -e "${GREEN}🔧 Configuring Nginx...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # پشتیبان‌گیری از کانفیگ قبلی
    if [ -f /etc/nginx/sites-available/google-fake ]; then
        cp /etc/nginx/sites-available/google-fake /etc/nginx/sites-available/google-fake.backup
        echo -e "${YELLOW}  Backup created: google-fake.backup${NC}"
    fi
    
    cat > /etc/nginx/sites-available/google-fake << EOF
# Google Play Simulation Server
# Domain: $DOMAIN

# Upstream برای backend (اختیاری)
upstream google_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

# HTTP Server - ریدایرکت به HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    # ریدایرکت به HTTPS
    return 301 https://\$host\$request_uri;
}

# HTTPS Server - شبیه‌سازی Google Play
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Certificate
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    
    # Google-like Headers
    add_header Server "gws" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Alt-Svc 'h3=":443"; ma=2592000' always;
    
    # Root location
    location / {
        default_type application/json;
        return 200 '{"packageName":"com.android.vending","version":"38.2.18-21","status":"ok","server":"gws"}';
    }
    
    # Google Play Store
    location /store/ {
        default_type text/html;
        return 200 '<html><head><title>Google Play</title></head><body><h1>Google Play Store</h1></body></html>';
    }
    
    # Connectivity check
    location /generate_204 {
        return 204;
    }
    
    # API endpoints
    location /api/ {
        default_type application/json;
        return 200 '{"status":"success","timestamp":"\$time_iso8601"}';
    }
}
EOF
    
    # فعال‌سازی کانفیگ
    ln -sf /etc/nginx/sites-available/google-fake /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # تست کانفیگ
    nginx -t
    
    if [ $? -eq 0 ]; then
        systemctl restart nginx
        systemctl enable nginx
        echo -e "${GREEN}✅ Nginx configured and running!${NC}"
    else
        echo -e "${RED}❌ Nginx configuration failed!${NC}"
        # بازیابی بکاپ
        if [ -f /etc/nginx/sites-available/google-fake.backup ]; then
            cp /etc/nginx/sites-available/google-fake.backup /etc/nginx/sites-available/google-fake
            nginx -t && systemctl restart nginx
            echo -e "${YELLOW}  Restored from backup${NC}"
        fi
        exit 1
    fi
    echo ""
}

# ================================================
# نمایش اطلاعات نهایی
# ================================================
show_final_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}📊 Server Information:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Domain:${NC} ${GREEN}$DOMAIN${NC}"
    echo -e "${WHITE}URL:${NC} ${GREEN}https://$DOMAIN${NC}"
    echo -e "${WHITE}SSL:${NC} ${GREEN}Valid (Let's Encrypt)${NC}"
    echo -e "${WHITE}Certificate:${NC} ${GREEN}/etc/letsencrypt/live/$DOMAIN/${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Test Commands:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}curl https://$DOMAIN${NC}"
    echo -e "  ${BLUE}openssl s_client -connect $DOMAIN:443 -servername $DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}📱 Client Usage:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  1. Use: ${GREEN}https://$DOMAIN${NC}"
    echo -e "  2. No certificate installation needed"
    echo -e "  3. Works with all modern browsers"
    echo ""
    echo -e "${YELLOW}🔄 SSL Auto-Renewal:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}certbot renew --dry-run${NC} (test renewal)"
    echo -e "  Auto-renewal: ${GREEN}Enabled (cron job)${NC}"
    echo ""
}

# ================================================
# اجرای اصلی
# ================================================
main() {
    # نمایش بنر
    show_banner
    
    # دریافت اطلاعات از کاربر
    get_domain
    get_email
    show_summary
    
    # اجرای مراحل نصب
    install_requirements
    check_dns
    get_ssl_certificate
    setup_nginx
    show_final_info
}

# اجرای برنامه
main
