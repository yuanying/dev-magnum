#!/bin/bash
IDENTITY_API_VERSION=3
source ~/devstack/openrc admin admin
openstack service create --name=magnum \
                         --description="Magnum Container Service" \
                         container-infra
openstack endpoint create --region=RegionOne \
                          container-infra public http://192.168.11.132:9511/v1
openstack endpoint create --region=RegionOne \
                          container-infra internal http://192.168.11.132:9511/v1
openstack endpoint create --region=RegionOne \
                          container-infra admin http://192.168.11.132:9511/v1
