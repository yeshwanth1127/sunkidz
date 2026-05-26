"""Fix sunkidz.org: HTTP console + issue SSL when DNS points to this VPS."""
import os
import sys
from pathlib import Path

import paramiko

HOSTS = ["10.0.0.5", "31.97.63.193"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
REMOTE_WEB = "/var/www/sunkidz-console"
VPS_IP = "31.97.63.193"

# HTTP only — no redirect to HTTPS until cert exists (avoids wrong cert / HSTS trap)
NGINX_HTTP = f"""server {{
    listen 80;
    listen [::]:80;
    server_name sunkidz.org www.sunkidz.org;

    root {REMOTE_WEB};
    index index.html;

    location /.well-known/acme-challenge/ {{
        root /var/www/certbot;
        try_files $uri =404;
    }}

    location / {{
        try_files $uri $uri/ /index.html;
    }}

    access_log /var/log/nginx/sunkidz.access.log;
    error_log /var/log/nginx/sunkidz.error.log;
}}
"""

NGINX_HTTPS = f"""server {{
    listen 80;
    listen [::]:80;
    server_name sunkidz.org www.sunkidz.org;

    location /.well-known/acme-challenge/ {{
        root /var/www/certbot;
        try_files $uri =404;
    }}

    location / {{
        return 301 https://$host$request_uri;
    }}
}}

server {{
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sunkidz.org www.sunkidz.org;

    ssl_certificate /etc/letsencrypt/live/sunkidz.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sunkidz.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root {REMOTE_WEB};
    index index.html;

    client_max_body_size 50M;
    gzip on;
    gzip_types text/plain text/css application/javascript application/json application/wasm;

    location / {{
        try_files $uri $uri/ /index.html;
    }}

    location = /index.html {{
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }}

    access_log /var/log/nginx/sunkidz.access.log;
    error_log /var/log/nginx/sunkidz.error.log;
}}
"""


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for h in HOSTS:
        try:
            c.connect(h, username=USER, password=PASSWORD, timeout=25)
            print(f"Connected {h}")
            return c
        except Exception as e:
            print(f"  {h}: {e}")
    sys.exit(1)


def run(c, cmd):
    print(f"\n$ {cmd}")
    _, o, e = c.exec_command(cmd)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    sys.stdout.write(out)
    if err.strip():
        sys.stdout.write(f"[stderr] {err}")
    return out.strip()


def main():
    c = connect()
    sftp = c.open_sftp()

    dns_a = run(c, "dig +short sunkidz.org A @8.8.8.8 | head -1")
    dns_www = run(c, "dig +short www.sunkidz.org A @8.8.8.8 | head -1")
    print(f"\nDNS sunkidz.org -> {dns_a!r} (need {VPS_IP})")
    print(f"DNS www -> {dns_www!r}")

    # Always apply safe HTTP config first
    with sftp.file("/etc/nginx/sites-available/sunkidz.org.conf", "w") as f:
        f.write(NGINX_HTTP)
    run(c, "ln -sfn /etc/nginx/sites-available/sunkidz.org.conf /etc/nginx/sites-enabled/sunkidz.org.conf")
    run(c, "mkdir -p /var/www/certbot")
    run(c, "nginx -t && systemctl reload nginx")

    dns_ok = VPS_IP in (dns_a or "") or VPS_IP in (dns_www or "")

    if dns_ok:
        print("\nDNS points to VPS — requesting Let's Encrypt certificate...")
        run(
            c,
            "certbot certonly --webroot -w /var/www/certbot "
            "-d sunkidz.org -d www.sunkidz.org "
            "--non-interactive --agree-tos -m admin@sunkidz.org "
            "--keep-until-expiring 2>&1 | tail -20",
        )
        has_cert = "HAS_CERT" in run(
            c,
            "test -f /etc/letsencrypt/live/sunkidz.org/fullchain.pem && echo HAS_CERT || echo NO_CERT",
        )
        if has_cert:
            print("\nEnabling HTTPS vhost...")
            with sftp.file("/etc/nginx/sites-available/sunkidz.org.conf", "w") as f:
                f.write(NGINX_HTTPS)
            run(c, "nginx -t && systemctl reload nginx")
            run(
                c,
                "echo | openssl s_client -connect 127.0.0.1:443 -servername sunkidz.org 2>/dev/null "
                "| openssl x509 -noout -subject 2>/dev/null",
            )
        else:
            print("\nCertbot failed — keep using HTTP or Cloudflare proxy (see user instructions).")
    else:
        print(
            f"\nDNS still NOT on {VPS_IP}. "
            "Update Cloudflare A records, then re-run this script."
        )

    run(c, f"curl -sI -H 'Host: sunkidz.org' http://127.0.0.1/ | head -5")
    run(c, "ls -la /var/www/sunkidz-console/index.html 2>/dev/null | head -1")

    sftp.close()
    c.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
