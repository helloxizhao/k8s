1、install zabbix-server on k8s,这里选在安装在zabbix ns  
kubectl create ns zabbix  
kubectl apply -f zabbix-server.yml -n zabbix  
zabbix-server 里面的nodeselect根据自己的需求进行更改，另外MySQL映射的本地目录需要提前创建好，并且给777权限，不然有可能会出现问题。用于报警的Python
file微信.py也可以提前创建好目录  
2、install agent  
kubectl apply -f zabbix-agent.yml -n zabbix  
里面的zabbix server的地址需要改成zabbix-server的宿主机的地址  
3、都启动之后进行登录  
http://zabbix-server-ip:9090  
