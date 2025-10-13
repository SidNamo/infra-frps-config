###############################################
# Stage 1: Build frps
###############################################
FROM golang:1.23 AS frps-builder
WORKDIR /src
RUN apt-get update && apt-get install -y wget tar && \
    wget https://go.dev/dl/go1.24.0.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz && \
    ln -sf /usr/local/go/bin/go /usr/bin/go && \
    go version
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
RUN apt-get update && apt-get install -y curl gettext-base && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV FRPS_DASH_USER=admin \
    FRPS_DASH_PWD=admin123 \
    FRPS_TOKEN=changeme-secret \
    LOG_LEVEL=info \
    KEEPALIVE_INTERVAL=60 \
    DOMAIN=localhost

COPY --from=frps-builder /src/frp/bin/frps /usr/local/bin/frps
COPY --from=healthz-builder /app/healthz /usr/local/bin/healthz

EXPOSE 7000 7400 7500

COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

CMD ["/usr/local/bin/startup.sh"]
