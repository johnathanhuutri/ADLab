#!/bin/bash

# https://documentation.ubuntu.com/server/how-to/security/install-openvpn/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-22-04
# DHCP Pool: https://serverfault.com/a/1013100

### Change this #########################################################
SERVER_POOL='10.100.101.0 255.255.255.0'           # '<ip> <subnetmask>'
TEAM1_IP='10.100.100.1'                            # '<ip>'
TEAM2_IP='10.100.100.2'                            # '<ip>'
#########################################################################
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit
fi

if [ ! "$1" ]; then
	echo "Usage: $0 <public-ip>"
	echo "Ex:    $0 123.123.123.123"
	exit
fi

export EASYRSA_BATCH=1

printf "\n\n\n${RED}### Installing OpenVPN and Easy-RSA...${NC}\n"
apt update
apt install -y openvpn openvpn easy-rsa

printf "\n\n\n${RED}### Setting up the Certificate Authority...${NC}\n"
make-cadir /root/easy-rsa
cd /root/easy-rsa
echo -e 'set_var EASYRSA_ALGO "ec"\nset_var EASYRSA_DIGEST "sha512"\n' >> vars
echo './easyrsa init-pki'
./easyrsa init-pki
echo './easyrsa build-ca'
./easyrsa build-ca

printf "\n\n\n${RED}### Generating server certificates and keys...${NC}\n"
./easyrsa --batch --req-cn=server gen-req server nopass
./easyrsa --batch --req-cn=server sign-req server server
openvpn --genkey --secret ta.key
cp pki/private/server.key /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/ca.crt /etc/openvpn/server/
cp ta.key /etc/openvpn/server

names=( 'proxy1' 'proxy2' 'client' )
for name in ${names[@]}; do
    printf "\n\n\n${RED}### Generating client certificates and keys for ${name}...${NC}\n"
    mkdir -p /root/${name}/keys
    chmod -R 700 /root/${name}/keys
    ./easyrsa --batch --req-cn=${name} gen-req ${name} nopass
    ./easyrsa --batch --req-cn=${name} sign-req client ${name} nopass
    cp pki/private/${name}.key /root/${name}/keys/
    cp pki/issued/${name}.crt /root/${name}/keys/
    cp pki/ca.crt /root/${name}/keys/
    cp ta.key /root/${name}/keys/
done

printf "\n\n\n${RED}### Configuring OpenVPN server...${NC}\n"
cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/
sed -i "s/server 10.8.0.0 255.255.255.0/server ${SERVER_POOL}\npush \"route ${SERVER_POOL}\"\nroute ${TEAM1_IP} 255.255.255.255\nroute ${TEAM2_IP} 255.255.255.255/g" /etc/openvpn/server/server.conf
sed -i 's/;tls-auth ta.key 0/tls-crypt ta.key/g' /etc/openvpn/server/server.conf
sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /etc/openvpn/server/server.conf
sed -i 's/dh dh2048.pem/dh none/g' /etc/openvpn/server/server.conf
sed -i 's/;client-config-dir ccd/client-config-dir ccd/g' /etc/openvpn/server/server.conf
sed -i 's/;client-to-client/client-to-client/g' /etc/openvpn/server/server.conf
sed -i 's/;duplicate-cn/duplicate-cn/g' /etc/openvpn/server/server.conf

printf "\n\n\n${RED}### Configuring static IP for proxies...${NC}\n"
mkdir /etc/openvpn/server/ccd
echo "ifconfig-push ${TEAM1_IP} 255.255.255.255" > /etc/openvpn/server/ccd/proxy1
echo "ifconfig-push ${TEAM2_IP} 255.255.255.255" > /etc/openvpn/server/ccd/proxy2

printf "\n\n\n${RED}### Adjusting Networking Configuration...${NC}\n"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/openvpn/server/server.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

printf "\n\n\n${RED}### Adjusting Firewall Configuration...${NC}\n"
ufw allow 1194/udp
ufw allow OpenSSH
ufw disable
ufw enable <<<y

printf "\n\n\n${RED}### Starting OpenVPN Server...${NC}\n"
systemctl start openvpn-server@server

### Install server ################################################
echo '''#!/bin/bash
 
KEY_DIR=~/${1}/keys
OUTPUT_DIR=~
BASE_CONFIG=~/${1}/client.conf
 
cat ${BASE_CONFIG} \
    <(echo -e "<ca>") \
    ${KEY_DIR}/ca.crt \
    <(echo -e "</ca>\n<cert>") \
    ${KEY_DIR}/${1}.crt \
    <(echo -e "</cert>\n<key>") \
    ${KEY_DIR}/${1}.key \
    <(echo -e "</key>\n<tls-crypt>") \
    ${KEY_DIR}/ta.key \
    <(echo -e "</tls-crypt>") \
    > ${OUTPUT_DIR}/${1}.ovpn''' > /root/make_config.sh
chmod 700 /root/make_config.sh
cd /root

names=( 'proxy1' 'proxy2' )
for name in ${names[@]}; do
    printf "\n\n\n${RED}Generating ${name} configuration - ${name}.ovpn${NC}\n"
    cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/${name}/
    sed -i "s/remote my-server-1 1194/remote $1 1194/g" /root/${name}/client.conf
    sed -i 's/ca ca.crt/;ca ca.crt/g' /root/${name}/client.conf
    sed -i 's/cert client.crt/;cert client.crt/g' /root/${name}/client.conf
    sed -i 's/key client.key/;key client.key/g' /root/${name}/client.conf
    sed -i 's/tls-auth ta.key 1/;tls-auth ta.key 1/g' /root/${name}/client.conf
    sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /root/${name}/client.conf
    echo 'key-direction 1' >> /root/${name}/client.conf

    ./make_config.sh ${name}
done

printf "\n\n\n${RED}Generating client configuration - client.ovpn${NC}\n"
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/client/
sed -i "s/remote my-server-1 1194/remote $1 1194/g" /root/client/client.conf
sed -i "s/ca ca.crt/;ca ca.crt/g" /root/client/client.conf
sed -i "s/cert client.crt/;cert client.crt/g" /root/client/client.conf
sed -i "s/key client.key/;key client.key\nroute ${TEAM1_IP} 255.255.255.255\nroute ${TEAM2_IP} 255.255.255.255/g" /root/client/client.conf
sed -i "s/tls-auth ta.key 1/;tls-auth ta.key 1/g" /root/client/client.conf
sed -i "s/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g" /root/client/client.conf
echo 'key-direction 1' >> /root/client/client.conf

./make_config.sh client
