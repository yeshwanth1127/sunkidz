"""Make api.sunkidz.org return CORS headers on EVERY response, not only OPTIONS.

Browsers cache CORS preflights — if the server ever returns a non-CORS response
(5xx, 405, FastAPI startup error), the browser caches "no CORS" until the cache
expires. Returning the headers unconditionally avoids that trap.
"""
import os
import sys
import paramiko

HOSTS = ["10.0.0.5", "31.97.63.193"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")

API_CONF = r"""upstream sunkidz_api {
    server 127.0.0.1:8001;
    keepalive 64;
}

# CORS headers reused in every location
map $http_origin $cors_origin {
    default "*";
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name api.sunkidz.org;

    client_max_body_size 50M;

    ssl_certificate /etc/letsencrypt/live/api.sunkidz.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.sunkidz.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Add CORS headers to EVERY response (incl. errors from upstream)
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, X-Requested-With' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Disposition, Content-Length' always;
    add_header 'Access-Control-Max-Age' 86400 always;

    location = /api/v1/auth/login {
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, X-Requested-With' always;
            add_header 'Access-Control-Max-Age' 86400 always;
            add_header 'Content-Length' 0;
            add_header 'Content-Type' 'text/plain';
            return 204;
        }

        limit_req zone=login_limit burst=10 nodelay;
        limit_req_status 429;

        proxy_pass http://sunkidz_api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, X-Requested-With' always;
            add_header 'Access-Control-Max-Age' 86400 always;
            add_header 'Content-Length' 0;
            add_header 'Content-Type' 'text/plain';
            return 204;
        }

        limit_req zone=api_limit burst=20 nodelay;
        limit_req_status 429;

        proxy_pass http://sunkidz_api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name api.sunkidz.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
"""


def main():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for h in HOSTS:
        try:
            c.connect(h, username=USER, password=PASSWORD, timeout=20)
            print(f"connected {h}")
            break
        except Exception as e:
            print(f"  {h}: {e}")
    else:
        sys.exit(1)

    sftp = c.open_sftp()
    with sftp.file("/etc/nginx/sites-available/api.sunkidz.org.conf", "w") as f:
        f.write(API_CONF)
    sftp.close()

    for cmd in [
        "ln -sfn /etc/nginx/sites-available/api.sunkidz.org.conf "
        "/etc/nginx/sites-enabled/api.sunkidz.org.conf",
        "nginx -t",
        "systemctl reload nginx && echo reloaded",
        "curl -sI https://api.sunkidz.org/health | head -8",
        "curl -sI -X OPTIONS https://api.sunkidz.org/api/v1/syllabus/calendar "
        "-H 'Origin: https://sunkidz.org' "
        "-H 'Access-Control-Request-Method: GET' | head -10",
    ]:
        print(f"\n$ {cmd}")
        _, o, e = c.exec_command(cmd)
        print(o.read().decode(errors="replace"))
        err = e.read().decode(errors="replace")
        if err.strip():
            print(f"[stderr] {err}")

    c.close()


if __name__ == "__main__":
    main()
