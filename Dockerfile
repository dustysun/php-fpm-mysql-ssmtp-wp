FROM php:fpm

RUN apt-get update && apt-get install -q -y zlib1g-dev mysql-client sendmail mailutils && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install mysqli zip


# PHP Settings
RUN echo "file_uploads = On" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "memory_limit = 128M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "upload_max_filesize = 20M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "post_max_size = 25M" >> /usr/local/etc/php/conf.d/php-uploads.ini
RUN echo "max_execution_time = 90" >> /usr/local/etc/php/conf.d/php-uploads.ini

RUN echo "sendmail_path=sendmail -i -t" >> /usr/local/etc/php/conf.d/php-sendmail.ini

COPY docker-entrypoint.sh /usr/local/bin

ENTRYPOINT ["docker-entrypoint.sh"]

CMD /usr/sbin/service sendmail restart

CMD ["php-fpm"]
