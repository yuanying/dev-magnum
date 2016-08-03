#!/bin/bash
source ~/devstack/openrc demo demo

magnum baymodel-create --name kubernetes --keypair-id default \
                       --server-type bm \
                       --external-network-id public \
                       --fixed-subnet private-subnet \
                       --image-id fedora-k8s \
                       --flavor-id baremetal \
                       --network-driver flannel \
                       --coe kubernetes

magnum baymodel-create --name swarm --keypair-id default \
                      --server-type bm \
                      --external-network-id public \
                      --fixed-subnet private-subnet \
                      --image-id fedora-k8s \
                      --flavor-id baremetal \
                      --network-driver flannel \
                      --coe swarm
