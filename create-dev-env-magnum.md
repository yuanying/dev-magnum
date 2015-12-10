Develop Magnum with Devstack
============================

## Vagrant

I'm using vagrant (parallels on Mac) to boot a devstack.
Vagrantfile is below. Devstack IP Address is 192.168.11.197.

    Vagrant.configure('2') do |config|
      config.vm.box = "trusty64"

      config.vm.define :devstack do |devstack|
        devstack.vm.hostname = "devstack"
        devstack.vm.network :private_network, ip: "192.168.123.10"
        devstack.vm.network :public_network, dev: 'br0', mode: 'bridge', ip: "192.168.11.197"

        devstack.vm.synced_folder ".", "/vagrant", type: "nfs"
        #devstack.vm.synced_folder "/home/yuanying/Projects", "/home/yuanying/Projects", type: "nfs"

        devstack.vm.provider :libvirt do |libvirt, override|
          libvirt.memory = 8192
          libvirt.nested = true
        end

        devstack.vm.provision "shell", path: "./install.sh"
      end

    end


and vagrant up.

## Inside Devstack VM

### Install requirement packages

    $ sudo apt-get update
    $ sudo apt-get install libffi-dev libssl-dev git vim \
                           libxml2-dev libsqlite3-dev libxslt1-dev -y

### Network settings

    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

### Install DevStack

    $ cd ~
    $ git clone https://git.openstack.org/openstack-dev/devstack
    $ cd devstack
    $ ./stack.sh
    $ sudo mkdir /etc/neutron
    $ chown -R $USER /etc/neutron
    $ echo "dhcp-option-force=26,1400" >> /etc/neutron/dnsmasq.conf

local.conf is below.

    [[local|localrc]]
    HOST_IP=192.168.11.197
    #SERVICE_HOST=192.168.202.4
    #HEAT_API_HOST=${SERVICE_HOST}
    #HEAT_API_CFN_HOST=${SERVICE_HOST}
    #HEAT_ENGINE_HOST=${SERVICE_HOST}
    #HEAT_API_CW_HOST=${SERVICE_HOST}

    FLOATING_RANGE=172.16.12.0/24
    Q_FLOATING_ALLOCATION_POOL="start=172.16.12.10,end=172.16.12.200"
    PUBLIC_NETWORK_GATEWAY=172.16.12.1

    Q_USE_SECGROUP=True
    ENABLE_TENANT_VLANS=True
    TENANT_VLAN_RANGE=1000:1999
    PHYSICAL_NETWORK=default
    OVS_PHYSICAL_BRIDGE=br-ex

    NETWORK_GATEWAY=10.11.12.1
    FIXED_RANGE=10.11.12.0/24
    FIXED_NETWORK_SIZE=256

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

    #LOGFILE=$DEST/logs/devstack.log
    DEST=/opt/stack
    #SCREEN_LOGDIR=$DEST/logs/screen

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


#### register magnum service to keystone

    $ source ~/devstack/openrc admin admin
    $ openstack service create --name=magnum \
                               --description="Magnum Container Service" \
                               container
    $ openstack endpoint create --region=RegionOne \
                                --publicurl=http://192.168.11.132:9511/v1 \
                                --internalurl=http://192.168.11.132:9511/v1 \
                                --adminurl=http://192.168.11.132:9511/v1 \
                                magnum

#### Register Image to glance

    $ curl -O https://fedorapeople.org/groups/magnum/fedora-21-atomic-5.qcow2
    $ source ~/devstack/openrc admin admin
    $ glance image-create --name fedora-21-atomic-5 \
                        --visibility public \
                        --disk-format qcow2 \
                        --os-distro fedora-atomic \
                        --container-format bare < fedora-21-atomic-5.qcow2

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
                             --image-id fedora-21-atomic-5 \
                             --flavor-id m1.small \
                             --docker-volume-size 1 \
                             --network-driver flannel
                             --coe kubernetes

    $ magnum bay-create --name k8s_bay --baymodel kubernetes

    $ magnum baymodel-create --name swarm \
                             --image-id fedora-21-atomic-5 \
                             --keypair-id default \
                             --external-network-id public \
                             --flavor-id m1.small \
                             --docker-volume-size 1 \
                             --coe swarm

### Try to create pod

    $ magnum pod-create --bay-id 99cab72f-16a7-4564-8d73-d4497f51f557 \
        --pod-file redis-master.json


## After reload

    $ sudo ip addr add 172.16.12.1/24 dev br-ex
    $ sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    $ sudo losetup /dev/loop0 /opt/stack/data/stack-volumes-default-backing-file ;
    $ sudo losetup /dev/loop1 /opt/stack/data/stack-volumes-lvmdriver-1-backing-file ;
