#!/bin/bash
source ~/devstack/openrc admin admin
curl -O http://tarballs.openstack.org/magnum/images/fedora-atomic-f23-dib.qcow2
glance image-create --name fedora-21-atomic-latest \
                    --visibility public \
                    --disk-format qcow2 \
                    --os-distro fedora-atomic \
                    --container-format bare < fedora-atomic-f23-dib.qcow2
