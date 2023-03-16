#!/bin/sh
sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl cluster-info
source /usr/share/bash-completion/bash_completion >/dev/null
source <(kubectl completion bash) >/dev/null
sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null