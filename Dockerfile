# Base image.
FROM php:7.4-apache

# Install Composer
RUN set -ex; \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer;

# Install Xdebug
RUN set -ex; \
    pecl install xdebug-3.1.4; \
    docker-php-ext-enable xdebug; \
    rm -r /tmp/pear;

# persistent dependencies
# Set (with a minus -) or unset (with a plus +) settings for the shell, influencing the behavior of shell scripts.
# -e : instructs a shell to exit if a command fails (non-zero exit code)
# -u : treats unset or undefined variables as an error when substituting. Ex.: version='5.9.3'; echo "${version}";
# -x : prints out command arguments during execution
# https://phoenixnap.com/kb/linux-set
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    # Ghostscript is required for rendering PDF previews
    ghostscript \
    ; \
    # Remove recursively and forcefully the package lists. Tools like apt-get cannot get package information unless you update the package lists (apt-get update)
    rm -rf /var/lib/apt/lists/*

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
    \
    # apt-mark allows you to set various settings for a package, such as marking a package as being  automatically/manually installed.
    # showmanual will prints a list of manually installed packages, with each package on a new line.
    # https://manpages.ubuntu.com/manpages/bionic/man8/apt-mark.8.html
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libmagickwand-dev \
    libpng-dev \
    libwebp-dev \
    libzip-dev \
    ; \
    \
    docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    ; \
    docker-php-ext-install -j "$(nproc)" \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    zip \
    ; \
    # https://pecl.php.net/package/imagick
    pecl install imagick-3.6.0; \
    docker-php-ext-enable imagick; \
    rm -r /tmp/pear; \
    \
    # some misbehaving extensions end up outputting to stdout 🙈 (https://github.com/docker-library/wordpress/issues/669#issuecomment-993945967)
    # php -r : run code without using <??>
    out="$(php -r 'exit(0);')"; \
    [ -z "$out" ]; \
    err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
    [ -z "$err" ]; \
    \
    extDir="$(php -r 'echo ini_get("extension_dir");')"; \
    [ -d "$extDir" ]; \
    # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$extDir"/*.so \
    | awk '/=>/ { print $3 }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    \
    ! { ldd "$extDir"/*.so | grep 'not found'; }; \
    # check for output like "PHP Warning:  PHP Startup: Unable to load dynamic library 'foo' (tried: ...)
    err="$(php --version 3>&1 1>&2 2>&3)"; \
    [ -z "$err" ]

RUN set -eux; \
    a2enmod rewrite headers expires; \
    \
    # https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
    a2enmod remoteip; \
    { \
    echo 'RemoteIPHeader X-Forwarded-For'; \
    # these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
    echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
    echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
    echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
    echo 'RemoteIPTrustedProxy 169.254.0.0/16'; \
    echo 'RemoteIPTrustedProxy 127.0.0.0/8'; \
    } > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    # https://github.com/docker-library/wordpress/issues/383#issuecomment-507886512
    # (replace all instances of "%h" with "%a" in LogFormat)
    find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
    # https://www.php.net/manual/en/errorfunc.constants.php
    # https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
    echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
    echo 'display_errors = On'; \
    echo 'display_startup_errors = On'; \
    echo 'log_errors = On'; \
    echo 'error_log = /dev/stderr'; \
    echo 'log_errors_max_len = 1024'; \
    echo 'ignore_repeated_errors = On'; \
    echo 'ignore_repeated_source = Off'; \
    echo 'html_errors = Off'; \
    } > /usr/local/etc/php/conf.d/error-logging.ini

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
    docker-php-ext-enable opcache; \
    { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

WORKDIR /var/www/mydomain/public

ENV APACHE_DOCUMENT_ROOT /var/www/mydomain/public

RUN set -eux; \
    \
    # https://wordpress.org/support/article/htaccess/
    [ ! -e "${APACHE_DOCUMENT_ROOT}/.htaccess" ]; \
    { \
    echo 'RewriteEngine On'; \
    echo 'RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]'; \
    echo 'RewriteCond %{REQUEST_FILENAME} !-d'; \
    echo 'RewriteCond %{REQUEST_URI} (.+)/$'; \
    echo 'RewriteRule ^ %1 [L, R=301]'; \
    echo 'RewriteCond %{REQUEST_FILENAME} !-f'; \
    echo 'RewriteCond %{REQUEST_FILENAME} !-d'; \
    echo 'RewriteRule . /index.php [L]'; \
    } > ${APACHE_DOCUMENT_ROOT}/.htaccess;

# sed options are:
# -e <script> : add the script to the commands to be executed
# -r : use extended regular expressions
# -i : edit files in place
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf; \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf;

RUN [ -e "${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini" ]; \
    { \
    echo 'xdebug.mode=debug'; \
    echo 'xdebug.start_with_request=yes'; \
    echo 'xdebug.client_host=host.docker.internal'; \
    } >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini;
