#!/bin/bash
DMZ_PROXY_HTTP=${DMZ_PROXY_HTTP:-"http://proxy-dmz.intel.com:911/"}
DMZ_PROXY_HTTPS=${DMZ_PROXY_HTTPS:-"http://proxy-dmz.intel.com:912/"}
PRC_PROXY=${PRC_PROXY:-"http://child-prc.intel.com:913"}
dockermirror="10.67.115.219:5000"

display_usage() {
    echo -e "Example: ./docker.sh --docker_ver=5:27.5.1-1~ubuntu.24.04~noble --proxy=dmz/prc \n"
}

if [[ "$1" == *h ]] || [[ "$1" == *help ]] ; then
    display_usage
    exit 1
fi

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    proxy_env=prc
    echo -e "Will install the latest docker version proxy=prc"

else
    while [ "$1" != "" ]; do
        PARAM=$(echo $1 | awk -F= '{print $1}')
        VALUE=$(echo $1 | awk -F= '{print $2}')
        case $PARAM in
        -h | --help)
            display_usage
            exit
            ;;
        -p | --proxy)
            proxy_env=$VALUE
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

set_proxy() {
    local docker_mirror=$1  # 第一个参数
    local proxy_env=$2   # 第二个参数
    mkdir -p /etc/systemd/system/docker.service.d/
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        echo "/etc/systemd/system/docker.service.d/http-proxy.conf 文件存在"
    else
        if [[ "$proxy_env" == "dmz" ]] ; then
        
        cat << EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$DMZ_PROXY_HTTP"
Environment="HTTPS_PROXY=$DMZ_PROXY_HTTPS"
Environment="NO_PROXY=127.0.0.1,localhost,10.67.0.0/16"
EOF
        else
        
        cat << EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PRC_PROXY"
Environment="HTTPS_PROXY=$PRC_PROXY"
Environment="NO_PROXY=127.0.0.1,localhost,10.67.0.0/16"
EOF
        fi
    fi
mkdir -p /etc/docker/ 
    if [ -f /etc/docker/daemon.json ]; then
        echo "/etc/docker/daemon.json 文件存在"
    else
        cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],

  "registry-mirrors": ["http://$dockermirror"],
  "insecure-registries": ["$dockermirror", "docker.io", "gcr.io", "k8s.gcr.io"]
}
EOF

    fi

mkdir -p $HOME/.docker 
    if [ -f $HOME/.docker/config.json ]; then
        echo "$HOME/.docker/config.json 文件存在"
    else
        if [[ "$proxy_env" == "dmz" ]] ; then
            cat << EOF > $HOME/.docker/config.json
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "$DMZ_PROXY_HTTP",
     "httpsProxy": "$DMZ_PROXY_HTTPS",
     "noProxy": "localhost,127.0.0.0/8,10.67.0.0/16,10.239.0.0/16"
   }
 }
}
EOF
        else
            cat << EOF > $HOME/.docker/config.json
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "$PRC_PROXY",
     "httpsProxy": "$PRC_PROXY",
     "noProxy": "localhost,127.0.0.0/8,10.67.0.0/16,10.239.0.0/16"
   }
 }
}
EOF
        fi



    fi

}

install_docker() {

if [[ "$docker_ver" != "" ]] ; then
    apt install  docker-ce=$docker_ver docker-ce-cli=$docker_ver
else
    apt install  docker-ce docker-ce-cli
fi

}


apt update -y
apt install -y --no-install-recommends apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

install_docker
echo $proxy_env
set_proxy $dockermirror $proxy_env
