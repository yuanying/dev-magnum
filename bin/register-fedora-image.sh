#!/bin/bash
source ~/devstack/openrc admin admin

IMAGE_NAME=fedora-atomic-latest.qcow2
IMAGE_PATH=~/${IMAGE_NAME}

if [ ! -f "$IMAGE_PATH" ]; then
  echo "Download Image: ${IMAGE_NAME}"
  curl https://fedorapeople.org/groups/magnum/${IMAGE_NAME} \
       -o ${IMAGE_PATH}
fi

glance image-create --name fedora-atomic-latest \
                    --visibility public \
                    --disk-format qcow2 \
                    --os-distro fedora-atomic \
                    --container-format bare < ${IMAGE_PATH}
