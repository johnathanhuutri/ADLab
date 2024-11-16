#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'				# No Color
client_ip=""
server_ip=""
service_url=""

export EASYRSA_BATCH=1

usage() {
	cat <<EOF
Usage: $0 [OPTION]... -s SERVICE-URL --cip CLIENT-IP --sip SERVER-IP

Options:
  -s, --service-url             link to download services.zip
  --cip                         client ip address (current machine's ip)
  --sip                         server ip address (for default gateway)
  -h, --help                    display help message and exit

Example: $0 -s https://github.com/ --cip 10.254.1.2 --sip 10.254.1.1

EOF
	exit
}

network_configuration() {
	printf "\n\n\n$RED### Network configuration ###$NC\n"
	rm -rf /etc/netplan/*
	echo """network:
    version: 2
    ethernets:
        ens33:
            optional: true
            dhcp4: true
            addresses: [$client_ip/24]
            routes:
              - to: default
                via: $server_ip
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]""" > "/etc/netplan/01-client-network.yaml"
	chmod 600 "/etc/netplan/01-client-network.yaml"
	netplan apply
}

basic_setup() {
	printf "\n\n\n$RED### Basic setup ###$NC\n"
	apt-get update
	apt-get remove -y unattended-upgrades
	apt-get install -y build-essential openvpn unzip python3-pip
	apt-get clean
	ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1
}

docker_installation() {
	printf "\n\n\n$RED### Docker installation ###$NC\n"
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

service_configuration() {
	printf "\n\n\n$RED### Service configuration ###$NC\n"
	cd /tmp
	wget $service_url -O services.zip
	unzip services.zip -d /
}


if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

while getopts ":hs:-:" opt; do
	case $opt in
		h)
			usage
			;;
		s)
			service_url=$OPTARG
			;;
		-) # Handle long options
			case $OPTARG in
				service-url)
					service_url="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				cip)
					client_ip="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				sip)
					server_ip="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				*)
					echo "Invalid option --$OPTARG"
					usage
					;;
			esac
			;;
		\?) # Invalid short option
			echo "Invalid option: -$OPTARG"
			usage
			;;
		:) # Missing argument
			echo "Option -$OPTARG requires an argument."
			usage
			;;
	esac
done

if [[ -z $service_url || -z $client_ip || -z $server_ip ]]; then
	echo "Error: Missing required arguments"
	usage
fi

network_configuration
basic_setup
docker_installation
service_configuration
cd ~
