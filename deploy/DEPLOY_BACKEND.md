# Sunkidz Backend Deployment (PM2 + Nginx + SSL)

## 1. Backend environment

```bash
cd /var/www/sunkidz/backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
python -m scripts.create_db_if_missing
python -m scripts.init_db
```

Create `/var/www/sunkidz/backend/.env` with production values:

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/sunkidz_lms
JWT_SECRET_KEY=change-this-in-production
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440
```

## 2. Start backend with PM2

Create logs directory:

```bash
sudo mkdir -p /var/log/pm2
sudo chown -R $USER:$USER /var/log/pm2
```

Start service:

```bash
cd /var/www/sunkidz
pm2 start deploy/pm2/ecosystem.config.cjs
pm2 save
pm2 startup systemd -u $USER --hp $HOME
```

Check status:

```bash
pm2 status
pm2 logs sunkidz-backend
```

## 3. Nginx reverse proxy + SSL

Run:

```bash
cd /var/www/sunkidz
./deploy/ssl/create_ssl_cert.sh
```

This will:
1. Install certbot
2. Copy nginx config to `/etc/nginx/sites-available/sunkidz.org.conf`
3. Enable site and reload nginx
4. Create SSL cert for `sunkidz.org` and `www.sunkidz.org`
5. Keep the backend proxied to `127.0.0.1:9889`

## 4. Flutter APK backend URL

Flutter now defaults to:

```text
https://sunkidz.org
```

So normal APK build already connects to your domain:

```bash
cd /var/www/sunkidz/mobile
flutter build apk --release
```

Optional override at build time:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://sunkidz.org
```
