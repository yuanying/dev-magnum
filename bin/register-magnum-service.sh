#!/bin/bash
source ~/devstack/openrc admin admin
openstack service create --name=magnum \
                         --description="Magnum Container Service" \
                         container
openstack endpoint create --region=RegionOne \
                          container public http://192.168.11.132:9511/v1
openstack endpoint create --region=RegionOne \
                          container internal http://192.168.11.132:9511/v1
openstack endpoint create --region=RegionOne \
                          container admin http://192.168.11.132:9511/v1
