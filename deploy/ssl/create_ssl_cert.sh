#!/usr/bin/env bash
set -euo pipefail

DOMAIN="sunkidz.org"
WWW_DOMAIN="www.sunkidz.org"
NGINX_SITE_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"
NGINX_SITE_LINK="/etc/nginx/sites-enabled/${DOMAIN}.conf"
LEGACY_DISABLED_LINK="/etc/nginx/sites-enabled/sunkidz-disabled"

echo "Installing certbot and nginx plugin"
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

echo "Enabling nginx site config"
sudo cp /var/www/sunkidz/deploy/nginx/sunkidz.org.conf "$NGINX_SITE_CONF"
sudo ln -sf "$NGINX_SITE_CONF" "$NGINX_SITE_LINK"
if [[ -L "$LEGACY_DISABLED_LINK" ]]; then
	sudo rm -f "$LEGACY_DISABLED_LINK"
fi
sudo nginx -t
sudo systemctl reload nginx

echo "Requesting SSL certificate"
sudo certbot --nginx -d "$DOMAIN" -d "$WWW_DOMAIN" --agree-tos --register-unsafely-without-email

echo "Done. Certificates are managed by certbot auto-renew."
