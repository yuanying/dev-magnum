#!/bin/bash
source ~/devstack/openrc admin admin

KERNEL_NAME=fedora-23-kubernetes-ironic.vmlinuz
RAMDISK_NAME=fedora-23-kubernetes-ironic.initrd
IMAGE_NAME=fedora-23-kubernetes-ironic.qcow2

if [ ! -f "~/${KERNEL_NAME}" ]; then
  echo "Download Image: ${KERNEL_NAME}"
  curl https://fedorapeople.org/groups/magnum/${KERNEL_NAME} \
       -o ~/${KERNEL_NAME}
fi

if [ ! -f "~/${RAMDISK_NAME}" ]; then
  echo "Download Image: ${RAMDISK_NAME}"
  curl https://fedorapeople.org/groups/magnum/${RAMDISK_NAME} \
       -o ~/${RAMDISK_NAME}
fi

if [ ! -f "~/${IMAGE_NAME}" ]; then
  echo "Download Image: ${IMAGE_NAME}"
  curl https://fedorapeople.org/groups/magnum/${IMAGE_NAME} \
       -o ~/${IMAGE_NAME}
fi

KERNEL_ID=`glance image-create --name fedora-k8s-kernel \
                               --visibility public \
                               --disk-format=aki \
                               --container-format=aki \
                               --file=~/${KERNEL_NAME} \
                               | grep id | tr -d '| ' | cut --bytes=3-57`
RAMDISK_ID=`glance image-create --name fedora-k8s-ramdisk \
                               --visibility public \
                               --disk-format=ari \
                               --container-format=ari \
                               --file=~/${RAMDISK_NAME} \
                               | grep id |  tr -d '| ' | cut --bytes=3-57`

BASE_ID=`glance image-create --name fedora-k8s \
                               --os-distro fedora \
                               --visibility public \
                               --disk-format=qcow2 \
                               --container-format=bare \
                               --property kernel_id=$KERNEL_ID \
                               --property ramdisk_id=$RAMDISK_ID \
                               --file=${IMAGE_NAME} \
                               | grep -v kernel | grep -v ramdisk \
                               | grep id | tr -d '| ' | cut --bytes=3-57`
