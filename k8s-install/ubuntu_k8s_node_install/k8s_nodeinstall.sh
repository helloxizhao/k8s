#!/bin/bash
# install docker-ce depend
cd /usr/local/src
wget http://launchpadlibrarian.net/236916213/libltdl7_2.4.6-0.1_amd64.deb
dpkg -i libltdl7_2.4.6-0.1_amd64.deb 
#----------------------------------------
# install docker-ce-17.03
apt-get update
apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
apt-get -y update
apt -y install docker-ce=17.03.1~ce-0~ubuntu-xenial
systemctl start docker
#---------------------------------------------------
# change docker storage fs type
cat >/etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2"
}
EOF
systemctl  daemon-reload
systemctl  restart docker
#--------------------------------
#change iptables 
cat <<EOF > /etc/sysctl.d/net.iptables.k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
#--------------------------------
# close swap
swapoff -a
#---------------
#create ali k8s repo file
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.ustc.edu.cn/kubernetes/apt kubernetes-xenial main
EOF
apt-get -y update
apt install -y  kubelet=1.13.1-00 kubectl=1.13.1-00 kubeadm=1.13.1-00 kubernetes-cni=0.6.0-00 --allow-unauthenticated
systemctl start kubelet
systemctl enable kubelet
#------------------------
for  image in $(cat image);
do 
    docker pull registry.ispacesys.cn/k8sbase/$image
    docker tag registry.ispacesys.cn/k8sbase/$image  k8s.gcr.io/$image
done
