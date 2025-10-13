# ---------------------------
# 1. Build stage (healthz)
# ---------------------------
FROM golang:1.23 AS builder
WORKDIR /app
COPY healthz.go .
RUN go build -o healthz healthz.go

# ---------------------------
# 2. Runtime stage (FRPS + Healthz)
# ---------------------------
FROM fatedier/frps:latest
WORKDIR /app

# 환경 변수 기본값 (Render 환경에서도 override 가능)
ENV FRPS_BIND_PORT=7000 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_PORT=7500 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info

# healthz 바이너리 복사
COPY --from=builder /app/healthz /usr/local/bin/healthz

# 포트 노출 (Render는 80으로만 연결됨)
EXPOSE 80

# 시작 스크립트 작성
CMD sh -c '\
cat <<EOF > /app/frps.ini
[common]
bind_port = ${FRPS_BIND_PORT}
dashboard_port = ${FRPS_DASH_PORT}
dashboard_user = ${FRPS_DASH_USER}
dashboard_pwd = ${FRPS_DASH_PWD}
enable_api = true
api_addr = 0.0.0.0
api_port = ${FRPS_API_PORT}
token = ${FRPS_TOKEN}
log_file = /dev/stdout
log_level = ${LOG_LEVEL}
log_max_days = 3
EOF

echo "✅ Generated /app/frps.ini:"
cat /app/frps.ini

# 동시에 frps와 healthz 실행
(frps -c /app/frps.ini &) && exec /usr/local/bin/healthz
'
