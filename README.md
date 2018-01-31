# 在Kubernetes集群里安装RabbitMQ集群 #

## 1. 准备工作 ##

### 1.1 Kubernetes集群 ###

在进行安装之前，必须保证先有一个安装好的正常工作的kubernetes集群。并且集群还应该满足以下条件：

- kubernetes版本1.9。
- 定义好了一个storageclass资源，并且安装好glusterfs作为文件系统。
- kube-dns已经正常安装可以工作。

### 1.2 安装包 ###

- 1.2.1 Erlang运行环境 

  erlang-20.1.7-1.el7.centos.x86_64.rpm

  下载地址：https://github.com/rabbitmq/erlang-rpm/releases



- 1.2.2 RabbitMQ Server 

  rabbitmq-server-3.6.13-1.el7.noarch.rpm

  下载地址：https://github.com/rabbitmq/rabbitmq-server/releases



- 1.2.3 RabbitMQ autocluser插件 

  autocluster-0.10.0.ez、rabbitmq_aws-0.10.0.ez

  下载地址：https://github.com/rabbitmq/rabbitmq-autocluster/releases


> 注意：
>
> 1. 注意插件和rabbitmq server的版本对应关系。autocluster插件仅支持3.6.X版本的rabbitmq server。从3.7版本开始，使用新的插件。参考：https://github.com/rabbitmq/rabbitmq-peer-discovery-k8s。
> 2. 注意rabbitmq server和支持的erlang版本对应关系。可以参考官方文档：http://www.rabbitmq.com/which-erlang.html。
>
> 参考：https://github.com/rabbitmq/rabbitmq-autocluster

### 1.3 制作镜像 ###

#### 1.3.1 为基础镜像添加依赖 ####

​	为了能够使用特定版本的RPM安装包来安装RabbitMQ server，需要基础镜像里能够支持`rpm`命令，所以选用了centos镜像(即`docker.io/centos:latest`)作为基础镜像。

​	测试过程发现，centos镜像缺少安装rabbitmq-server的依赖，需要先安装依赖：

```shell
docker pull centos
docker run centos yum install -y socat logrotate
myid=$(docker ps -a | grep centos | awk '{print $1}')
docker commit -m 'add dependencies' $myid centos-base:latest
```

#### 1.3.2 制作docker镜像 ####

使用编写的Dockerfile（见附件1）制作镜像：

```shell
docker build -t my-registry:5000/rabbitmq-zj:latest ./Dockerfile
docker push my-registry:5000/rabbitmq-zj:latest
```

目前应该有以下目录结构：

```text
- workdir
	- Dockerfile
	- boot.sh
	- install_rabbitmq.sh
	- files/
		- autocluster-0.10.0.ez
		- rabbitmq_aws-0.10.0.ez
		- erlang-20.1.7-1.el7.centos.x86_64.rpm
		- rabbitmq-server-3.6.13-1.el7.noarch.rpm
		- rabbitmq.config
```



## 2. 在k8s集群创建service资源 ##

为了能够让rabbitmq对外k8s集群外和集群里其它pod提供服务，需要为它创建一个`service`。

使用附件3的`rabbitmq-service.yaml`文件，在k8s集群的master节点执行以下命令创建`service`资源：

```shell
kubectl create -f rabbitmq-service.yaml
```

**说明**	YAML文件里`ports`（端口映射）配置的

- `port`是容器内部RabbitMQ监听的内部端口；
- `targetPort`是容器将`port`映射为容器对外开放的端口;

一共配置了两组端口，`http`表示的是rabbitmq网页监控页面访问的端口，`amqp`表示的是通过rabbitmq客户端访问的端口。

## 3. 在k8s集群创建serviceAccount资源  ##

autocluster插件需要访问apiserver，以发现其它rabbitmq节点。所以需要为它创建一个`serviceAccount`（也是一种k8s资源），以确保它有足够的权限在pod里访问apiserver。

使用附件4的`rabbitmq-account.yaml`文件，在k8s集群的master节点执行以下命令创建`serviceAccount`资源：

```shell
kubectl create -f rabbitmq-account.yaml
```
## 4. 在k8s集群创建StatefulSet资源 ##

假设现在现在想把rabbitmq集群部署到k8s集群里指定的3个Node上。假设这3个node的名字分别为`k8s-node1`、`k8s-node2`和`k8s-node3`，那么先应该在master节点执行以下命令，为它们设置标签：

```shell
kubectl label node k8s-node1 mq=yes
kubectl label node k8s-node2 mq=yes
kubectl label node k8s-node3 mq=yes
```

> 注意rabbitmq-statefulset.yaml里的`nodeSelector`，它会让k8s将pod调度到上面设置过对应标签的node上。

使用附件5的`rabbitmq-statefulset.yaml`文件，在k8s集群的master节点执行以下命令创建statefulset资源：

```shell
kubectl create -f rabbitmq-statefulset.yaml
```
**说明**

为了配合autocluster插件实现rabbitmq节点的服务发现，需要设置一些环境变量，这些环境变量的作用参考github文档：https://github.com/rabbitmq/rabbitmq-autocluster#k8s-configuration.

`volumeClaimTemplates`和`volumeMounts`两个标签的作用是为了将容器内的rabbitmq的数据库文件(`/var/lib/rabbitmq`)、日志文件目录(`/var/log/rabbitmq`)挂载出来，以保证pod重新调度容器被被删除后，数据目录还能保存好。

**问题**

- 挂载的目录在容器内，会出现无法被rabbitmq server访问的问题。

  解决方法：因为挂载后目录的权限所有者为`root:root`。所以需要在`image`标签后面添加一个`command`标签，用于在容器启动时设置这两个目录的所有者权限为`rabbitmq:rabbitmq`。

- 在某个rabbitmq节点挂掉之后，重新加入集群，会被拒绝。

  解决方法：挂掉的节点，会被集群其它节点检测到失去连接，所以集群会把它移除。而挂掉的节点重启后，认为自己还在集群，所以尝试加入集群，然后又被拒绝。环境变量`AUTOCLUSTER_CLEANUP`应该设置为`false`，禁止自动移除跟集群失去连接的节点。

## 5. 增加与减少RabbitMQ节点

### 5.1 增加节点

可以使用类似于以下命令，进行增加rabbitmq节点：

```shell
kubectl scale statefulset rabbitmq --replicas=5
```

通常，增加rabbitmq节点时，也会相应增加新的主机，新加的主机在k8s集群对应的Node应该先设置好标签（如第4节所述）。比如新的主机对应的Node名称分别为`k8s-node4`、`k8s-node5`，则应该先运行以下命令：

```shell
kubectl label node k8s-node4 mq=yes
kubectl label node k8s-node5 mq=yes
```

注意这里设置的标签与`rabbitmq-statefulset.yaml`文件里的`nodeSelector`指定的标签一致。然后，再运行k8s的`scale`命令进行添加rabbitmq节点。

### 5.2 减少节点

首先需要清楚的是，使用当前文档的方案在k8s集群里搭建的rabbitmq集群，每个mq节点对应的pod名称都是有编号的，pod名称类似于`rabbitmq-0`、`rabbitmq-1`……这样的。

创建rabbitmq集群时，在k8s里对应pod的启动顺序是按名称编号从小到大顺序逐个启动。

因此，删除时会按照pod名称的编号从大到小的顺序删除。

比如，现在在k8s集群里有5个rabbitmq节点了，对应5个pod：`rabbitmq-0`，……，`rabbitmq-4`。现在想删除一个rabbitmq节点（也即删除pod `rabbimq-4`），可以在k8s的master节点执行以下命令：

```shell
mq_node='rabbit@'$(kubectl get po rabbitmq-4 -o jsonpath='{.status.podIP}')
kubectl exec rabbitmq-4 rabbitmqctl stop_app
kubectl exec rabbitmq-0 rabbitmqctl forget_cluster_node $mq_node
kubectl scale statefulset rabbitmq --replicas=4
```

**注意** 务必先在待删除的rabbitmq节点执行`stop_app`让它脱离rabbitmq集群，然后再执行命令将其从rabbitmq集群移除。

## 6. 其它问题及解决办法

### 6.1 出现Network partition问题

**形成的原因**

有时候由于网络故障或者系统挂起(suspend)，集群节点之间无法通信，无法通信的双方节点都认为对方发生故障，都认为自己正常运行。等到无法通信的双方重新恢复通信时，这时候网络分区(Network partitions)就会形成。

因为双方无法通信时，双方都在独立作为集群运行，这期间它们都可能单方面地发生队列\Queue\Binding的创建删除。双方恢复通信时，双方集群的状态可能不一致，它们将继续在不同的网络分区以独立集群运行，等待人工修复。

**检测是否出现网络分区**

最简单的就是在web监控页面，会看到红字警告提示，网络发生分区，可能会有数据丢失。或者在某一节点运行命令`rabbitmqctl cluster_status`，从输出信息的partitions部分可以看到。

```shell
rabbitmqctl cluster_status
# => Cluster status of node rabbit@smacmullen ...
# => [{nodes,[{disc,[hare@smacmullen,rabbit@smacmullen]}]},
# =>  {running_nodes,[rabbit@smacmullen,hare@smacmullen]},
# =>  {partitions,[{rabbit@smacmullen,[hare@smacmullen]},
# =>               {hare@smacmullen,[rabbit@smacmullen]}]}]
# => ...done.
```

**手动恢复**

选择一个保留的分区，重启其它分区的所有节点。重启命令为：

```shell
rabbitmqctl stop_app
rabbitmqctl start_app
```

**设置自动恢复的策略**

在配置文件`/etc/rabbitmq/rabbitmq.conf`里设置：

```sh
# 默认为ignore模式
cluster_partition_handling=ignore
# cluster_partition_handling=pause_minority
# cluster_partition_handling=pause_if_all_down
# cluster_partition_handling=autoheal
```

参考官方文档：https://www.rabbitmq.com/partitions.html#automatic-handling

------

## 附件： ##

### 1. Dockerfile ###
```dockerfile
FROM centos-base:latest
COPY ./files/* /tmp/
COPY ./*.sh /tmp/
WORKDIR /tmp/
RUN sh ./install_rabbitmq.sh
RUN rm -v ./install_rabbitmq.sh
CMD sh boot.sh
```

### 2. install_rabbitmq.sh ###

```shell
echo '============ install erlang ... ============'
rpm -ivh erlang-20.1.7.1-1.el7.centos.x86_64.rpm

echo '============ install rabbitmq server ... ============'
rpm -ivh rabbitmq-server-3.6.13-1.el7.noarch.rpm

echo '============ deleting rpm packages ... ============'
rm -v *.rpm

chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq

echo '====== move RabbitMQ extension files ========'
mv *.ez /usr/lib/rabbitmq/lib/rabbitmq_server-3.6.13/plugins/

echo '====== move RabbitMQ configuration  file ========'
mv rabbitmq.config /etc/rabbitmq/

rabbitmq-server -detached
rabbitmq-plugins enable rabbitmq_management autocluster
rabbitmq-plugins list
```

关于`rabbitmq.config`文件，可以参考在github上的rabbitmq server项目的`docs/rabbitmq.config.example`文件。地址：https://github.com/rabbitmq/rabbitmq-server。

### 3. boot.sh ###

```shell
#!/bin/bash

wait_for_log(){

log_name=$1

echo 'check log file '$log_name'...'
while true
do
        if [ ! -f $log_name ]; then
                sleep 5
        else
                break
        fi
done

tail -f $log_name

}

check_apiserver(){
ck=1
retry=0
apiserver="http://${K8S_HOST}:${K8S_PORT}/api/v1"
while [ $ck -ne 0 -a $retry -lt 10 ]
do
	curl $apiserver
	ck=$?
        let retry=retry+1
	sleep 2
done
if [ $retry -lt 10 ] ; then
	return 0
else
	echo "unable to connect kubernetes apiserver:$apiserver. Refuse to start rabbitmq server."
	return 1	
fi
}

check_apiserver && \
rabbitmq-server -detached && \
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq && \
wait_for_log /var/log/rabbitmq/${RABBITMQ_NODENAME}.log
```

### 4. rabbitmq-service.yaml ###

```yaml
kind: Service
apiVersion: v1
metadata:
  name: rabbitmq
  labels:
    app: rabbitmq
    type: LoadBalancer  
spec:
  type: ClusterIP
  ports:
   - name: http
     protocol: TCP
     port: 15672
     targetPort: 15672
   - name: amqp
     protocol: TCP
     port: 5672
     targetPort: 5672
  selector:
    app: rabbitmq
```

### 5. rabbitmq-account.yaml ###

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rabbitmq
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rabbitmq
rules:
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["get"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rabbitmq
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rabbitmq
subjects:
- kind: ServiceAccount
  name: rabbitmq
```

### 6. rabbitmq-statefulset.yaml ###

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
spec:
  serviceName: rabbitmq
  replicas: 3
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      serviceAccountName: rabbitmq
      terminationGracePeriodSeconds: 10
      nodeSelector:
        mq-node: "yes"
      containers:        
      - name: rabbitmq-autocluster
        image: my-registry:5000/rabbitmq-zj:20180129e
        ports:
          - name: http
            protocol: TCP
            containerPort: 15672
          - name: amqp
            protocol: TCP
            containerPort: 5672
        livenessProbe:
          exec:
            command: ["rabbitmqctl", "status"]
          initialDelaySeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          exec:
            command: ["rabbitmqctl", "status"]
          initialDelaySeconds: 30
          timeoutSeconds: 15
        imagePullPolicy: IfNotPresent
        securityContext:
          capabilities: {}
          privileged: true
        volumeMounts:
        - name: rabbitmq-data
          mountPath: /var/lib/rabbitmq/mnesia
        - name: rabbitmq-log
          mountPath: /var/log/rabbitmq
        env:
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: RABBITMQ_USE_LONGNAME
          value: "true"
        - name: RABBITMQ_NODENAME
          value: "rabbit@$(MY_POD_IP)"
        - name: AUTOCLUSTER_TYPE
          value: "k8s"
        - name: RABBITMQ_NODE_TYPE
          value: "disc"
        - name: AUTOCLUSTER_DELAY
          value: "10"
        - name: AUTOCLUSTER_CLEANUP
          value: "false"
        - name: CLEANUP_WARN_ONLY
          value: "true"
        - name: K8S_SCHEME
          value: "http"
        - name: K8S_HOST
          value: "172.20.0.12"
        - name: K8S_PORT
          value: "8080"
      hostNetwork: true
  volumeClaimTemplates:
  - metadata:
      name: rabbitmq-data
      annotations:
        volume.beta.kubernetes.io/storage-class: "fast"
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Gi
  - metadata:
      name: rabbitmq-log
      annotations:
        volume.beta.kubernetes.io/storage-class: "fast"
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Gi
```

### 7. 参考文档 ###

rabbitmq server的安装文档：http://www.rabbitmq.com/install-rpm.html

官方使用autocluster插件在kubernetes集群实现集群的示例：https://github.com/rabbitmq/rabbitmq-autocluster/tree/master/examples/k8s_rbac_statefulsets

RabbitMQ配置文件的说明：http://www.rabbitmq.com/configure.html

RabbitMQ自动化组建集群：http://www.rabbitmq.com/cluster-formation.html#peer-discovery-k8s