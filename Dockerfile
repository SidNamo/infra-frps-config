###############################################
# Stage 1: Build frps from source
###############################################
FROM golang:1.23 AS frps-builder

WORKDIR /src
RUN git clone https://github.com/fatedier/frp.git . && \
    make frps

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

# 필수 패키지 설치
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 기본 환경변수 (Render에서도 override 가능)
ENV FRPS_BIND_PORT=7000 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_PORT=7500 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=300 \
    DOMAIN=localhost

# 빌드된 실행 파일 복사
COPY --from=frps-builder /src/bin/frps /usr/local/bin/frps
COPY --from=healthz-builder /app/healthz /usr/local/bin/healthz

# Render는 80 포트를 외부로 연결
EXPOSE 80

# 실행 시:
# 1️⃣ /app/frps.ini 생성
# 2️⃣ frps 실행
# 3️⃣ healthz 실행
# 4️⃣ keepalive 루프 실행
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
