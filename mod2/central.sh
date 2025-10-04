#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
forcad_url=""
checker_url=""
ip_1=""
ip_2=""
ip_lo=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
	cat <<EOF
Usage: $0 [OPTION]... --lo <SERVER-IP> --ip1 <IP1> --ip2 <IP2> [-f FORCAD_URL] [-c CHECKER_URL]

Options:
  -f, --forcad-url              link to download ForcAD.zip (or ensure ForcAD.zip exists locally)
  -c, --checker-url             link to download checkers.zip (or ensure checkers.zip exists locally)
  --lo                          ip of server for general use
  --ip1                         ip of server to communicate with team1
  --ip2                         ip of server to communicate with team2
  -h                            display help message and exit

Example: $0 -f https://github.com/ -c https://github.com/ --lo 10.254.0.254 --ip1 10.254.1.1 --ip2 10.254.2.1

EOF
	exit
}

basic_setup() {
	printf "\n\n\n${RED}### Basic setup ###${NC}\n"

	apt-get update
	apt-get remove -y unattended-upgrades
	echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
	apt-get install -y build-essential iptables-persistent nginx jq openvpn unzip python3-pip
	ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1
}

docker_installation() {
	printf "\n\n\n${RED}### Docker installation ###${NC}\n"

	# Add Docker's official GPG key
	apt-get update --fix-missing
	apt-get install -y ca-certificates curl
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
	apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

forcad_setup() {
	printf "\n\n\n${RED}### ForcAD configuration ###${NC}\n"

	wget $forcad_url -O /tmp/ForcAD.zip
	unzip /tmp/ForcAD.zip -d /
	wget $checker_url -O /tmp/checkers.zip
	unzip -o /tmp/checkers.zip -d /ForcAD    # Overwrite existed checkers

	cd /ForcAD
	find checkers -name checker.py -type f -exec chmod +x {} \;
	cp /root/.ssh/id_rsa ./checkers
	chmod 644 ./checkers/id_rsa
	pip3 install -r cli/requirements.txt
}

network_configuration() {
	printf "\n\n\n${RED}### Network configuration ###${NC}\n"

	rm -rf /etc/netplan/*
	echo """network:
    version: 2
    ethernets:
        ens33:
            optional: true
            dhcp4: true
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
        ens34:
            optional: true
            dhcp4: false
            addresses: [$ip_1/24]
        ens38:
            optional: true
            dhcp4: false
            addresses: [$ip_2/24]""" > "/etc/netplan/01-server-network.yaml"
	chmod 600 "/etc/netplan/01-server-network.yaml"
	netplan apply

	sysctl -w net.ipv4.ip_forward=1
	iptables -P FORWARD DROP
	iptables -I FORWARD -i ens34 -o ens33 -j ACCEPT
	iptables -I FORWARD -i ens33 -o ens34 -j ACCEPT
	iptables -I FORWARD -i ens38 -o ens33 -j ACCEPT
	iptables -I FORWARD -i ens33 -o ens38 -j ACCEPT
	iptables -t nat -I POSTROUTING -o ens33 -j MASQUERADE

	iptables-save > /etc/iptables/rules.v4
}



if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

while getopts ":hf:c:-:" opt; do
	case $opt in
		h)
			usage
			;;
		c)
			checker_url=$OPTARG
			;;
		f)
			forcad_url=$OPTARG
			;;
		-) # Handle long options
			case $OPTARG in
				forcad-url)
					forcad_url="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				checker-url)
					checker_url="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				service-url)
					service_url="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				ip1)
					ip_1="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	 # Shift to next option
					;;
				ip2)
					ip_2="${!OPTIND}" # Next argument is the value
					OPTIND=$((OPTIND + 1))	# Shift to next option
					;;
				lo)
					ip_lo="${!OPTIND}" # Next argument is the value
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

required_vars=(forcad_url checker_url ip_1 ip_2 ip_lo)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Missing required argument: $var"
        usage
    fi
done

basic_setup
docker_installation
forcad_setup
network_configuration
