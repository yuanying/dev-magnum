# Develop Magnum with Devstack

## Devstack

I'm using vagrant (parallels on Mac) to boot a devstack.
In this time, [heat-template](https://github.com/larsks/heat-kubernetes) only supports Juno version of OpenStack.
Latest version is not worked.

    $ sudo apt-get update && sudo apt-get install -y vim git libmysqlclient-dev
    $ cd /vagrant
    $ git clone https://git.openstack.org/openstack-dev/devstack
    $ cd devstack
    $ git checkout -b stable/juno origin/stable/juno
    $ ./stack.sh

localrc is below.

    NETWORK_GATEWAY=10.11.12.1
    FIXED_RANGE=10.11.12.0/24
    FIXED_NETWORK_SIZE=256

    PUBLIC_NETWORK_GATEWAY=192.168.34.225
    FLOATING_RANGE=192.168.34.224/27
    FLAT_INTERFACE=eth1

    ADMIN_PASSWORD=openstack
    MYSQL_PASSWORD=stackdb
    RABBIT_PASSWORD=stackqueue
    SERVICE_PASSWORD=$ADMIN_PASSWORD
    HOST_IP=192.168.34.56
    SERVICE_TOKEN=tokentoken

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service neutron

    NOVA_BRANCH=stable/juno
    GLANCE_BRANCH=stable/juno
    KEYSTONE_BRANCH=stable/juno
    HORIZON_BRANCH=stable/juno
    CINDER_BRANCH=stable/juno
    NEUTRON_BRANCH=stable/juno
    CEILOMETER_BRANCH=stable/juno
    HEAT_BRANCH=stable/juno

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

    $ sudo mkdir -p /etc/magnum/templates
    $ cd /etc/magnum/templates
    $ sudo git clone https://github.com/larsks/heat-kubernetes.git
    $ cd /etc/magnum
    $ vim magnum.conf

magnum.conf has below content.

    [DEFAULT]
    debug = True
    verbose = True

    rabbit_password = stackqueue
    rabbit_hosts = 192.168.34.56
    rpc_backend = rabbit

    [database]
    connection = mysql://root:stackdb@localhost/magnum

    [keystone_authtoken]
    admin_password = openstack
    admin_user = nova
    admin_tenant_name = service
    identity_uri = http://192.168.34.56:35357

    auth_uri=http://192.168.34.56:5000/v2.0
    auth_protocol = http
    auth_port = 35357
    auth_host = 192.168.34.56

#### register magnum service to keystone

    $ source /vagrant/devstack/openrc admin admin
    $ keystone service-create --name=magnum \
                            --type=container \
                            --description="Magnum Container Service"
    $ keystone endpoint-create --service=container \
                             --publicurl=http://127.0.0.1:9511/v1 \
                             --internalurl=http://127.0.0.1:9511/v1 \
                             --adminurl=http://127.0.0.1:9511/v1

#### Add default keypair

    $ ssh-keygen
    $ source /vagrant/devstack/openrc demo demo
    $ nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#### Register Image to glance

    $ cd /vagrant
    $ curl -O https://fedorapeople.org/groups/heat/kolla/fedora-21-atomic.qcow2
    $ source /vagrant/devstack/openrc admin admin
    $ glance image-create \
        --disk-format qcow2 \
        --container-format bare \
        --is-public True \
        --name fedora-21-atomic \
        --file /vagrant/fedora-21-atomic.qcow2

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

try to create bay.

    $ magnum baymodel-create --name default --keypair_id default \
      --external_network_id ef5e00ba-dd2a-49db-b6c2-8c3aceb83829 \
      --image_id fedora-21-atomic \
      --flavor_id m1.small

    $ magnum bay-create --name kube --baymodel_id ae8fd2a5-6076-4b36-a545-61c15ee43677