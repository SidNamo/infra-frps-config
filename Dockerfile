###############################################
# Stage 1: Build healthz (Go uptime endpoint)
###############################################
FROM golang:1.23 AS builder

# 작업 디렉터리 지정
WORKDIR /app

# 헬스체크용 Go 파일 복사
COPY healthz.go .

# 실행 가능한 바이너리로 빌드
RUN go build -o healthz healthz.go


###############################################
# Stage 2: Runtime - FRPS + Healthz
###############################################
FROM ghcr.io/fatedier/frps:latest

# 작업 디렉터리
WORKDIR /app

# -------- 기본 환경변수 설정 --------
# Render 대시보드나 .env 파일에서 덮어쓸 수 있음
ENV FRPS_BIND_PORT=7000 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_PORT=7500 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info

# healthz 바이너리를 빌드 스테이지에서 복사
COPY --from=builder /app/healthz /usr/local/bin/healthz

# Render는 기본적으로 외부 요청을 80 포트로 전달함
EXPOSE 80

# -------- 실행 단계 --------
# 1️⃣ 환경변수 기반으로 frps.ini를 동적으로 생성
# 2️⃣ 설정을 출력해 로그로 확인
# 3️⃣ frps 백그라운드 실행
# 4️⃣ healthz 서버 실행 (Render용)
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
echo '✅ Generated /app/frps.ini:' && \
cat /app/frps.ini && \
(frps -c /app/frps.ini &) && exec /usr/local/bin/healthz \
"]
