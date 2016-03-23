# Demo command list

    nova list
    neutron net-list

    magnum baymodel-list

    nova keypair-list

    ssh-keygen

    nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

    magnum baymodel-create \
      --name kubernetes \
      --keypair-id default \
      --external-network-id public \
      --image-id fedora-21-atomic-5 \
      --flavor-id m1.small \
      --docker-volume-size 1 \
      --network-driver flannel \
      --coe kubernetes

    magnum bay-create --name k8sbay --baymodel kubernetes

    heat stack-list

    nova list

    heat resource-list k8sbay-ap76ggow3rpc

    https://github.com/openstack/magnum/blob/master/doc/source/dev/dev-tls.rst

    openssl genrsa -out client.key 4096

    cat > client.conf << END
    [req]
    distinguished_name = req_distinguished_name
    req_extensions     = req_ext
    prompt = no
    [req_distinguished_name]
    CN = yuanying@fraction.jp
    [req_ext]
    extendedKeyUsage = clientAuth
    END

    openssl req -new -days 365 \
        -config client.conf \
        -key client.key \
        -out client.csr

    openssl req -text -in client.csr

    magnum ca-sign --bay k8sbay --csr client.csr > client.crt

    openssl x509 -text -in client.crt

    magnum ca-show --bay k8sbay > ca.crt


    KUBERNETES_URL=$(magnum bay-show k8sbay |
                     awk '/ api_address /{print $4}')

    kubectl version --certificate-authority=ca.crt \
                   --client-key=client.key \
                   --client-certificate=client.crt -s $KUBERNETES_URL

    kubectl config set-cluster secure-k8sbay --server=${KUBERNETES_URL} \
       --certificate-authority=${PWD}/ca.crt
    kubectl config set-credentials client --certificate-authority=${PWD}/ca.crt \
       --client-key=${PWD}/client.key --client-certificate=${PWD}/client.crt
    kubectl config set-context secure-k8sbay --cluster=secure-k8sbay --user=client
    kubectl config use-context secure-k8sbay


    cat > nginx.yml << END
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx

    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
          - containerPort: 80
    END

    cat > nginx-service.yml << END
    apiVersion: v1
    kind: Service
    metadata:
      name: nginx-service
    spec:
      ports:
        - port: 80
      selector:
        app: nginx
    END

    kubectl create -f nginx.yml
