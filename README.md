Develop Magnum with Devstack
============================

## Devstack VM HOST

### network interface

    # This file describes the network interfaces available on your system
    # and how to activate them. For more information, see interfaces(5).

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    auto em1
    iface em1 inet manual
      up ip link set $IFACE up
      up ip link set $IFACE promisc on
      down ip link set $IFACE promisc off
      down ip link set $IFACE down

    auto br0
    iface br0 inet static
      address 192.168.11.196
      netmask 255.255.255.0
      gateway 192.168.11.1
      dns-nameservers 8.8.8.8
      bridge_ports em1
      bridge_stp off
      bridge_fd 0
      bridge_maxwait 0

### uvt-kvm

    $ uvt-kvm create devstack release=trusty \
              --bridge br0 --cpu 2 --memory 24576 --disk 200 \
              --user-data ~/init-devstack.cfg

## Inside VM

### Network settings

    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

### Install DevStack

    $ cd ~
    $ sudo mkdir - p /etc/neutron
    $ sudo chown -R $USER /etc/neutron
    $ echo "dhcp-option-force=26,1400" >> /etc/neutron/dnsmasq.conf
    $ git clone https://git.openstack.org/openstack-dev/devstack
    $ cd devstack
    $ ./stack.sh

local.conf is below.

    [[local|localrc]]
    HOST_IP=192.168.11.197

    FLOATING_RANGE=172.16.12.0/24
    PUBLIC_NETWORK_GATEWAY=172.16.12.1
    ENABLE_TENANT_VLANS=True
    TENANT_VLAN_RANGE=1000:1999
    PHYSICAL_NETWORK=public
    OVS_PHYSICAL_BRIDGE=br-ex

    ADMIN_PASSWORD=openstack
    MYSQL_PASSWORD=stackdb
    RABBIT_PASSWORD=stackqueue
    SERVICE_PASSWORD=$ADMIN_PASSWORD
    SERVICE_TOKEN=tokentoken

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service q-lbaas
    enable_service neutron

    enable_service h-eng
    enable_service h-api
    enable_service h-api-cfn
    enable_service h-api-cw

    enable_plugin barbican https://git.openstack.org/openstack/barbican
    enable_plugin neutron-lbaas https://git.openstack.org/openstack/neutron-lbaas

    [[post-config|/etc/neutron/dhcp_agent.ini]]
    [DEFAULT]
    dnsmasq_config_file = /etc/neutron/dnsmasq.conf

## Magnum

### Install

Magnum is outside of devstack.
In this case, magnum will install to 192.168.11.132 host.

#### Magnum Server

    $ cd ~
    $ git clone https://github.com/openstack/magnum.git
    $ cd magnum
    $ tox -evenv -- echo 'done'

#### Magnum Client

    $ cd ~
    $ git clone https://github.com/openstack/python-magnumclient.git
    $ cd python-magnumclient
    $ tox -evenv -- echo 'done'

### Configuration

#### Setup trust

    TRUSTEE_DOMAIN_ID=$(
        openstack domain create magnum \
            --description "Owns users and projects created by magnum" \
            -f value -c id
    )
    TRUSTEE_DOMAIN_ADMIN_ID=$(
        openstack user create trustee_domain_admin \
            --password "password" \
            --domain=${TRUSTEE_DOMAIN_ID} \
            --or-show \
            -f value -c id
    )
    openstack --os-identity-api-version 3 role add \
              --user $TRUSTEE_DOMAIN_ADMIN_ID --domain $TRUSTEE_DOMAIN_ID \
              admin

#### Create config

    $ sudo mkdir -p /etc/magnum
    $ cd /etc/magnum
    $ sudo vim magnum.conf

magnum.conf has below content.
Change 192.168.11.197 to your devstack IP address.

    [DEFAULT]
    debug = True
    verbose = True

    rabbit_userid=stackrabbit
    rabbit_password = stackqueue
    rabbit_hosts = 192.168.11.197
    rpc_backend = rabbit

    [database]
    connection = mysql://root:stackdb@192.168.11.197/magnum

    [keystone_authtoken]
    admin_password = openstack
    admin_user = nova
    admin_tenant_name = service
    identity_uri = http://192.168.11.197:35357
    #user_domain_id = default
    #project_domain_id = default

    auth_uri=http://192.168.11.197:5000/v3

    [api]

    host = 0.0.0.0

    [cinder_client]
    region_name = RegionOne

    [trust]
    #trustee_domain_id = magnum
    #trustee_domain_admin_id = trustee_domain_admin
    trustee_domain_admin_password = password

Update trust config

    # set trustee domain id
    sudo sed -i "s/#trustee_domain_id\s*=.*/trustee_domain_id=${TRUSTEE_DOMAIN_ID}/" \
             /etc/magnum/magnum.conf

    # set trustee domain admin id
    sudo sed -i "s/#trustee_domain_admin_id\s*=.*/trustee_domain_admin_id=${TRUSTEE_DOMAIN_ADMIN_ID}/" \
             /etc/magnum/magnum.conf

    # set trustee domain admin password
    sudo sed -i "s/#trustee_domain_admin_password\s*=.*/trustee_domain_admin_password=password/" \
             /etc/magnum/magnum.conf

    # set correct region name to clients
    sudo sed -i "s/#region_name\s*=.*/region_name=RegionOne/" \
             /etc/magnum/magnum.conf

#### register magnum service to keystone

    $ IDENTITY_API_VERSION=3
    $ source ~/devstack/openrc admin admin
    $ openstack service create --name=magnum \
                               --description="Magnum Container Service" \
                               container
    $ openstack endpoint create --region=RegionOne \
                                container public http://192.168.11.132:9511/v1
    $ openstack endpoint create --region=RegionOne \
                                container internal http://192.168.11.132:9511/v1
    $ openstack endpoint create --region=RegionOne \
                                container admin http://192.168.11.132:9511/v1


#### Register Image to glance

    $ curl -O http://tarballs.openstack.org/magnum/images/fedora-atomic-f23-dib.qcow2
    $ source ~/devstack/openrc admin admin
    $ glance image-create --name fedora-atomic-latest \
                        --visibility public \
                        --disk-format qcow2 \
                        --os-distro fedora-atomic \
                        --container-format bare < fedora-atomic-f23-dib.qcow2

#### Add default keypair to demo user

    $ ssh-keygen
    $ source ~/devstack/openrc demo demo
    $ nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#### Database

    $ mysql -h 192.168.11.197 -u root -pstackdb mysql <<EOF
    CREATE DATABASE IF NOT EXISTS magnum DEFAULT CHARACTER SET utf8;
    GRANT ALL PRIVILEGES ON magnum.* TO
        'root'@'%' IDENTIFIED BY 'stackdb'
    EOF

and create tables.

    $ cd ~/magnum
    $ source .tox/venv/bin/activate
    $ pip install mysql-python
    $ magnum-db-manage upgrade

### Start Magnum

#### magnum-api

    $ cd ~/magnum
    $ source .tox/venv/bin/activate
    $ magnum-api

#### magnum-conductor

    $ cd ~/magnum
    $ source .tox/venv/bin/activate
    $ magnum-conductor

#### python-magnumclient

    $ cd ~/python-magnumclient
    $ source .tox/venv/bin/activate
    $ magnum bay-list

## Test magnum

### Try to create bay

    $ magnum baymodel-create --name kubernetes --keypair-id default \
                             --external-network-id public \
                             --image-id fedora-atomic-latest \
                             --flavor-id m1.small \
                             --docker-volume-size 5 \
                             --network-driver flannel \
                             --coe kubernetes

    $ magnum bay-create --name k8s_bay --baymodel kubernetes

    $ magnum baymodel-create --name swarm \
                             --image-id fedora-atomic-latest \
                             --keypair-id default \
                             --external-network-id public \
                             --flavor-id m1.small \
                             --docker-volume-size 5 \
                             --coe swarm

### Try to create pod

    $ magnum pod-create --bay-id 99cab72f-16a7-4564-8d73-d4497f51f557 \
        --pod-file redis-master.json


## After reload

    $ sudo ip addr add 10.0.0.1/24 dev br-ex
    $ sudo ip addr add 172.16.12.1/24 dev br-ex
    $ sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    $ sudo losetup /dev/loop0 /opt/stack/data/stack-volumes-default-backing-file ;
    $ sudo losetup /dev/loop1 /opt/stack/data/stack-volumes-lvmdriver-1-backing-file ;
