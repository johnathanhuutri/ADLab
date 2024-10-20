#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ ! -z "ForcAD_v1.4.0.zip" ];
then
	echo "Missing ForcAD_v1.4.0.zip"
	exit
fi

install_docker() {
	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install build-essential ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
}

setup_forcad() {
	unzip ForcAD_v1.4.0.zip
	mv ForcAD_v1.4.0 /ForcAD
}

apt remove unattended-upgrades
install_docker
setup_forcad
























