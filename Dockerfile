# -----------------------------
# 1단계: Build healthz
# -----------------------------
FROM golang:1.22-alpine AS builder
WORKDIR /src

# healthz.go 복사
COPY healthz.go .

# healthz 바이너리 빌드
RUN go build -o /healthz healthz.go


# -----------------------------
# 2단계: Runtime (frps 실행 환경)
# -----------------------------
FROM alpine:3.20
WORKDIR /app

# 환경변수 설정
ENV FRPS_BIND_PORT=7000 \
    FRPS_API_PORT=7400 \
    FRPS_DASH_PORT=7500 \
    FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin \
    FRPS_TOKEN=defaulttoken \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=60 \
    PORT=80

# frps 공식 바이너리 다운로드
RUN apk add --no-cache wget tar && \
    wget -O /tmp/frp.tgz https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz && \
    tar -xzf /tmp/frp.tgz -C /tmp && \
    mv /tmp/frp_*/frps /usr/local/bin/frps && \
    chmod +x /usr/local/bin/frps

# healthz, startup.sh 복사
COPY --from=builder /healthz /usr/local/bin/healthz
COPY startup.sh /app/startup.sh

RUN chmod +x /usr/local/bin/healthz /app/startup.s
