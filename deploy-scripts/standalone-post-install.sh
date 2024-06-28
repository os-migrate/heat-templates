#!/bin/bash
GATEWAY=192.168.24.2
STANDALONE_HOST=192.168.24.2
PUBLIC_NETWORK_CIDR=192.168.24.0/24
PRIVATE_NETWORK_CIDR=192.168.100.0/24
PUBLIC_NET_START=192.168.24.40
PUBLIC_NET_END=192.168.24.150
DNS_SERVER=10.11.5.19
PING_TEST=${PING_TEST:-false}

# OS auth
export OS_CLOUD=standalone
# Flavor
openstack flavor create --ram 2048 --disk 15 --vcpu 2 --public m1.medium

# CentOS Image
curl -O https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
openstack image create CentOS-Stream-GenericCloud-9-latest  --container-format bare --disk-format qcow2 --public --file CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2

# Keypair
yes | ssh-keygen
openstack keypair create --public-key ~/.ssh/id_rsa.pub default

# create basic security group to allow ssh/ping/dns
openstack security group create basic
# allow ssh
openstack security group rule create basic --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0
# allow ping
openstack security group rule create --protocol icmp basic
# allow DNS
openstack security group rule create --protocol udp --dst-port 53:53 basic

openstack network create --external --provider-physical-network datacentre --provider-network-type flat public
openstack subnet create public-net \
    --subnet-range $PUBLIC_NETWORK_CIDR \
    --no-dhcp \
    --gateway $GATEWAY \
    --allocation-pool start=$PUBLIC_NET_START,end=$PUBLIC_NET_END \
    --network public \
    --dns-nameserver $DNS_SERVER

# Only for ping and debug tests
if [ "$PING_TEST" = true ]; then
    openstack network create --internal private
    openstack subnet create private-net \
        --subnet-range $PRIVATE_NETWORK_CIDR \
        --network private

    openstack router create vrouter
    openstack router set vrouter --external-gateway public
    openstack router add subnet vrouter private-net
    openstack floating ip create public
    openstack server create --flavor m1.medium --image CentOS-Stream-GenericCloud-9-latest  --key-name default --network private --security-group basic test
    FLOATING_IP=$(openstack floating ip list -c "Floating IP Address" -f value)
    echo "Floating IP: $FLOATING_IP"
    echo "now add floating ip with: openstack server add floating ip test <floating-ip>"
    openstack server add floating ip test $FLOATING_IP
    echo "then ssh with: ssh cloud-user@$FLOATING_IP -i .ssh/id_rsa"
fi
