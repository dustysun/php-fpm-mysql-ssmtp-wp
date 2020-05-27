FROM php:fpm

RUN apt-get update && apt-get install -q -y \
		libjpeg-dev \
		libpng-dev \
		libxml2-dev \
		zlib1g-dev \
		libzip-dev \
		# needed for gd
		libfreetype6-dev \
		libjpeg62-turbo-dev \
		mariadb-client \
		msmtp \
		mailutils \
		libmemcached-dev \
		&& rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg

RUN pecl install memcached \
    && echo "extension=memcached.so" > /usr/local/etc/php/conf.d/20_memcached.ini

RUN docker-php-ext-install gd mysqli opcache soap zip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PHP Settings
RUN echo "file_uploads = On" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "upload_max_filesize = 64M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "post_max_size = 72M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "max_execution_time = 180" >> /usr/local/etc/php/conf.d/php-uploads.ini

RUN echo "sendmail_path=sendmail -i -t" >> /usr/local/etc/php/conf.d/php-sendmail.ini

COPY docker-entrypoint.sh /usr/local/bin

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm"]
