FROM ubuntu:22.04

### DO NOT CHANGE THESE LINES ##################
ENV DEBIAN_FRONTEND=noninteractive
ARG SSHKEY

RUN apt-get update && \
    apt-get install -y openssh-server apache2 php libapache2-mod-php php-curl && \
    apt-get clean

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

# Enable mod_rewrite for Apache
RUN a2enmod rewrite

RUN rm -rf /var/www/html/*
# Copy your application code into the container
COPY ./share/html/ /var/www/html
COPY ./share/php.ini /etc/php/8.1/apache2/
COPY ./share/entrypoint.sh /entrypoint.sh
# Set proper permissions for the Apache server
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html
RUN chmod +x /entrypoint.sh

# Start Apache in the foreground
CMD ["/entrypoint.sh"]


