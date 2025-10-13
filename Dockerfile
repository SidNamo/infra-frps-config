###############################################
# Stage 1: Build frps (Go 1.24 manually installed)
###############################################
FROM golang:1.23 AS frps-builder

WORKDIR /src

# Go 1.24 수동 설치
RUN apt-get update && apt-get install -y wget tar && \
    wget https://go.dev/dl/go1.24.0.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz && \
    ln -sf /usr/local/go/bin/go /usr/bin/go && \
    go version

# ✅ frp 빌드 (디렉토리 충돌 방지)
RUN git clone https://github.com/fatedier/frp.git frp && \
    cd frp && make frps

###############################################
# Stage 2: Build healthz
###############################################
FROM golang:1.23 AS healthz-builder
WORKDIR /app
COPY healthz.go .
RUN go build -o healthz healthz.go

###############################################
# Stage 3: Runtime - FRPS + Healthz + Keepalive
###############################################
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 기본 환경변수
ENV FRPS_BIND_PORT=7000 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_PORT=7500 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=300 \
    DOMAIN=localhost

# 실행 파일 복사
COPY --from=frps-builder /src/bin/frps /usr/local/bin/frps
COPY --from=healthz-builder /app/healthz /usr/local/bin/healthz

EXPOSE 80

CMD ["/bin/sh", "-c", "\
echo '[common]' > /app/frps.ini && \
echo 'bind_port = ${FRPS_BIND_PORT}' >> /app/frps.ini && \
echo 'dashboard_port = ${FRPS_DASH_PORT}' >> /app/frps.ini && \
echo 'dashboard_user = ${FRPS_DASH_USER}' >> /app/frps.ini && \
echo 'dashboard_pwd = ${FRPS_DASH_PWD}' >> /app/frps.ini && \
echo 'enable_api = true' >> /app/frps.ini && \
echo 'api_addr = 0.0.0.0' >> /app/frps.ini && \
echo 'api_port = ${FRPS_API_PORT}' >> /app/frps.ini && \
echo 'token = ${FRPS_TOKEN}' >> /app/frps.ini && \
echo 'log_file = /dev/stdout' >> /app/frps.ini && \
echo 'log_level = ${LOG_LEVEL}' >> /app/frps.ini && \
echo 'log_max_days = 3' >> /app/frps.ini && \
echo '✅ Generated /app/frps.ini:' && cat /app/frps.ini && \
(frps -c /app/frps.ini &) && \
(/usr/local/bin/healthz &) && \
while true; do \
  curl -fsSL http://${DOMAIN}/healthz >/dev/null 2>&1 && \
  echo \"🌀 Keepalive ping sent at $(date +'%Y-%m-%d %H:%M:%S')\"; \
  sleep ${KEEPALIVE_INTERVAL}; \
done \
"]
