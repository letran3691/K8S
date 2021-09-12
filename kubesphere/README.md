# install helm
    https://helm.sh/docs/intro/install/

edit coredns

    kubectl -n kube-system edit configmap/coredns

    data:
      Corefile: |
        .:53 {
            errors
            health {
                lameduck 5s
            }
            ready
            hosts {
               192.168.1.65 node1
               192.168.1.67 node2
               192.168.1.24 node3
               192.168.1.226 node4
               fallthrough
            }
            kubernetes cluster.local in-addr.arpa ip6.arpa {
                pods insecure
                fallthrough in-addr.arpa ip6.arpa
                ttl 30
            }
            prometheus :9153
            forward . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
         } 


# Config manager storage 


default k8s can't provider NFS server. We're need install NFS provider
add repo provider NFS server

    helm repo add stable https://charts.kubesphere.io/main
    helm repo update

# deploy nfs-client-provisioner

## static NFS provisioner
    helm install nfs stable/nfs-client-provisioner --set nfs.server=192.168.1.30 --set nfs.path=/lv-data/elk/ --set storageClass.name=nfs-client,storageClass.reclaimPolicy=Retain

## Dynamic NFS provisioner
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
    helm repo update
    helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
        --set nfs.server=192.168.1.30 \
        --set nfs.path=/data/NFS

before start we're check storage default existed with command

    kubectl get storageclass

otherwise need storageclass and set default

set default storageclass

    kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    
    kubectl get storageclass


deploy KubeSphere console

    kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.0/kubesphere-installer.yaml
       
    kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.0/cluster-configuration.yaml
    
    kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

# deploy dashboard k8s

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml

expose port

    kubectl -n kubernetes-dashboard edit service kubernetes-dashboard

change type: ClusterIP to type: NodePort

get token login dashboard

    kubectl -n kube-system describe $(kubectl -n kube-system get secret -n kube-system -o name | grep namespace) | grep token:



# install metallb
    https://metallb.universe.tf/installation/


deploy EFK




