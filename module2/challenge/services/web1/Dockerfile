FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y openssh-server apache2 php
RUN apt-get clean

RUN useradd -m ctf && echo "ctf:ctf" | chpasswd && echo /bin/bash | chsh ctf && mkdir /root/.ssh
ADD share/entrypoint.sh /entrypoint.sh
ADD share/html/ /var/www/html/
ADD /usr/share/.ssh/id_rsa.pub /root/.ssh

RUN rm /var/www/html/index.html
RUN chown -R ctf:ctf /var/www/html/
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
#CMD ["/bin/sh"]
