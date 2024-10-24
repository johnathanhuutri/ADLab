FROM ubuntu:22.04

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
RUN apt-get install -y apache2 php
RUN apt-get clean

ADD web1/share/entrypoint.sh /entrypoint.sh
ADD web1/share/html/ /var/www/html/
RUN rm /var/www/html/index.html
RUN chown -R ctf:ctf /var/www/html/
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
#CMD ["/bin/sh"]
