#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please switch to sudo bash to run this script!"
  exit
fi

if [ ! -f "ForcAD.zip" ];
then
	echo "Missing ForcAD.zip"
	exit
fi

if [ ! -d "challenge" ];
then
	echo "Missing challenge folder"
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
	ssh-keygen -q -t rsa -N '' <<< $'\ny' >/dev/null 2>&1
}

install_docker() {
	printf "\n\n\n${RED}### Docker installation ###${NC}\n"
	# Add Docker's official GPG key:
	apt-get update --fix-missing
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

setup_network() {
	printf "\n\n\n${RED}### Network configuration ###${NC}\n"
	echo -e \
		"network:\n" \
		"  version: 2\n" \
		"  ethernets:\n" \
		"    enp2s1:\n" \
		"      optional: true\n" \
		"      dhcp4: true\n" \
		"    enp2s2:\n" \
		"      optional: true\n" \
		"      dhcp4: false\n" \
		"      addresses: [192.168.0.1/24]\n" > "/etc/netplan/01-network-manager-all.yaml"
	chmod 600 "/etc/netplan/01-network-manager-all.yaml"
	netplan apply
}
setup_forcad() {
	printf "\n\n\n${RED}### ForcAD installation ###${NC}\n"
	unzip ForcAD.zip -d /
	cd /ForcAD
	cp /root/.ssh/id_rsa .
	pip3 install -r cli/requirements.txt
	sed -i "s/docker-compose/docker', 'compose/g" cli/utils.py
	sed -i "s/docker-compose/docker', 'compose/g" cli/base/print_tokens.py
	sed -i "s/docker-compose/docker', 'compose/g" cli/base/reset.py
	sed -i "s/COPY .\/checkers \/checkers/COPY .\/checkers \/checkers\n\nRUN mkdir -p \/nonexistent\/.ssh\nCOPY id_rsa \/nonexistent\/.ssh\nRUN chown -R nobody:nogroup \/nonexistent\/.ssh \&\& chmod 600 \/nonexistent\/.ssh\/id_rsa/g" /ForcAD/docker_config/celery/Dockerfile
	cd -
}

basic_setup
install_docker
setup_network
setup_forcad
























