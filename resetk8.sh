#!/bin/bash
set +x

echo -e "\033[31m clear kubetools \033[m"
echo -e "\033[31m !!!! start purge kubenetes ...... \033[m"

# reset system env
if [ -x "$(command -v kubeadm)" ]; then
    kubeadm reset --force 
fi
systemctl stop kubelet >/dev/null 2>&1
rm -rf /var/lib/kubelet
docker stop $(docker ps -aq) >/dev/null 2>&1
docker system prune -f >/dev/null 2>&1
docker volume rm -f $(docker volume ls -q) >/dev/null 2>&1
docker image rm -f $(docker image ls -q) >/dev/null 2>&1
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
modprobe -r ipip


#claer container engine
systemctl stop docker
if ! type yum >/dev/null 2>&1; then
    sudo apt-get remove docker docker-engine docker.io containerd containerd.io  docker-ce docker-ce-cli -y
else
    yum remove docker docker-clientdocker-client-latestdocker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-ce-cli containerd.io -y
fi



#clear repository
if ! type yum >/dev/null 2>&1; then
    if [ -e "/etc/apt/sources.list.d/kubernetes.list" ]; then
        rm -rf /etc/apt/sources.list.d/kubernetes.list 
    fi
    if [ -x "$(command -v kubeadm)" ]; then
        apt purge -y kubeadm --allow-change-held-packages
    fi
    if [ -x "$(command -v kubectl)" ]; then
        apt purge -y kubectl --allow-change-held-packages
    fi
    if [ -x "$(command -v kubelet)" ]; then
        apt purge -y kubelet --allow-change-held-packages
    fi
else
    if [ -e "/etc/yum.repos.d/kubernetes.repo" ]; then
        rm -rf /etc/yum.repos.d/kubernetes.repo 
    fi
    if [ -x "$(command -v kubeadm)" ]; then
        yum remove -y kubeadm kubectl kubelet kubernetes-cni kube*
    fi
fi


#clear conf flie
if [ -e "/etc/cni/net.d" ]; then
    rm -rf /etc/cni/net.d/*
fi
if [ -e "/etc/modules-load.d/containerd.conf" ]; then
    rm -rf /etc/modules-load.d/containerd.conf 
fi
if [ -e "/etc/sysctl.d/kubernetes.conf" ]; then
    rm -rf /etc/sysctl.d/kubernetes.conf 
fi
#clear containerd configfiles
if [ -x "$(command -v crictl)" ]; then
    containerd config default>/etc/containerd/config.toml
fi
rm -rf /var/lib/docker >/dev/null 2>&1
rm -rf /var/lib/containerd >/dev/null 2>&1
rm -rf $HOME/.kube 
rm -rf /home/raspadmin/.kube
systemctl daemon-reload
