#!/bin/bash
#Run these commands as root
###Install GO###
git clone https://github.com/Mirantis/cri-dockerd.git
#wget https://storage.googleapis.com/golang/getgo/installer_linux
#chmod +x ./installer_linux
#./installer_linux
#source ~/.bash_profile
echo -e "033[43;34m ---start install go and cri--- \033[0m"
apt install golang-go -y
cd cri-dockerd || exit
mkdir bin
go build -o bin/cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
sed -i "s/^disabled_plugins/#disabled_plugins/g" /etc/containerd/config.toml
systemctl daemon-reload
systemctl restart cri-docker && systemctl restart docker
