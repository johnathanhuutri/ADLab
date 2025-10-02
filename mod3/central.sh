#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
forcad_url=""
checker_url=""
service_url=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
	cat <<EOF
Usage: $0 [OPTION]... [-f FORCAD_URL] [-c CHECKER_URL] [-s SERVICE_URL]

Options:
  -f, --forcad-url              link to download ForcAD.zip (or ensure ForcAD.zip exists locally)
  -c, --checker-url             link to download checkers.zip (or ensure checkers.zip exists locally)
  -s, --service-url             link to download services.zip (or ensure services.zip exists locally)
  -h, --help                    display help message and exit

Example: $0 -f https://github.com/ForcAD.zip -c https://github.com/checkers.zip -s https://github.com/services.zip

EOF
	exit
}

check_and_fetch() {
    local url=$1      # url tương ứng
    local file=$2     # file local cần kiểm tra

    if [ -n "$url" ]; then
        echo "[*] Downloading $file from $url"
        wget -q "$url" -O "$file" || { echo "[-] Failed to download $file"; exit 1; }
    else
        if [ ! -f "$file" ]; then
            echo "[-] Missing $file: neither URL provided nor local file found ($file)"
            exit 1
        fi
        echo "[*] Using local file: $file"
    fi
}

basic_setup() {
	printf "\n\n\n${RED}### Basic setup ###${NC}\n"

	apt-get update
	apt-get remove -y unattended-upgrades
	echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
	apt-get install -y build-essential iptables-persistent jq openvpn unzip python3-pip
	ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1

	check_and_fetch "$forcad_url" "ForcAD.zip"
	check_and_fetch "$checker_url" "checkers.zip"
	check_and_fetch "$service_url" "services.zip"

	unzip -o ForcAD.zip -d /
	unzip -o checkers.zip -d /ForcAD
	unzip -o services.zip -d /
}

docker_installation() {
	printf "\n\n\n${RED}### Docker installation ###${NC}\n"

    if command -v docker >/dev/null 2>&1; then
        echo "[*] Docker is already installed, skipping installation."
        return
    fi

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

	usermod -aG docker $SUDO_USER

    echo "[+] Docker installed successfully."
}

forcad_setup() {
	printf "\n\n\n${RED}### ForcAD configuration ###${NC}\n"

	cd /ForcAD
	find checkers -name checker.py -type f -exec chmod +x {} \;
	cp /root/.ssh/id_rsa ./checkers
	chmod 644 ./checkers/id_rsa
	pip3 install -r cli/requirements.txt
	cd -
}


if [ "$EUID" -ne 0 ]
	then echo "Please run as sudo"
	exit
fi

while getopts ":hf:c:s:-:" opt; do
	case $opt in
		h)
			usage
			;;
		f)
			forcad_url=$OPTARG
			;;
		c)
			checker_url=$OPTARG
			;;
		s)
			service_url=$OPTARG
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
				help)
					usage
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

basic_setup
docker_installation
forcad_setup
