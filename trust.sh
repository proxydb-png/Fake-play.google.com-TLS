#!/bin/bash
# ================================================
# Fake play.google.com - Trust Building
# قبل از پروکسی، TLS واقعی برگردونه
# ================================================

DOMAIN="play.google.com"
SERVER_IP=$(curl -s ifconfig.me)

echo "🔧 Setup Fake $DOMAIN..."

# ۱. گرفتن Certificate واقعی گوگل (برای الگو)
openssl s_client -connect play.google.com:443 -servername play.google.com 2>/dev/null </dev/null | \
    openssl x509 -outform PEM > /opt/google-cert.pem 2>/dev/null

# ۲. ساخت Certificate جعلی شبیه گوگل
mkdir -p /opt/fake_google

# استخراج اطلاعات certificate واقعی
GOOGLE_CN=$(openssl x509 -in /opt/google-cert.pem -noout -subject 2>/dev/null | grep -oP 'CN\s*=\s*\K[^,]+' | head -1)

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/fake_google/play.google.key \
    -out /opt/fake_google/play.google.crt \
    -subj "/C=US/ST=California/L=Mountain View/O=Google LLC/CN=*.google.com" \
    -addext "subjectAltName=DNS:play.google.com,DNS:*.google.com,DNS:*.googleapis.com"

# ۳. Nginx با TLS واقعی
cat > /etc/nginx/sites-available/google-fake << 'EOF'
server {
    listen 443 ssl http2;
    server_name play.google.com *.google.com;
    
    ssl_certificate /opt/fake_google/play.google.crt;
    ssl_certificate_key /opt/fake_google/play.google.key;
    
    # Google headers
    add_header Server "gws" always;
    add_header Alt-Svc 'h3=":443"' always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # Fake Google response
    location / {
        return 200 '{"google":"play","status":"ok"}';
    }
    
    location /store/ {
        return 200 '{"store":"google-play"}';
    }
    
    location /_/ {
        return 200 'OK';
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
EOF

ln -sf /etc/nginx/sites-available/google-fake /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/fake-cdn
systemctl restart nginx

# ۴. iptables - فقط ۴۴۳ رو به Nginx
iptables -t nat -F PREROUTING
iptables -t nat -A PREROUTING -p tcp --dport 22 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 80 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 443
iptables-save > /etc/iptables/rules.v4

echo ""
echo "✅ Fake play.google.com فعال شد!"
echo ""
echo "تست کن:"
echo "  curl -k https://$SERVER_IP"
echo "  openssl s_client -connect $SERVER_IP:443 -servername play.google.com"
