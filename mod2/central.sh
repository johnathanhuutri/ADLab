#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
checker_url=""
ifname_1=""
ifname_2=""
ip_address_1=""
ip_address_2=""

export EASYRSA_BATCH=1

usage() {
	cat <<EOF
Usage: $0 [OPTION]... -c URL --ip1 IP --ip2 IP

Options:
  -c, --checker-url             link to download services.zip
  --if1                         interface name to team1
  --ip1                         ip that is in the same network of team1
  --if2                         interface name to team2
  --ip2                         ip that is in the same network of team2
  -h, --help                    display help message and exit

Example: $0 -c https://github.com/ --if1 ens34 --ip1 192.168.1.1 --if2 ens38 --ip2 192.168.2.1

EOF
	exit
}

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

forcad_installation() {
	printf "\n\n\n${RED}### ForcAD installation ###${NC}\n"
	cd /tmp

	wget https://github.com/johnathanhuutri/ADLab_v2/releases/download/v1.4.0/ForcAD.zip -O ForcAD.zip
	unzip ForcAD.zip -d /
	wget $checker_url -O checkers.zip
	unzip checkers.zip -d /ForcAD

	cd /ForcAD
	find checkers -mindepth 1 -type d -exec chmod +x "{}/checker.py" \;
	cp /root/.ssh/id_rsa ./checkers
	chmod 644 ./checkers/id_rsa
	pip3 install -r cli/requirements.txt
}

network_configuration() {
	printf "\n\n\n${RED}### Network configuration ###${NC}\n"
	sysctl -w net.ipv4.ip_forward=1
	echo -e \
		"network:\n" \
		"  version: 2\n" \
		"  ethernets:\n" \
		"    enp2s1:\n" \
		"      optional: true\n" \
		"      dhcp4: true\n" \
		"    $ifname_1:\n" \
		"      optional: true\n" \
		"      dhcp4: false\n" \
		"      addresses: [$network_1/24]\n" \
		"    $ifname_2:\n" \
		"      optional: true\n" \
		"      dhcp4: false\n" \
		"      addresses: [$network_2/24]\n" \
		> "/etc/netplan/01-network-manager-all.yaml"
	chmod 600 "/etc/netplan/01-network-manager-all.yaml"
	netplan apply
}

checker_configuration() {
	printf "\n\n\n${RED}### Checker configuration ###${NC}\n"
}


if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

while getopts ":hc:-:" opt; do
	case $opt in
		h)
			usage
			;;
		c)
			checker_url=$OPTARG
			;;
		-) # Handle long options
			case $OPTARG in
				ip1)
					network_1="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				ip2)
					network_2="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				if1)
					ifname_1="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				if2)
					ifname_2="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
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

if [[ -z $checker_url || -z $network_1 || -z $network_2 ]]; then
	echo "Error: Missing required arguments"
	usage
fi

basic_setup
docker_installation
forcad_installation
network_configuration
cd ~
