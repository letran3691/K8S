#### create ClusterRoleBinding file

    vi example-cluster-admin.yaml
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: example-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: example:masters

```
    kubectl apply -f example-cluster-admin.yaml

    openssl genrsa -out trunglv.key 2048

    openssl req -new -key trunglv.key -out trunglv.csr -subj "/CN=${USERNAME}/O=example:masters"

    cat trunglv.csr | base64 | tr -d '\n'

#### create CertificateSigningRequest file

    vi  CertificateSigningRequest.yaml
```
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: test-csr
spec:
  groups:
  - system:authenticated
  request: BASE64ENCODEDCSR FROMS TEP3
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
```
    kubectl apply -f CertificateSigningRequest.yaml
    
    kubectl certificate approve trunglv-csr
  
    KEY=`cat trunglv.key | base64 | tr -d '\n'`
    CERT=`kubectl get csr trunglv-csr -o jsonpath='{.status.certificate}'`
    
    echo "======KEY"
    echo ${KEY}
    echo
    
    echo "======Cert"
    echo $CERT
    echo

```
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
```