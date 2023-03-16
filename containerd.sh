#!/bin/bash
set +x
DMZ_PROXY_HTTP=${DMZ_PROXY_HTTP:-"http://proxy-dmz.intel.com:911/"}
DMZ_PROXY_HTTPS=${DMZ_PROXY_HTTPS:-"http://proxy-dmz.intel.com:912/"}
PRC_PROXY=${PRC_PROXY:-"http://child-prc.intel.com:913"}
display_usage() {
    echo -e "\nUsage: $0 --sock=<cri socket path> --role=master|worker\n"
    echo -e "Example: ./containerd.sh --sock=/run/containerd/containerd.sock --role=master\n"
}

if [ $# -ne 2 ]; then
    display_usage
    exit 1
else
    while [ "$1" != "" ]; do
        PARAM=$(echo $1 | awk -F= '{print $1}')
        VALUE=$(echo $1 | awk -F= '{print $2}')
        case $PARAM in
        -h | --help)
            display_usage
            exit
            ;;
        -v | --sock)
            sock=$VALUE
            ;;
        -r | --role)
            role=$VALUE
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

#centos containerd
install_contai_ubuntu() {
    echo -e "\033[43;34m ======================== \033[0m"
    echo -e "\033[43;34m Start to setup containerd.io... \033[0m"
    echo -e "\033[43;34m ======================== \033[0m"
    apt-get install ca-certificates curl gnupg lsb-release gnupg2 software-properties-common apt-transport-https -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
    apt update
    apt install containerd.io -y
    mkdir -p /etc/systemd/system/containerd.service.d/
}

#centos containerd
install_contai_centos() {
    echo -e "\033[43;34m ======================== \033[0m"
    echo -e "\033[43;34m Start to setup containerd.io... \033[0m"
    echo -e "\033[43;34m ======================== \033[0m"
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    # Set up a repository
    YUM_UTILS=$(yum list installed yum-utils 2>>/dev/null)
    if [[ ! $YUM_UTILS =~ "yum-utils" ]]; then
        yum install -y yum-utils device-mapper-persistent-data
    fi
    if [ ! -e /etc/yum.repos.d/docker-ce.repo ]; then
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
    #  Install Docker Engine
    yum remove -y buildah # remove buildah
    yum remove -y podman  # remove podman
    yum install containerd.io -y
    mkdir -p /etc/systemd/system/containerd.service.d/
}


#proxy
containerdproxy() {
    local_ip=$(ip a | awk '/^[0-9]+: / {}; /inet.*global/ {printf  gensub(/(.*)\/(.*)/, "\\1,", "g", $2)}')
    if [[ "$proxy" == "dmz" ]]; then
        tee /etc/systemd/system/containerd.service.d/https-proxy.conf <<EOF
[Service]
Environment="HTTPS_PROXY=${DMZ_PROXY_HTTPS}"
EOF

        tee /etc/systemd/system/containerd.service.d/http-proxy.conf <<EOF
[Service]	
Environment="HTTP_PROXY=${DMZ_PROXY_HTTP}"
EOF

        tee /etc/systemd/system/containerd.service.d/no-proxy.conf <<EOF
[Service]	
Environment="NO_PROXY=${local_ip}127.0.0.1,flex-npg-workload.bj.intel.com,localhost,10.67.116.242,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16,flex-npg-workload.sh.intel.com,intel.com,intel.com，linux-ftp.intel.com"
EOF

    else
        tee /etc/systemd/system/containerd.service.d/https-proxy.conf <<EOF
[Service]
Environment="HTTPS_PROXY=${PRC_PROXY}"
EOF

        tee /etc/systemd/system/containerd.service.d/http-proxy.conf <<EOF
[Service]	
Environment="HTTP_PROXY=${PRC_PROXY}"
EOF

        tee /etc/systemd/system/containerd.service.d/no-proxy.conf <<EOF
[Service]	
Environment="NO_PROXY=${local_ip}127.0.0.1,flex-npg-workload.bj.intel.com,localhost,10.67.116.242,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16,flex-npg-workload.sh.intel.com,intel.com,intel.com，linux-ftp.intel.com"
EOF
    fi
}


#set_config
set_containerd() {
#create default config files 
    if [ ! -d "/etc/containerd" ]; then
	    mkdir -p /etc/containerd
        containerd config default>/etc/containerd/config.toml
#run file
    else
        rm -f /etc/containerd/config.toml >/dev/null 2>&1
        containerd config default>/etc/containerd/config.toml
fi
    cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
    sed -i.bak 's#config_path = ""#config_path = "/etc/containerd/certs.d"#g' /etc/containerd/config.toml
    mkdir -p /etc/containerd/certs.d
    tee  /etc/containerd/certs.d/hosts.toml <<-foo
server = "dcsorepo.jf.intel.com"
[host."dcsorepo.jf.intel.com"]
  capabilities = ["pull", "resolve","push"]
  skip_verify = true
server = "10.219.170.195:5000"
[host."10.219.170.195:5000"]
  capabilities = ["pull", "resolve","push"]
  skip_verify = true
  username = ""
  password = ""
server = "10.67.115.219:5000"
[host."10.67.115.219:5000"]
  capabilities = ["pull", "resolve","push"]
  skip_verify = true
server = "https://harbor-npg.pact.intel.com"
[host."https://harbor-npg.pact.intel.com"]
  capabilities = ["pull", "resolve","push"]
  skip_verify = true
server = "amr-registry.caas.intel.com"
[host."amr-registry.caas.intel.com"]
  capabilities = ["pull", "resolve","push"]
  skip_verify = true
foo
}

#set_crictl
install_crictl () {
    cd /tmp || exit
    VERSION="v1.25.0"
    wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
    sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
    sudo rm -f crictl-$VERSION-linux-amd64.tar.gz
}


#set env
docker_os() {
    OS_ID=$(sed -rn '/^NAME=/s@.*="([[:alpha:]]+).*"$@\1@p' /etc/os-release)
    if [ "${OS_ID}" == "CentOS" ] && [ "${OS_ID}" == "Fedora" ];then
        install_contai_centos
        containerdproxy
        set_containerd
        sleep 3
        install_crictl
        systemctl daemon-reload
        systemctl restart containerd
        systemctl enable containerd
    else
        install_contai_ubuntu
        containerdproxy
        set_containerd
        sleep 3
        install_crictl
        systemctl daemon-reload
        systemctl restart containerd
        systemctl enable containerd
    fi
}

docker_os


#if [[ "${role}" != "master" ]]; then
#    echo -e "==============================================================="
#    echo -e "Successfully Installed k8s ${role} node with containerd as container runtime"
#    echo -e "==============================================================="
#else
#    systemctl enable kubelet
#    kubeadm config images pull --cri-socket "${sock}"
#fi
echo -e "if you want:kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-"
