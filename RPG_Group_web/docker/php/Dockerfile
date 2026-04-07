FROM php:8.4-cli-alpine

RUN apk add --no-cache \
        git \
        unzip \
        icu-dev \
    postgresql-dev \
        libzip-dev \
        $PHPIZE_DEPS \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql intl zip \
    && apk del $PHPIZE_DEPS

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

CMD ["php", "-S", "0.0.0.0:8000", "-t", "public"]
