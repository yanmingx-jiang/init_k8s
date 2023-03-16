#!/bin/bash

set +x
DMZ_PROXY_HTTP=${DMZ_PROXY_HTTP:-"http://proxy-dmz.intel.com:911/"}
DMZ_PROXY_HTTPS=${DMZ_PROXY_HTTPS:-"http://proxy-dmz.intel.com:912/"}
PRC_PROXY=${PRC_PROXY:-"http://child-prc.intel.com:913"}
dockermirror="10.67.115.219"
#shell_folder=$(
#    cd "$(dirname "$0")" || exit
#    pwd
#)

#source "$shell_folder/k8s_config.cfg"
#source k8s_config.cfg

display_usage() {
    echo -e "\nUsage: $0 --ver=<k8s version> --cri=containerd --docker_ver=<docker version> --net=calico --role=master|worker --proxy=dmz \n"
    echo -e "ubuntu 20.04: ./install.sh --ver=1.23.3 --cri=docker --docker_ver=20.10.12 --net=calico --role=master --proxy=dmz \n"
    echo -e "ubuntu 22.04: ./install.sh --ver=1.23.3 --cri=docker --docker_ver=20.10.23 --net=calico --role=master --proxy=dmz \n"
}
if [ $# -ne 4 ] && [ $# -ne 5 ] && [ $# -ne 6 ] ; then
    display_usage
    exit 1
else
    while [ "$1" != "" ]; do
        PARAM=$(echo "$1" | awk -F= '{print $1}')
        VALUE=$(echo "$1" | awk -F= '{print $2}')
        case $PARAM in
        -h | --help)
            display_usage
            exit
            ;;
        -v | --ver)
            ver=$VALUE
            ;;
        -r | --role)
            role=$VALUE
            ;;
        -c | --cri)
            cri=$VALUE
            ;;
        -n | --net)
            net=$VALUE
            ;;
        -p | --proxy)
            proxy=$VALUE
            ;;
        --docker_ver)
            docker_ver=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            display_usage
            exit 1
            ;;
        esac
        shift
    done
fi
echo -e "Starting the K8s Installation with below configs"
echo "==============================================================="
echo -e "K8s version ====> ${ver}"
echo -e "Container runtime ====> ${cri}"
echo -e "CNI ====> ${net}"
echo -e "Role ====> ${role}"
if [ "${docker_ver}" != "" ] ;then
echo -e "docker version ====> ${docker_ver}"
fi
echo -e "==============================================================="

# select proxy

set_proxy() {
    # set proxy
    local_ip=$(ip a | awk '/^[0-9]+: / {}; /inet.*global/ {printf  gensub(/(.*)\/(.*)/, "\\1,", "g", $2)}')
    #echo "${local_ip}"
    if [[ "$proxy" == "dmz" ]]; then
        export http_proxy=${DMZ_PROXY_HTTP}
        export https_proxy=${DMZ_PROXY_HTTPS}
        export no_proxy="${local_ip}127.0.0.1,localhost,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,10.166.0.0/16,10.244.0.0/16,flex-npg-workload.sh.intel.com,intel.com,01.org,flex-npg-workload.bj.intel.com,linux-ftp.intel.com,$dockermirror"
    else
        export http_proxy=${PRC_PROXY}
        export https_proxy=${PRC_PROXY}
        export no_proxy="${local_ip}127.0.0.1,flex-npg-workload.bj.intel.com,localhost,10.67.116.242,10.67.0.0/16,10.96.0.0/12,172.17.0.0/16,10.244.0.0/16,flex-npg-workload.sh.intel.com,intel.com,01.org,linux-ftp.intel.com,$dockermirror"
    fi
    FIELE_CONTENT=$(cat /etc/environment 2>>/dev/null)
    cat /etc/environment 2>>/dev/null
    if [[ ! "$FIELE_CONTENT" =~ $http_proxy ]]; then
        echo -e "http_proxy=$http_proxy" | sudo tee -a /etc/environment
    fi
    if [[ ! "$FIELE_CONTENT" =~ $https_proxy ]]; then
        echo -e "https_proxy=$https_proxy" | sudo tee -a /etc/environment
    fi
    if [[ ! "$FIELE_CONTENT" =~ $no_proxy ]]; then
        echo -e "no_proxy=$no_proxy" | sudo tee -a /etc/environment
    fi
    sleep 3
}

#update time

set_time_ubuntu() {
    if [[ "$proxy" == "dmz" ]]; then
        timedatectl set-ntp true
        apt install ntpdate -y
        ntpdate corp.intel.com >/dev/null 2>&1
        hwclock --systohc
    else
        timedatectl set-timezone Asia/Shanghai
        timedatectl set-ntp true
        apt install ntpdate -y
        ntpdate corp.intel.com >/dev/null 2>&1
        hwclock --systohc
    fi
    sleep 5
}

set_time_centos() {
    if [[ "$proxy" == "dmz" ]]; then
        sed -i  's#pool 2.centos.pool.ntp.org iburst#pool corp.intel.com iburst#g' /etc/chrony.conf
        chronyd -q 'server corp.intel.com iburst'
        chronyc sourcestats  -v
        systemctl enable chronyd.service
        systemctl start chronyd.service
    else
        timedatectl set-timezone Asia/Shanghai
        sed -i  's#pool 2.centos.pool.ntp.org iburst#pool corp.intel.com iburst#g' /etc/chrony.conf
        chronyd -q 'server corp.intel.com iburst'
        chronyc sourcestats  -v
        systemctl enable chronyd.service
        systemctl start chronyd.service
    fi
}

#install kuadmin

install_kube_ubuntu() {
    apt -y install curl wget vim git apt-transport-https gnupg gnupg2 software-properties-common ca-certificates lsb-release
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    systemctl stop ufw
    systemctl disable ufw
    apt purge -y needrestart --allow-change-held-packages
    apt update
    apt -y install wget kubelet=${ver}-00 kubeadm=${ver}-00 kubectl=${ver}-00 --allow-change-held-packages
    apt-mark hold kubelet kubeadm kubectl
    source k8s_config.cfg
}

install_kube_centos() {
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
    # Set SELinux in permissive mode (effectively disabling it)
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    # Turn off firewall
    systemctl stop firewalld    # temporary wiy
    systemctl disable firewalld # permanent way
    yum install -y kubelet-${ver}-0 kubeadm-${ver}-0 kubectl-${ver}-0 --disableexcludes=kubernetes
    systemctl enable --now kubelet  
    source k8s_config.cfg
}

#initializing kubenetes

set_kube() {
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab
    modprobe overlay
    modprobe br_netfilter
    tee /etc/sysctl.d/kubernetes.conf <<-foo
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
foo
    sysctl --system
    sleep 5
}

k8_init() {
    echo -e "sudo ./${cri}.sh --sock=${!cri} --role=${role} --docker_ver=${docker_ver}"
    if [[ "${ver}" =~ ^'1.25' || "${ver}" =~ ^'1.24' ]]; then
        echo -e "\033[43;34m kubenetes version greater than 1.23, automatically switch container engine to containerd! \033[0m"
        cri=containerd
        containerd=/var/run/containerd/containerd.sock
        source ${cri}.sh --sock=${!cri} --role=${role} # ${!cri}是/var/run/docker.sock变量间接引用
    else
        cri=docker
        docker=/var/run/docker.sock
        source ${cri}.sh --sock=${!cri} --role=${role} --docker_ver=${docker_ver}
    fi  
    echo -e "\033[43;34m ============================  \033[0m"
    echo -e "\033[43;34m ---start init the cluster--- \033[0m"
    echo -e "\033[43;34m ============================  \033[0m"
    tee /etc/modules-load.d/containerd.conf <<-foo
    overlay
    br_netfilter
foo
    sleep 5
    if [[ "${role}" == "master" ]]; then
        kubeadm init --service-cidr=10.96.0.0/16 --pod-network-cidr=10.244.0.0/16
        kubectl get node -o wide
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
# Avoid docker.sock not running
        sleep 3
        systemctl restart docker >/dev/null 2>&1
        kubectl cluster-info
        echo -c "Deploying the CNI $net with yaml ==> ${!net}"
        kubectl apply -f "${!net}"
        sleep 30
        kubectl get node -o wide
    fi
}

#ubuntu install
setup_all_ubuntu() {
    set_proxy
    set_time_ubuntu
    install_kube_ubuntu
    set_kube
    k8_init
    source /usr/share/bash-completion/bash_completion >/dev/null
    source <(kubectl completion bash) >/dev/null
    sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null
    echo -e "\033[43;34m =============================================================== \033[0m"
    echo -e "\033[43;34m Successfully Installed k8s ${ver} ${role} node with ${net} CNI \033[0m"
    echo -e "\033[43;34m =============================================================== \033[0m"
}

#centos install
setup_all_centos() {
    set_proxy
    set_time_centos
    install_kube_centos
    set_kube
    k8_init
    echo "source <(kubectl completion bash)" >>$USER_HOME/.bashrc
    source $USER_HOME/.bashrc &>/dev/null
    echo -e "==============================================================="
    echo -e "\033[43;34m =============================================================== \033[0m"
    echo -e "\033[43;34m Successfully Installed k8s ${ver} ${role} node with ${net} CNI \033[0m"
    echo -e "\033[43;34m =============================================================== \033[0m"

}

#choose os
choose_os() {
    if ! type yum >/dev/null 2>&1; then
        setup_all_ubuntu
        apt-get -y needrestart
    else
        setup_all_centos
    fi
}
#choose_os(){
#    OS_ID=$(sed -rn '/^NAME=/s@.*="([[:alpha:]]+).*"$@\1@p' /etc/os-release)
#    if [ "${OS_ID}" == "CentOS" ] && [ "${OS_ID}" == "Fedora" ] && [ "${OS_ID}" == "Red" ];then
#        setup_all_centos
#    else
#        setup_all_ubuntu
#    fi
#}

choose_os
