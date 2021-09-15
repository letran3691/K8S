OS: Centos 7.

K8S: v1.22.

DOCKER-CE: v20.10.6.

kube-flannel: v0.14 hoặc cao hơn.

kubeadm init: lỗi "waiting for the kubelet to perform the tls bootstrap... kubelet-check initial timeout of 40s passed"


    cat > /etc/docker/daemon.json <<EOF
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m"
      },
      "storage-driver": "overlay2",
      "storage-opts": [
        "overlay2.override_kernel_check=true"
      ]
    }
    EOF
    
    mkdir -p /etc/systemd/system/docker.service.d

    systemctl daemon-reload
    systemctl restart docker
 
lỗi failed to parse kernel config: unable to load kernel module: "configs",

    [root@node4 ~]# ls /boot/config*
    /boot/config-3.10.0-1160.42.2.el7.x86_64
    [root@node4 ~]# uname -r
    3.10.0-693.2.2.el7.x86_64
    [root@node4 ~]# cd /boot
    [root@node4 boot]# mv config-3.10.0-1160.42.2.el7.x86_64 config-3.10.0-693.2.2.el7.x86_64



**Yêu cầu phần cứng**

- Máy thật tối thiểu 24G RAM

- Các NODE trong cụm cluster (máy ảo vmware)

   - Cấu hình tối thiểu mỗi node
   
   - Gồm 4 node mỗi node 2core, 4-6G RAM
   
   - 1 node NFS server


## MENU

### [I: Cài đặt  helm](#I)

### [II: Sửa coredns](#II)

### [III: Cài đặt storageclass](#III)

### [IV: Dashboard k8s](#IV)

### [V: Cài đặt KubeSphere](#V)

### [VI: Cài đặt metallb](#VI)

### [VII: Cài đặt Cài đặt EFK](#VII)

### [VIII: Cài đặt Cài đặt ELK](#VIII)



------------------

## <a name="I"><a/>**I: Cài đặt Helm**

    https://helm.sh/docs/intro/install/
    
    curl -LO https://get.helm.sh/helm-v3.7.0-rc.3-linux-amd64.tar.gz
    tar -xvf helm-v3.7.0-rc.3-linux-amd64.tar.gz && cp linux-amd64/helm /usr/local/bin/

## <a name="II"><a/>**II: Sửa coredns**

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



## <a name="III"><a/>**III: cài đặt storageclass**

### Cài đặt NFS server 

        yum -y install nfs-utils
        
        vi /etc/idmapd.conf
    
    tìm đến dòng 5 và sửa
        
        Domain = 192.168.1.30 #ip local của NFS server
        
        mkdir -p /data/NFS && chown -R nfsnobody. /data/NFS
        
        echo "/data/NFS  *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports 
        
        systemctl enable rpcbind nfs-server && systemctl start rpcbind nfs-server
        
Có thể tìm hiểu <a href="https://www.server-world.info/en/note?os=CentOS_7&p=nfs&f=1" rel="nofollow">tại đây<a>.

### Cài đặt NFS client trên các node cluster 
        
        yum -y install nfs-utils
        
        vi /etc/idmapd.conf
    tìm đến dòng 5 và sửa   
    
        Domain = 192.168.1.30 #ip local của NFS server
        
        systemctl start rpcbind && systemctl enable rpcbind
        
tham khảo <a href="https://www.server-world.info/en/note?os=CentOS_7&p=nfs&f=2" rel="nofollow">tại đây<a>.

 _- các bạn nên mount thử sau khi cấu hình NFS cho chắc._

### Cài đặt NFS provider
 
default k8s can't provider NFS server. We're need install NFS provider
add repo provider NFS

    helm repo add stable https://charts.kubesphere.io/main
    helm repo update


### Static NFS provisioner

   Trong K8s không có khái niệm nào là static NFS provisioner tuy nhiên mình gọi vậy cho đơn giản. Các bạn cứ hiểu đơng giản là với static NFS provisioner này thì các PV và PVC các bạn sẽ phải tạo thủ công

    helm install nfs stable/nfs-client-provisioner --set nfs.server=192.168.1.x --set nfs.path=/data/NFS/ --set storageClass.name=nfs-client,storageClass.reclaimPolicy=Retain

### Dynamic NFS provisioner

   Dynamic NFS provisioner sẽ giúp tự động tạo ra các PV và PVC
    
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
    helm repo update
    helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
        --set nfs.server=192.168.1.30 \
        --set nfs.path=/data/NFS

Kiểm tra storage default đã tồn tại hay chưa

    kubectl get storageclass

Nếu chưa có thì set default storageclass bằng lệnh dưới

    kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

Kiểm tra lại

    kubectl get storageclass
    

## <a name="IV"><a/>**IV: Dashboard k8s**

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml

Expose port

    kubectl -n kubernetes-dashboard edit service kubernetes-dashboard
    
Tìm đến dòng 34 và sửa lại 

    type:  ClusterIP thành type: NodePort

Get token login dashboard

    kubectl -n kube-system describe $(kubectl -n kube-system get secret -n kube-system -o name | grep namespace) | grep token:
    

## <a name="V"><a/>**V: Cài đặt KubeSphere**


Các bạn cứ hiểu đơn giản KubeSphere giống như dashboard của K8S vậy, nhưng nó được tích hợp và hỗ trợ nhiều thứ hơn.

![0_7R0fY_FNk4BN8uKf](https://user-images.githubusercontent.com/19284401/133020207-b231b875-6969-4f7b-a7fd-039769032030.png)

    kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.0/kubesphere-installer.yaml
       
    kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.1.0/cluster-configuration.yaml
    
    kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f

## <a name="VI"><a/>**VI: Cài đặt metallb**

    - **Chú ý thay đúng dải IP**    

    helm repo add metallb https://metallb.github.io/metallb
    helm repo update
    
    cat > "meta_values.yaml" << END
    configInline:
      address-pools:
       - name: default
         protocol: layer2
         addresses:
         - 192.168.1.200-192.168.1.240

    END

    helm install metallb metallb/metallb -f meta_values.yaml
        
    
Test thử metallb

    kubectl create deploy nginx --image=nginx
    kubectl expose deploy nginx --port 80 --type LoadBalancer 
    
Ktra nhận ip LoadBalancer cấp phát

    kubectl get pod,deploy,svc -o wide

![image](https://user-images.githubusercontent.com/19284401/133022064-65251afd-a78b-41a0-8fc6-3a3d72ac51ff.png)

truy cập thử vào ip LoadBalancer xem có được không. nếu mọi thứ ổn thì sẽ trả về trang nginx

![image](https://user-images.githubusercontent.com/19284401/133022223-3b0900a0-8059-4c3d-b3b6-ae90bd29cb3a.png)


## <a name="VII"><a/>**VII: Cài đặt Cài đặt EFK**    

    - Cần deploy metallb trước khi deploy EFK

### Elastic

    helm repo add elastic https://helm.elastic.co
    helm repo update
    
    mkdir EFK && cd EFK
    
    cat > "esvalues.yaml" << END
    ---
    protocol: http
    httpPort: 9200
    transportPort: 9300
    service:
      labels: {}
      labelsHeadless: {}
      type: LoadBalancer
      nodePort: ""
      annotations: {}
      httpPortName: http
      transportPortName: transport
      loadBalancerIP: ""
      loadBalancerSourceRanges: []
      externalTrafficPolicy: ""
    END
    
    
    helm pull --version 7.13.0 elastic/elasticsearch && tar -xvf elasticsearch-7.13.0.tgz
    
    vi elasticsearch/values.yaml
    
 tìm đến dòng 103 sửa 30Gi thành 4Gi
    
![image](https://user-images.githubusercontent.com/19284401/133023317-0240a5e0-2a76-4dd9-97ec-0d61c7a19486.png)

    helm install elasticsearch elasticsearch -f esvalues.yaml
    

ktra lại

    kubectl get pod,deploy,svc,pv,pvc -o wide
    
![image](https://user-images.githubusercontent.com/19284401/133023753-20c3d490-434a-4476-87d9-f80afa76e43d.png)

truy cập thử vào IP LoadBalancer

![image](https://user-images.githubusercontent.com/19284401/133024584-54cae358-f25f-4ae6-bef8-72b43265b7f7.png)

### Fluent

    curl -LO https://raw.githubusercontent.com/letran3691/K8S/main/kubesphere/fluentd-ds-rbac.yaml
    
    vim fluentd-ds-rbac.yaml
    
   tìm đến dòng 66 sửa thành ip LoadBalancer của elasticsearch

    kubectl create -f fluentd-ds-rbac.yaml
    
Ktra lại
    
    kubectl -n kube-system get all -l=k8s-app=fluentd-logging -o wide
    
![image](https://user-images.githubusercontent.com/19284401/133024271-6fec962f-364e-45ec-809b-083ee9c2c53e.png)

##### Kibana

    curl -LO https://raw.githubusercontent.com/letran3691/K8S/main/kubesphere/kivalues.yaml
    
    vi kivalues.yaml
    
Dòng 2 thay địa chỉ IP LoadBalancer của elasticsearch

Dòng 9 và dòng 12 sửa thành 500m

![image](https://user-images.githubusercontent.com/19284401/133026790-07c72efe-a5f6-481d-b9fa-17dbb57da668.png)


    helm install kibana --version 7.13.0 elastic/kibana -f kivalues.yaml
    
    kubectl get pod,deploy,svc,pv,pvc -o wide
    
![image](https://user-images.githubusercontent.com/19284401/133027106-7a1b613d-a0fd-406c-b6dc-383135ee4e1b.png)
    

### Test

    kubectl apply -f https://github.com/letran3691/K8S/releases/download/hellopod/test.yaml
    
    
![1](https://user-images.githubusercontent.com/19284401/133058054-8f7b8f33-a534-4ca6-b2fb-70eee917ba3a.gif)

![2_1](https://user-images.githubusercontent.com/19284401/133058135-1b194fd5-68e9-4a96-a5a7-007e00b1979b.gif)

![3_1](https://user-images.githubusercontent.com/19284401/133058196-f1e311cc-198f-4061-80ec-3bea9b76f207.gif)

## <a name="VIII"><a/>**VIII: Cài đặt ELK**  

    - Cần deploy metallb trước khi deploy ELK

### Elastic

    helm repo add elastic https://helm.elastic.co
    helm repo update

    mkdir ELK && cd ELK

    helm pull --version 7.8.0 elastic/elasticsearch && tar -xvf elasticsearch-7.8.0.tgz

    vi elasticsearch/values.yaml
  Tìm đến dòng 95 sửa 30Gi thành 3Gi  

![image](https://user-images.githubusercontent.com/19284401/133391383-83b73d38-6cc7-4e1c-9d4c-cec8106fd7af.png)

    helm install elasticsearch elasticsearch -f esvalues.yaml

Ktra lai

    kubectl get pod,deploy,svc,pv,pvc -o wide

![image](https://user-images.githubusercontent.com/19284401/133392800-47fa85e6-8816-4cdd-9b0e-a33a0b80fcdb.png)

### FileBeat

    helm pull --version 7.10.0 elastic/filebeat && tar -xvf filebeat-7.10.0.tgz

    vim filebeat/values.yaml

Tìm đến dòng 111 sửa 1000m  thành 500m

![image](https://user-images.githubusercontent.com/19284401/133395492-7a19a455-bf36-4c68-a771-a28c3e51e812.png)

    helm install filebeat filebeat


### kibana

    curl -LO https://github.com/letran3691/K8S/blob/main/LAB/kivalues.yaml

    vim kivalues.yaml

Đến dòng 2 đổi thành IP LoadBalancer của Elastic

Đến dòng 5 đổi thành imageTag: "7.8.0"

![image](https://user-images.githubusercontent.com/19284401/133396574-84118b43-6f47-4ce6-9570-e0b756e2b29e.png)

    helm install --version 7.8.0 kibana elastic/kibana -f kivalues.yaml

sau khi deploy xong nhớ ktra lại

![image](https://user-images.githubusercontent.com/19284401/133423597-5c51ee09-de48-429c-9269-252533a03781.png)


### Metricbeat

#### Metrics-server

    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

    helm pull metrics-server/metrics-server && tar -xvf metrics-server-*

    vim metrics-server/values.yaml

   tìm đến dòng 76 và thêm vào

    - --kubelet-insecure-tls
    
![2021-09-15_16h50_25](https://user-images.githubusercontent.com/19284401/133420431-e90b7e3d-b240-4e9d-99a6-a7e181204a90.png)

    helm install metrics-server metrics-server

#### Metricbeat

    helm pull --version 7.8.0 elastic/metricbeat && tar -xvf metricbeat-7.8.0.tgz

    vim metricbeat/values.yaml

Tìm đến dòng 89 sửa CPU thành 500m

Tìm đến dòng 141 sửa CPU thành 500m

    helm install metricbeat metricbeat

nếu bạn nào bị báo lỗi (Mình đang dùng K8S v1.22.1, nên phát sinh ra lỗi này)

Error: INSTALLATION FAILED: unable to build kubernetes objects from release manifest: [unable to recognize "": no matches for kind "ClusterRole" in version "rbac.authorization.k8s.io/v1beta1", unable to recognize "": no matches for kind "ClusterRoleBinding" in version "rbac.authorization.k8s.io/v1beta1"]

thì hãy sửa lại toàn bộ các apiVersion: rbac.authorization.k8s.io/v1beta1 thành apiVersion: rbac.authorization.k8s.io/v1

#### Metricbeat Dashboard

    curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.8.0-x86_64.rpm

    rpm -vi metricbeat-7.8.0-x86_64.rpm

    vim /etc/metricbeat/metricbeat.yml

dòng 67 đổi thành ip LoadBalancer của Kibana
dòng 94 đổi thành ip LoadBalancer của Elastic

![2021-09-15_16h25_27](https://user-images.githubusercontent.com/19284401/133421104-fb5ee270-21c2-4ec9-a08b-3b50bde457ca.png)


    metricbeat modules enable kubernetes

    metricbeat setup dashboard

![2021-09-15_17h32_38](https://user-images.githubusercontent.com/19284401/133421839-817cee0f-caa8-4f1e-a70c-ce3744d0458a.png)

![1](https://user-images.githubusercontent.com/19284401/133421971-700bfe7f-9183-47b0-9eb6-774743aa145c.gif)
![2](https://user-images.githubusercontent.com/19284401/133422399-8be7c821-1bc3-4f6f-8899-87d69f6077f3.gif)





