#!/bin/bash

echo "Enter Username: "
read username

echo "Enter Namespace wanna grant:"
read namespace

echo "Gen key..."

useradd -s /bin/bash -m $username
cd /home/$username && openssl genrsa -out "$username".key 2048
cd /home/$username && openssl req -new -key "$username".key -out "$username".csr -subj "/CN=$username"

sleep 3

echo  "Ally cert and Approve cert..."

csr=$(cat $username.csr | base64 | tr -d "\n")


cat >> $username-csr.yaml << END
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $username-csr
spec:
  groups:
  - system:authenticated
  request: $csr
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
END

kubectl apply -f "$username"-csr.yaml

kubectl certificate approve "$username"-csr

sleep 3

cluster_name=$(kubectl config get-contexts | awk '{print $3}' | tail -n 1)
cert=$(kubectl config view --raw --flatten -o json | jq -r '.clusters[0].cluster."certificate-authority-data"')
server=$(kubectl config view --raw --flatten -o json | jq -r '.clusters[0].cluster.server')

client_cert=$(kubectl get csr $username-csr -o jsonpath='{.status.certificate}')

key=$(cat $username.key | base64 | tr -d '\n')

echo  "create config file..."

cat >> "$username".conf << END
apiVersion: v1
kind: Config
clusters:
- name: $cluster_name
  cluster:
    certificate-authority-data: $cert
    server: $server
contexts:
- name: $username-$namespace
  context:
    cluster: $cluster_name
    namespace: $namespace
    user: $username
current-context: $username-$namespace
users:
- name: $username
  user:
    client-certificate-data: $client_cert
    client-key-data: $key
END

mkdir /home/$username/.kube/
cp -p /home/$username/$username.conf /home/$username/.kube/config
chmod 600 /home/$username/.kube/config
chown -R $username:$username /home/$username

echo "create role..."

cat >> "$username"-role.yaml << END

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $namespace
  name: full-access-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

END

kubectl apply -f "$username"-role.yaml

sleep 3

echo "Bind Role..."

cat >> "$username"_RoleBinding.yaml << END
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: full-access-binding
  namespace: $namespace
subjects:
- kind: User
  name: $username
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: full-access-role
  apiGroup: rbac.authorization.k8s.io

END
kubectl apply -f "$username"_RoleBinding.yaml

echo "Done!!!"