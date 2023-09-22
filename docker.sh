#!/bin/bash

set +x
DMZ_PROXY_HTTP=${DMZ_PROXY_HTTP:-"http://proxy-dmz.intel.com:911/"}
DMZ_PROXY_HTTPS=${DMZ_PROXY_HTTPS:-"http://proxy-dmz.intel.com:912/"}
PRC_PROXY=${PRC_PROXY:-"http://child-prc.intel.com:913"}
dockermirror="10.67.115.219"
display_usage() {
    echo -e "\nUsage: $0 --sock=<cri socket path> --role=master|worker  --docker_ver=20.10.21\n "
    echo -e "Example: ./docker.sh --sock=/var/run/docker.sock --role=master  --docker_ver=${docker_ver}\n"
}

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
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

# Add repo and Install packages
install_docker_ubuntu() {
    echo -e "\033[43;34m ======================== \033[0m"
    echo -e "\033[43;34m Start to setup docker... \033[0m"
    echo -e "\033[43;34m ======================== \033[0m"
    apt-get install ca-certificates curl gnupg lsb-release gnupg2 software-properties-common apt-transport-https -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
    apt-get update
    if [ "${docker_ver}" == "" ] ; then
    apt install -y containerd.io docker-ce docker-ce-cli
    else
    # apt install -y containerd.io docker-ce=5:${docker_ver}~3-0~ubuntu-focal docker-ce-cli=5:${docker_ver}~3-0~ubuntu-focal 
    apt install -y containerd.io docker-ce=5:${docker_ver}~3-0~ubuntu-* docker-ce-cli=5:${docker_ver}~3-0~ubuntu-* 
    fi
}

install_docker_centos() {
    echo -e "\033[43;34m ======================== \033[0m"
    echo -e "\033[43;34m Start to setup docker... \033[0m"
    echo -e "\033[43;34m ======================== \033[0m"
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    # Set up a repository
    YUM_UTILS=$(yum list installed yum-utils 2>>/dev/null)
    if [[ ! $YUM_UTILS =~ "yum-utils" ]]; then
        yum install yum-utils -y
    fi
    if [ ! -e /etc/yum.repos.d/docker-ce.repo ]; then
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
    #  Install Docker Engine
    yum remove -y buildah # remove buildah
    yum remove -y podman  # remove podman
    if [ "${docker_ver}" == "" ] ; then
    yum install -y docker-ce docker-ce-cli containerd.io
    else
    yum install -y docker-ce-${docker_ver} docker-ce-cli-${docker_ver} containerd.io
    fi
}

# Create required directories
set_docker() {
    RESULT_NAME="/etc/systemd/system/docker.service.d"
    if [ ! -d $RESULT_NAME ]; then
        mkdir -p $RESULT_NAME
    else
        echo -e 'Folder created!'
    fi
    if [ ! -e /etc/docker/daemon.json ]; then
        mkdir /etc/docker
        touch /etc/docker/daemon.json
        chmod a+w /etc/docker/daemon.json # all user add write permision
    fi
    # Create daemon json config file
    tee /etc/docker/daemon.json <<EOF
{
    "insecure-registries" : ["$dockermirror:5000","https://harbor-npg.pact.intel.com", "jhou15-4rd-ccr-corp-intel-com.sh.intel.com", "10.67.115.219:5000", "https://sfdev.sh.intel.com:10443","https://icx12.sh.intel.com:10443","https://r49s04.gv.intel.com:10443", "amr-registry.caas.intel.com", "dcsorepo.jf.intel.com","r49s04.gv.intel.com", "vcaa-jf5-lab-1.jf.intel.com:10443", "10.219.170.195:5000","10.166.44.134:5000"],
    "exec-opts":["native.cgroupdriver=systemd"],
    "experimental": true,
    "registry-mirrors": [ "http://$dockermirror","http://hub-mirror.c.163.com","http://docker.mirrors.ustc.edu.cn","https://fl791z1h.mirror.aliyuncs.com" ]
}
EOF
}

dockerproxy() {
    local_ip=$(ip a | awk '/^[0-9]+: / {}; /inet.*global/ {printf  gensub(/(.*)\/(.*)/, "\\1,", "g", $2)}')
    if [[ "$proxy" == "dmz" ]]; then
        tee /etc/systemd/system/docker.service.d/https-proxy.conf <<EOF
[Service]
Environment="HTTPS_PROXY=${DMZ_PROXY_HTTPS}"
EOF

        tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]	
Environment="HTTP_PROXY=${DMZ_PROXY_HTTP}"
EOF

        tee /etc/systemd/system/docker.service.d/no-proxy.conf <<EOF
[Service]	
Environment="NO_PROXY=${local_ip}127.0.0.1,flex-npg-workload.bj.intel.com,localhost,10.67.116.242,172.17.28.0/23,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16,flex-npg-workload.sh.intel.com,intel.com,intel.com,$dockermirror"
EOF
    # set docker proxy
    mkdir ~/.docker 
    cat << EOF > ~/.docker/config.json
    {
     "proxies":
     {
       "default":
       {
         "httpProxy": "$DMZ_PROXY_HTTP",
         "httpsProxy": "$DMZ_PROXY_HTTPS",
         "noProxy": "${local_ip}localhost,127.0.0.0/8,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16"
       }
     }
    }
EOF
else
        tee /etc/systemd/system/docker.service.d/https-proxy.conf <<EOF
[Service]
Environment="HTTPS_PROXY=${PRC_PROXY}"
EOF

        tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]	
Environment="HTTP_PROXY=${PRC_PROXY}"
EOF

        tee /etc/systemd/system/docker.service.d/no-proxy.conf <<EOF
[Service]	
Environment="NO_PROXY=${local_ip}127.0.0.1,flex-npg-workload.bj.intel.com,localhost,10.67.116.242,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16,flex-npg-workload.sh.intel.com,172.17.28.0/23,$dockermirror"
EOF
    # set docker proxy
    mkdir ~/.docker 
    cat << EOF > ~/.docker/config.json
    {
     "proxies":
     {
       "default":
       {
         "httpProxy": "$PRC_PROXY",
         "httpsProxy": "$PRC_PROXY",
         "noProxy": "${local_ip}localhost,127.0.0.0/8,10.67.0.0/16,10.166.0.0/16,10.96.0.0/12,10.244.0.0/16"
       }
     }
    }
EOF

    fi
}

restart_docker() {
    # Start and enable Services
    systemctl daemon-reload
    sleep 5
    systemctl restart docker
    systemctl enable docker
    if [[ "${role}" != "master" ]]; then
        echo -e "==============================================================="
        echo -e "Successfully Installed k8s ${role} node with docker as container runtime"
        echo -e "==============================================================="
    else
        echo "Successfully Installed k8s ${role} node with docker as container runtime"
        systemctl enable kubelet
    fi
}

#install all
install_all_ubuntu() {
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "\033[43;34m Start installing docker for you... \033[0m"
        echo -e "\033[43;34m docker is not installed!! \033[0m"
        install_docker_ubuntu
    else
        echo -e "\033[46;30m docker installed... \033[0m"
    fi
    set_docker
    dockerproxy
    restart_docker
}

install_all_centos() {
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "\033[43;34m Start installing docker for you... \033[0m"
        echo -e "\033[43;34m docker is not installed!! \033[0m"
        install_docker_centos
    else
        echo -e "\033[46;30m docker installed... \033[0m"
    fi
    set_docker
    dockerproxy
    restart_docker
}
choose_os() {
    if ! type yum >/dev/null 2>&1; then
        install_all_ubuntu
    else
        install_all_centos
    fi

}

choose_os
