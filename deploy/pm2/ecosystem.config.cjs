module.exports = {
  apps: [
    {
      name: 'sunkidz-backend',
      cwd: '/var/www/sunkidz/backend',
      script: '/var/www/sunkidz/deploy/pm2/start_backend.sh',
      interpreter: 'none',
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      max_restarts: 10,
      restart_delay: 3000,
      env_file: '/var/www/sunkidz/backend/.env',
      env: {
        PYTHONUNBUFFERED: '1',
      },
      error_file: '/var/log/pm2/sunkidz-backend-error.log',
      out_file: '/var/log/pm2/sunkidz-backend-out.log',
      merge_logs: true,
      time: true,
    },
  ],
};
