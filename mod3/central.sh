#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
forcad=""
checker=""
service=""
out=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
    cat <<EOF
Usage: $0 [OPTION]... --out INTERFACE_OUT [-f FORCAD_URL] [-c CHECKER_URL] [-s SERVICE_URL]

Options:
  --out                         interface name for accessing the internet
  -f, --forcad                  link to download ForcAD.zip (omit to use local ForcAD.zip locally)
  -c, --checker                 link to download checkers.zip (omit to use local checkers.zip locally)
  -s, --service                 link to download services.zip (omit to use local services.zip locally)
  -h, --help                    display help message and exit

Example: $0 --out ens33 -f https://github.com/ -c https://github.com/ -s https://github.com/

EOF
    exit
}

network_configuration() {
    printf "\n\n\n${RED}### Network configuration ###${NC}\n"

    mac_out=$(cat /sys/class/net/$out/address)

    # --- Check & apply netplan if not configured ---
    if [ ! -f /etc/netplan/01-network.yaml ]; then
        echo "${YELLOW}Applying new Netplan configuration...${NC}"
        rm -rf /etc/netplan/*
        cat <<EOF > /etc/netplan/01-network.yaml
network:
    version: 2
    ethernets:
        lo:
            addresses:
                - 127.0.0.1/8
                - 10.254.0.254/32
        out:
            optional: true
            dhcp4: true
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
            match:
                macaddress: $mac_out
            set-name: out
EOF
        chmod 600 /etc/netplan/01-network.yaml
        netplan apply
    else
        echo "${GREEN}Netplan already configured, skipping...${NC}"
    fi
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
    if [ ! -f "/etc/sudoers.d/01-passwordless-user" ]; then
        echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/01-passwordless-user
    fi

    check_and_fetch "$forcad" "ForcAD.zip"
    check_and_fetch "$checker" "checkers.zip"
    check_and_fetch "$service" "services.zip"

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
            forcad=$OPTARG
            ;;
        c)
            checker=$OPTARG
            ;;
        s)
            service=$OPTARG
            ;;
        -) # Handle long options
            case $OPTARG in
                out)
                    out="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))     # Shift to next option
                    ;;
                forcad)
                    forcad="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))     # Shift to next option
                    ;;
                checker)
                    checker="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                service)
                    service="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
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

required_vars=(out)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Missing required argument: $var"
        usage
    fi

    # Kiểm tra interface có tồn tại và có file address
    if [ ! -f "/sys/class/net/${!var}/address" ]; then
        echo "Error: Invalid interface: '${!var}'"
        usage
    fi
done

network_configuration
basic_setup
docker_installation
forcad_setup
