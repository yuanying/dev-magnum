Develop Magnum with Devstack
============================

## Vagrant

I'm using vagrant (parallels on Mac) to boot a devstack.
Vagrantfile is below.

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

    $ cd /vagrant
    $ git clone https://git.openstack.org/openstack-dev/devstack
    $ ./stack.sh

localrc is below.


    FLOATING_RANGE=192.168.19.0/24
    Q_FLOATING_ALLOCATION_POOL="start=192.168.19.80,end=192.168.19.100"
    PUBLIC_NETWORK_GATEWAY=192.168.19.1

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

    enable_service barbican-svc
    enable_service barbican-retry

    LOGFILE=$DEST/logs/devstack.log
    DEST=/opt/stack
    SCREEN_LOGDIR=$DEST/logs/screen

## Magnum

### Install

#### Magnum Server

    $ cd /vagrant
    $ git clone https://github.com/stackforge/magnum.git
    $ cd magnum
    $ tox -evenv -- echo 'done'

#### Magnum Client

    $ cd /vagrant
    $ git clone https://github.com/stackforge/python-magnumclient.git
    $ cd python-magnumclient
    $ tox -evenv -- echo 'done'

### Configuration

    $ sudo mkdir -p /etc/magnum
    $ cd /etc/magnum
    $ sudo vim magnum.conf

magnum.conf has below content.

    [DEFAULT]
    debug = True
    verbose = True

    rabbit_userid=stackrabbit
    rabbit_password = stackqueue
    rabbit_hosts = 127.0.0.1
    rpc_backend = rabbit

    [database]
    connection = mysql://root:stackdb@localhost/magnum

    [keystone_authtoken]
    admin_password = openstack
    admin_user = nova
    admin_tenant_name = service
    identity_uri = http://127.0.0.1:35357

    auth_uri=http://127.0.0.1:5000/v2.0
    auth_protocol = http
    auth_port = 35357
    auth_host = 127.0.0.1

#### register magnum service to keystone

    $ source /vagrant/devstack/openrc admin admin
    $ keystone service-create --name=magnum \
                            --type=container \
                            --description="Magnum Container Service"
    $ keystone endpoint-create --service=magnum \
                             --publicurl=http://127.0.0.1:9511/v1 \
                             --internalurl=http://127.0.0.1:9511/v1 \
                             --adminurl=http://127.0.0.1:9511/v1 \
                             --region RegionOne

#### Register Image to glance

    $ cd /vagrant
    $ curl -O https://fedorapeople.org/groups/heat/kolla/fedora-21-atomic-3.qcow2
    $ source /vagrant/devstack/openrc admin admin
    $ glance image-create \
        --disk-format qcow2 \
        --container-format bare \
        --is-public True \
        --name fedora-21-atomic-3 \
        --property os-distro='fedora-atomic' \
        --file /vagrant/fedora-21-atomic-3.qcow2

#### Add default keypair to demo user

    $ ssh-keygen
    $ source /vagrant/devstack/openrc demo demo
    $ nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#### Database

    $ mysql -h 127.0.0.1 -u root -pstackdb mysql <<EOF
    CREATE DATABASE IF NOT EXISTS magnum DEFAULT CHARACTER SET utf8;
    GRANT ALL PRIVILEGES ON magnum.* TO
        'root'@'%' IDENTIFIED BY 'stackdb'
    EOF

and create tables.

    $ cd /vagrant/magnum
    $ source .tox/venv/bin/activate
    $ pip install mysql-python
    $ magnum-db-manage upgrade

### Start Magnum

#### magnum-api

    $ cd /vagrant/magnum
    $ source .tox/venv/bin/activate
    $ magnum-api

#### magnum-conductor

    $ cd /vagrant/magnum
    $ source .tox/venv/bin/activate
    $ magnum-conductor

#### python-magnumclient

    $ cd /vagrant/python-magnumclient
    $ source .tox/venv/bin/activate
    $ magnum bay-list

## Test magnum

### Try to create bay

    $ magnum baymodel-create --name kubernetes --keypair-id default \
      --external-network public \
      --image-id fedora-21-atomic-3 \
      --flavor-id m1.small --docker-volume-size 1 \
      --coe kubernetes

    $ magnum bay-create --name k8s_bay --baymodel kubernetes

### Try to create pod

    $ magnum pod-create --bay-id 99cab72f-16a7-4564-8d73-d4497f51f557 \
        --pod-file redis-master.json


## After reload

    $ sudo ip addr add 192.168.19.1/24 dev br-ex
    $ sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    $ sudo losetup /dev/loop0 /opt/stack/data/stack-volumes-default-backing-file ;
    $ sudo losetup /dev/loop1 /opt/stack/data/stack-volumes-lvmdriver-1-backing-file ;
