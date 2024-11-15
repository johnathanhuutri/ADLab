#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'				# No Color
ip_address=""
service_url=""

export EASYRSA_BATCH=1

usage() {
	cat <<EOF
Usage: $0 [OPTION]... -s URL -i IP

Options:
  -s, --service-url             link to download services.zip
  -i, --ip                      ip address that you want to set
  -h, --help                    display help message and exit

Example: $0 -c https://github.com/ -i 192.168.1.10

EOF
	exit
}

basic_setup() {
	printf "\n\n\n${RED}### Basic setup ###${NC}\n"
	apt-get update
	apt-get remove -y unattended-upgrades
	apt-get install -y build-essential openvpn unzip python3-pip
	apt-get clean
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
		"      addresses: [${ip_address}/24]\n" \
		> "/etc/netplan/01-network-manager-all.yaml"
	chmod 600 "/etc/netplan/01-network-manager-all.yaml"
	netplan apply
}

service_configuration() {
	printf "\n\n\n${RED}### Service configuration ###${NC}\n"
	cd /tmp
	wget $service_url -O services.zip
	unzip services.zip -d /
}


if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

while getopts ":hs:i:-:" opt; do
	case $opt in
		h)
			usage
			;;
		s)
			service_url=$OPTARG
			;;
		i)
			ip_address=$OPTARG
			;;
		-) # Handle long options
			case $OPTARG in
				service-url)
					service_url="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				ip)
					ip_address="${!OPTIND}" # Next argument is the value
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

if [[ -z $service_url || -z $ip_address ]]; then
	echo "Error: Missing required arguments"
	usage
fi

basic_setup
docker_installation
network_configuration
service_configuration
cd ~
