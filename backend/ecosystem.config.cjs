/**
 * PM2 Ecosystem config for Sunkidz API
 * Run with: pm2 start ecosystem.config.cjs
 */
module.exports = {
  apps: [
    {
      name: 'sunkidz-api',
      script: 'venv/bin/python',
      args: '-m uvicorn app.main:app --host 0.0.0.0 --port 8000',
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production',
      },
      error_file: 'logs/pm2-error.log',
      out_file: 'logs/pm2-out.log',
      merge_logs: true,
      time: true,
    },
  ],
};
