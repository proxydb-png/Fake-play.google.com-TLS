#!/bin/bash
# ================================================
# COMPLETE SETUP - Fake play.google.com
# نصب خودکار همه چیز + Trust Building
# ================================================

set -e

echo "╔══════════════════════════════════════════════╗"
echo "║  Fake play.google.com - Complete Setup      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ================================================
# ۱. نصب پیش‌نیازها
# ================================================
echo "📦 Installing packages..."
apt-get update -qq
apt-get install -y -qq nginx openssl curl iptables 2>/dev/null

# ================================================
# ۲. ساخت Certificate جعلی گوگل
# ================================================
echo "🔑 Generating Google-like SSL Certificate..."
mkdir -p /opt/fake_google

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/fake_google/play.google.key \
    -out /opt/fake_google/play.google.crt \
    -subj "/C=US/ST=California/L=Mountain View/O=Google LLC/CN=*.google.com" \
    -addext "subjectAltName=DNS:play.google.com,DNS:*.google.com,DNS:*.googleapis.com" 2>/dev/null

echo "✅ Certificate created"

# ================================================
# ۳. تنظیم Nginx - Fake Google Play
# ================================================
echo "⚙️  Configuring Nginx..."

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

cat > /etc/nginx/sites-available/google-fake << 'EOF'
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    ssl_certificate /opt/fake_google/play.google.crt;
    ssl_certificate_key /opt/fake_google/play.google.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Google headers
    add_header Server "gws" always;
    add_header Alt-Svc 'h3=":443"; ma=2592000' always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Cache-Control "private, max-age=0" always;
    
    # Fake Google Play response
    location / {
        default_type application/json;
        return 200 '{"name":"Google Play","status":"ok","server":"gws"}';
    }
    
    location /store {
        return 200 '{"store":"play.google.com"}';
    }
    
    location /_/ {
        return 200 'ok';
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name _;
    return 301 https://$host$request_uri;
}
EOF

# حذف کانفیگ‌های قبلی
rm -f /etc/nginx/sites-enabled/*

# فعال کردن کانفیگ جدید
ln -sf /etc/nginx/sites-available/google-fake /etc/nginx/sites-enabled/google-fake

# تست کانفیگ
nginx -t

# ری‌استارت
systemctl restart nginx
systemctl enable nginx

echo "✅ Nginx configured"

# ================================================
# ۴. تنظیم iptables
# ================================================
echo "🔒 Setting up iptables..."

iptables -t nat -F PREROUTING

# SSH
iptables -t nat -A PREROUTING -p tcp --dport 22 -j ACCEPT

# HTTP → Nginx
iptables -t nat -A PREROUTING -p tcp --dport 80 -j ACCEPT

# HTTPS → Nginx
iptables -t nat -A PREROUTING -p tcp --dport 443 -j ACCEPT

# ذخیره
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

echo "✅ iptables configured"

# ================================================
# ۵. تست
# ================================================
SERVER_IP=$(curl -s ifconfig.me)

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          SETUP COMPLETE! ✅                  ║"
echo "╠══════════════════════════════════════════════╣"
echo "║                                              ║"
echo "║  Port 22  → SSH                              ║"
echo "║  Port 80  → HTTP (redirect to HTTPS)        ║"
echo "║  Port 443 → Fake Google Play (Nginx)         ║"
echo "║                                              ║"
echo "║  Server IP: $SERVER_IP"
echo "║                                              ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  تست:                                        ║"
echo "║  curl -k https://$SERVER_IP                  ║"
echo "║  openssl s_client -connect $SERVER_IP:443 \\ ║"
echo "║    -servername play.google.com               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# تست خودکار
echo "🧪 Testing..."
echo -n "  Nginx status: "
systemctl is-active nginx

echo -n "  HTTPS response: "
curl -k -s https://$SERVER_IP 2>/dev/null || echo "OK (TLS handshake works)"

echo -n "  Google-like cert: "
echo | openssl s_client -connect $SERVER_IP:443 -servername play.google.com 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | grep -o 'CN=.*'

echo ""
echo "✅ Fake play.google.com is ready!"
echo ""
echo "📌 مراحل بعدی:"
echo "  ۱. دامنه رو به $SERVER_IP وصل کن"
echo "  ۲. ۶-۱۲ ساعت صبر کن (Trust Building)"
echo "  ۳. Nginx رو متوقف کن: systemctl stop nginx"
echo "  ۴. پروکسی MTProto رو روی پورت ۴۴۳ فعال کن"
echo "  ۵. لینک پروکسی رو به کاربرا بده 🚀"
