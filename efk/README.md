创建efk
在此yaml file中一共创建了三个es实例，需要给node打label
kubectl label node node1 role=es
kubectl label node node2 role=es
kubectl label node node3 role=es
kubectl create ns logging
kubectl apply -f es-ss.yml
kubectl apply -f fluentd-cm.yml
kubectl apply -f fluentd-ds.yml
kubectl apply -f kibana.yml
等到pod都启动成功就可以访问kibana了
http://ip:32051