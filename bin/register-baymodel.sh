#!/bin/bash
source ~/devstack/openrc demo demo

magnum baymodel-create --name kubernetes --keypair-id default \
                       --external-network-id public \
                       --image-id fedora-atomic-latest \
                       --flavor-id m1.small \
                       --docker-volume-size 5 \
                       --network-driver flannel \
                       --coe kubernetes

magnum baymodel-create --name swarm \
                       --image-id fedora-atomic-latest \
                       --keypair-id default \
                       --external-network-id public \
                       --flavor-id m1.small \
                       --docker-volume-size 5 \
                       --coe swarm
