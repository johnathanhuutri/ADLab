#!/bin/bash

if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

if [ ! -d "services" ];
then
	echo "Missing service folder"
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
	ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1
}

docker_installation() {
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

network_configuration() {
	printf "\n\n\n${RED}### Network configuration ###${NC}\n"
	echo -e \
		"network:\n" \
		"  version: 2\n" \
		"  ethernets:\n" \
		"    enp2s1:\n" \
		"      optional: true\n" \
		"      dhcp4: false\n" \
		"      addresses: [192.168.1.1/24]\n" \
		> "/etc/netplan/01-network-manager-all.yaml"
	chmod 600 "/etc/netplan/01-network-manager-all.yaml"
	netplan apply
}

service_configuration() {
	printf "\n\n\n${RED}### Service configuration ###${NC}\n"
	mv services /
}

basic_setup
docker_installation
network_configuration
service_configuration
