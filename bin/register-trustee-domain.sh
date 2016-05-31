#!/bin/bash
IDENTITY_API_VERSION=3
source ~/devstack/openrc admin admin

TRUSTEE_DOMAIN_ID=$(
    openstack domain create magnum \
        --description "Owns users and projects created by magnum" \
        -f value -c id
)
TRUSTEE_DOMAIN_ADMIN_ID=$(
    openstack user create trustee_domain_admin \
        --password "password" \
        --domain=${TRUSTEE_DOMAIN_ID} \
        --or-show \
        -f value -c id
)
openstack --os-identity-api-version 3 role add \
          --user $TRUSTEE_DOMAIN_ADMIN_ID --domain $TRUSTEE_DOMAIN_ID \
          admin

echo "TRUSTEE_DOMAIN_NAME: magnum"
echo "TRUSTEE_DOMAIN_ID: ${TRUSTEE_DOMAIN_ID}"
echo "TRUSTEE_DOMAIN_ADMIN_NAME: trustee_domain_admin"
echo "TRUSTEE_DOMAIN_ADMIN_ID: ${TRUSTEE_DOMAIN_ADMIN_ID}"
