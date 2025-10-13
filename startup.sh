#!/bin/sh
set -e

cat <<EOF > /app/frps.tpl
[common]
dashboard_user = ${FRPS_DASH_USER}
dashboard_pwd = ${FRPS_DASH_PWD}
enable_api = true
api_addr = 0.0.0.0
token = ${FRPS_TOKEN}
log_file = /dev/stdout
log_level = ${LOG_LEVEL}
log_max_days = 3
bind_port = 7000
dashboard_port = 7500
EOF

envsubst < /app/frps.tpl > /app/frps.ini

echo "✅ Generated /app/frps.ini:"
cat /app/frps.ini

(frps -c /app/frps.ini &)
sleep 3
(/usr/local/bin/healthz &)

while true; do
  curl -fsSL http://${DOMAIN}/healthz >/dev/null 2>&1 && \
  echo "🌀 Keepalive ping sent at $(date +'%Y-%m-%d %H:%M:%S')"
  sleep ${KEEPALIVE_INTERVAL}
done
