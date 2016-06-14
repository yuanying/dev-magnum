#!/bin/bash
source ~/devstack/openrc demo demo

magnum baymodel-create --name kubernetes --keypair-id default \
                       --server-type bm \
                       --external-network-id public \
                       --fixed-network private \
                       --image-id fedora-k8s \
                       --flavor-id baremetal \
                       --network-driver flannel \
                       --coe kubernetes
