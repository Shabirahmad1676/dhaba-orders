FROM alpine:3.21
ARG KUBECTL_VERSION=v1.32.2

# hadolint ignore=DL3018
RUN apk add --no-cache bash curl ca-certificates \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && addgroup -S -g 1001 appgroup && adduser -S -u 1001 appuser -G appgroup

WORKDIR /app
COPY scripts/monitor /app/scripts/monitor

USER 1001:1001
ENTRYPOINT ["/app/scripts/monitor/run-all.sh"]
