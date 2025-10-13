FROM alpine:3.20

# 환경변수 기본값
ENV FRPS_BIND_PORT=7000 \
    FRPS_DASH_PORT=7500 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin \
    FRPS_TOKEN=defaulttoken \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=60
	PORT=80

WORKDIR /app

# frps, healthz, startup.sh 복사
COPY frps /usr/local/bin/frps
COPY healthz /usr/local/bin/healthz
COPY startup.sh /app/startup.sh

RUN chmod +x /usr/local/bin/frps /usr/local/bin/healthz /app/startup.sh

EXPOSE 7000 7400 7500 80

CMD ["/app/startup.sh"]
