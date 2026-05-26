"""Deploy Flutter staff web console to sunkidz.org (replaces the n8n placeholder).

Usage:
    python scripts/deploy_web_console.py

Requires the Flutter web build at mobile/build/web (build first with:
    cd mobile && flutter build web --release --dart-define=API_BASE_URL=https://api.sunkidz.org
)
"""
import io
import os
import posixpath
import stat
import sys
from pathlib import Path

import paramiko

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
LOCAL_WEB_BUILD = Path(__file__).resolve().parent.parent / "mobile" / "build" / "web"
REMOTE_WEB_ROOT = "/var/www/sunkidz-console"

NGINX_HTTP_ONLY = """server {
    listen 80;
    listen [::]:80;
    server_name sunkidz.org www.sunkidz.org;

    root /var/www/sunkidz-console;
    index index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
"""

NGINX_SITE = """server {
    listen 80;
    listen [::]:80;
    server_name sunkidz.org www.sunkidz.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sunkidz.org www.sunkidz.org;

    ssl_certificate /etc/letsencrypt/live/sunkidz.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sunkidz.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/sunkidz-console;
    index index.html;

    client_max_body_size 50M;
    gzip on;
    gzip_types text/plain text/css application/javascript application/json
               application/wasm image/svg+xml application/font-woff2;
    gzip_min_length 256;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \\.(?:js|css|wasm|woff2?|ttf|otf|png|jpg|jpeg|gif|svg|ico)$ {
        expires 7d;
        access_log off;
        try_files $uri =404;
    }

    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }

    access_log /var/log/nginx/sunkidz.access.log;
    error_log /var/log/nginx/sunkidz.error.log;
}
"""


def connect() -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for host in HOSTS:
        try:
            client.connect(host, username=USER, password=PASSWORD, timeout=25)
            print(f"Connected to {host}")
            return client
        except Exception as exc:  # noqa: BLE001
            print(f"  {host}: {exc}")
    sys.exit("Could not reach server. Use the VPN/LAN.")


def ensure_dir(sftp: paramiko.SFTPClient, path: str) -> None:
    parts = [p for p in path.split("/") if p]
    cur = ""
    for p in parts:
        cur += "/" + p
        try:
            sftp.stat(cur)
        except FileNotFoundError:
            sftp.mkdir(cur)


def upload_tree(sftp: paramiko.SFTPClient, local: Path, remote_root: str) -> int:
    ensure_dir(sftp, remote_root)
    count = 0
    for path in local.rglob("*"):
        rel = path.relative_to(local).as_posix()
        remote = posixpath.join(remote_root, rel)
        if path.is_dir():
            try:
                sftp.stat(remote)
            except FileNotFoundError:
                sftp.mkdir(remote)
            continue
        parent = posixpath.dirname(remote)
        ensure_dir(sftp, parent)
        sftp.put(str(path), remote)
        try:
            sftp.chmod(remote, 0o644)
        except OSError:
            pass
        count += 1
        if count % 25 == 0:
            print(f"  uploaded {count} files…")
    return count


def run(client: paramiko.SSHClient, cmd: str, label: str | None = None) -> str:
    if label:
        print(f"\n>>> {label}")
    print(f"$ {cmd}")
    _, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode(errors="replace").strip()
    err = stderr.read().decode(errors="replace").strip()
    if out:
        print(out)
    if err:
        print(f"[stderr] {err}")
    return out


def main() -> None:
    if not LOCAL_WEB_BUILD.exists():
        sys.exit(
            "Flutter web build not found.\n"
            "Run: cd mobile && flutter build web --release "
            "--dart-define=API_BASE_URL=https://api.sunkidz.org"
        )

    client = connect()
    sftp = client.open_sftp()

    print(f"\nClearing remote {REMOTE_WEB_ROOT}…")
    run(client, f"rm -rf {REMOTE_WEB_ROOT} && mkdir -p {REMOTE_WEB_ROOT}")

    print(f"\nUploading {LOCAL_WEB_BUILD} -> {REMOTE_WEB_ROOT}")
    n = upload_tree(sftp, LOCAL_WEB_BUILD, REMOTE_WEB_ROOT)
    print(f"Uploaded {n} files.")

    run(client, f"chown -R www-data:www-data {REMOTE_WEB_ROOT}")
    run(client, f"chmod -R a+rX {REMOTE_WEB_ROOT}")

    run(
        client,
        "rm -f /etc/nginx/sites-enabled/default "
        "/etc/nginx/sites-enabled/n8n "
        "/etc/nginx/sites-enabled/n8n.conf "
        "/etc/nginx/sites-enabled/sunkidz.org "
        "/etc/nginx/sites-available/sunkidz.org",
        label="Remove old n8n / placeholder configs",
    )

    cert_present = run(
        client,
        "test -f /etc/letsencrypt/live/sunkidz.org/fullchain.pem && echo YES || echo NO",
    ).endswith("YES")

    if not cert_present:
        print("\nNo SSL cert for sunkidz.org yet — installing HTTP-only site then issuing cert via certbot…")
        nginx_path = "/etc/nginx/sites-available/sunkidz.org.conf"
        with sftp.file(nginx_path, "w") as f:
            f.write(NGINX_HTTP_ONLY)
        run(
            client,
            "ln -sfn /etc/nginx/sites-available/sunkidz.org.conf "
            "/etc/nginx/sites-enabled/sunkidz.org.conf",
        )
        run(client, "mkdir -p /var/www/certbot")
        run(client, "nginx -t && systemctl reload nginx", label="Reload Nginx (HTTP)")
        run(
            client,
            "certbot certonly --webroot -w /var/www/certbot "
            "-d sunkidz.org -d www.sunkidz.org "
            "--non-interactive --agree-tos -m admin@sunkidz.org --keep-until-expiring",
            label="Issue Let's Encrypt certificate",
        )

    print("\nWriting full HTTPS Nginx site config…")
    nginx_path = "/etc/nginx/sites-available/sunkidz.org.conf"
    with sftp.file(nginx_path, "w") as f:
        f.write(NGINX_SITE)
    run(
        client,
        "ln -sfn /etc/nginx/sites-available/sunkidz.org.conf "
        "/etc/nginx/sites-enabled/sunkidz.org.conf",
    )

    run(client, "nginx -t", label="Validate Nginx config")
    run(client, "systemctl reload nginx", label="Reload Nginx")

    print("\nStopping any n8n service on this host (if present)…")
    run(client, "systemctl disable --now n8n 2>/dev/null; true")
    run(client, "pm2 stop n8n 2>/dev/null; pm2 delete n8n 2>/dev/null; true")
    run(client, "docker ps --format '{{.Names}}' | grep -i n8n | xargs -r docker stop; true")

    print("\nVerifying live site…")
    run(client, "curl -sI https://sunkidz.org | head -8")
    run(client, "curl -s https://sunkidz.org/ | head -10")

    sftp.close()
    client.close()
    print("\nDone. Open https://sunkidz.org to access the staff console.")


if __name__ == "__main__":
    main()
