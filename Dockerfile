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

# ✅ gettext-base 설치 (envsubst 포함)
RUN apt-get update && apt-get install -y curl gettext-base && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 기본 환경변수 (Render에서 덮어씌워짐)
ENV FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=60 \
    DOMAIN=localhost

# 실행 파일 복사
COPY --from=frps-builder /src/frp/bin/frps /usr/local/bin/frps
COPY --from=healthz-builder /app/healthz /usr/local/bin/healthz

EXPOSE 7000 7400 7500

CMD ["/bin/sh", "-c", "\
cat <<EOF > /app/frps.tpl
[common]
dashboard_user = \$FRPS_DASH_USER
dashboard_pwd = \$FRPS_DASH_PWD
enable_api = true
api_addr = 0.0.0.0
token = \$FRPS_TOKEN
log_file = /dev/stdout
log_level = \$LOG_LEVEL
log_max_days = 3
bind_port = 7000
dashboard_port = 7500
EOF

# ✅ 템플릿 치환 → 실제 frps.ini 생성
envsubst < /app/frps.tpl > /app/frps.ini && \
echo '✅ Generated /app/frps.ini:' && cat /app/frps.ini && \

# ✅ frps + healthz 실행
(frps -c /app/frps.ini &) && \
(/usr/local/bin/healthz &) && \

# ✅ 주기적 ping (Render 슬립 방지)
while true; do \
  curl -fsSL http://\${DOMAIN}/healthz >/dev/null 2>&1 && \
  echo \"🌀 Keepalive ping sent at $(date +'%Y-%m-%d %H:%M:%S')\"; \
  sleep \${KEEPALIVE_INTERVAL}; \
done \
"]
