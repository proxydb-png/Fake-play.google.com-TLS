#!/bin/bash
# ================================================
# Fake play.google.com - با نصب خودکار Nginx
# ================================================

echo "🔧 Installing Nginx..."
apt-get update -qq
apt-get install -y -qq nginx openssl curl iptables

echo "🔧 Setup Fake play.google.com..."

# ساخت Certificate
mkdir -p /opt/fake_google

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/fake_google/play.google.key \
    -out /opt/fake_google/play.google.crt \
    -subj "/C=US/ST=California/L=Mountain View/O=Google LLC/CN=*.google.com" \
    -addext "subjectAltName=DNS:play.google.com,DNS:*.google.com"

# Nginx config
cat > /etc/nginx/sites-available/google-fake << 'EOF'
server {
    listen 443 ssl http2;
    
    ssl_certificate /opt/fake_google/play.google.crt;
    ssl_certificate_key /opt/fake_google/play.google.key;
    
    add_header Server "gws" always;
    
    location / {
        return 200 '{"google":"play","status":"ok"}';
    }
}

server {
    listen 80;
    return 301 https://$host$request_uri;
}
EOF

# فعال کردن
mkdir -p /etc/nginx/sites-enabled
ln -sf /etc/nginx/sites-available/google-fake /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx
systemctl enable nginx

# iptables
iptables -t nat -F PREROUTING
iptables -t nat -A PREROUTING -p tcp --dport 22 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 443

echo ""
echo "✅ Fake play.google.com فعال شد!"
echo ""
echo "تست:"
echo "  curl -k https://$(curl -s ifconfig.me)"
echo "  openssl s_client -connect $(curl -s ifconfig.me):443 -servername play.google.com"
