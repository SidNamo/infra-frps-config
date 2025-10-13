#!/bin/sh
set -e

cat <<EOF > /app/frps.tpl
[common]
bind_port = ${FRPS_BIND_PORT:-7000}
token = ${FRPS_TOKEN:-defaulttoken}
log_file = /dev/stdout
log_level = ${LOG_LEVEL:-info}
log_max_days = 3

# 선택적 대시보드
dashboard_port = ${FRPS_DASH_PORT:-7500}
dashboard_user = ${FRPS_DASH_USER:-admin}
dashboard_pwd = ${FRPS_DASH_PWD:-admin}

# 선택적 API
enable_api = true
api_addr = 0.0.0.0
api_port = ${FRPS_API_PORT:-7400}
EOF

envsubst < /app/frps.tpl > /app/frps.ini

echo "✅ Generated /app/frps.ini:"
cat /app/frps.ini

(frps -c /app/frps.ini &)
sleep 2
(/usr/local/bin/healthz &)

# Koyeb에서는 내부 헬스체크만 유지
while true; do
  curl -fsSL http://127.0.0.1/healthz >/dev/null 2>&1 && \
  echo "🌀 Keepalive $(date '+%Y-%m-%d %H:%M:%S')"
  sleep ${KEEPALIVE_INTERVAL:-60}
done
