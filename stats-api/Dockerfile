FROM composer:2 AS builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist
COPY . .
RUN composer dump-autoload --optimize --no-dev

FROM php:8.4-fpm-alpine
ARG GIT_SHA=dev
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    REDIS_CLIENT=predis \
    GIT_SHA=${GIT_SHA}

# hadolint ignore=DL3018
RUN apk add --no-cache nginx \
    && addgroup -S -g 1001 appgroup && adduser -S -u 1001 appuser -G appgroup

WORKDIR /var/www/html
COPY --from=builder /app /var/www/html
COPY docker/nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p storage/framework/sessions storage/framework/views storage/framework/cache storage/logs bootstrap/cache \
    && APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= php artisan config:cache \
    && php artisan route:cache \
    && chown -R 1001:1001 /var/www/html /var/lib/nginx /var/log/nginx

USER 1001:1001
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
