FROM php:7.4-apache

MAINTAINER Nightcore

### DO NOT CHANGE THESE LINES ##################
ENV DEBIAN_FRONTEND=noninteractive
ARG SSHKEY

RUN apt-get update
RUN apt-get install -y openssh-server
RUN apt-get clean

RUN useradd -m ctf && \
	echo "ctf:ctf" | chpasswd && \
	echo /bin/bash | chsh ctf && \
	mkdir /root/.ssh && \
	echo $SSHKEY > /root/.ssh/authorized_keys
ADD getflag /getflag
RUN touch /flag1 && \
	chmod 644 /flag1
RUN touch /flag2 && \
	chmod 600 /flag2 && \
	chmod +xs /getflag
################################################

RUN apt-get update 
RUN docker-php-ext-install mysqli
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
RUN a2enmod rewrite
RUN sed -i "s/#\!\/bin\/sh/#\!\/bin\/sh\nservice ssh start/g" /usr/local/bin/docker-php-entrypoint

COPY share/src/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html
RUN chmod -R 775 /var/www/html
RUN chmod -R 777 /var/www/html/uploads
EXPOSE 80