#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please switch to sudo bash to run this script!"
  exit
fi

if [ ! -f "ForcAD_v1.4.0.zip" ];
then
	echo "Missing ForcAD_v1.4.0.zip"
	exit
fi

RED='\033[0;31m'
NC='\033[0m' # No Color
export EASYRSA_BATCH=1

basic_setup() {
	printf "\n\n\n${RED}### Basic setup ###${NC}\n"
	apt-get update
	apt-get remove -y unattended-upgrades
	apt-get install -y build-essential openvpn unzip python3-pip
	mkdir -p /usr/share/.ssh
	mkdir -p /root/.ssh
	ssh-keygen -q -t rsa -N '' -f /usr/share/.ssh/id_rsa <<<y >/dev/null 2>&1
	cp /usr/share/.ssh/id_rsa* /root/.ssh
}

install_docker() {
	printf "\n\n\n${RED}### Docker installation ###${NC}\n"
	# Add Docker's official GPG key:
	apt-get update
	apt-get install -y ca-certificates curl
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
	apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

setup_forcad() {
	printf "\n\n\n${RED}### ForcAD installation ###${NC}\n"
	unzip ForcAD_v1.4.0.zip
	mv ForcAD_v1.4.0 /ForcAD

	cd /ForcAD
	pip3 install -r cli/requirements.txt
	sed -i "s/docker-compose/docker', 'compose/g" cli/utils.py
	sed -i "s/docker-compose/docker', 'compose/g" cli/base/print_tokens.py
	sed -i "s/docker-compose/docker', 'compose/g" cli/base/reset.py
	cd -
}

basic_setup
install_docker
setup_forcad
























