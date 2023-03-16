The installation was verified on ubuntu 22.0.4 and centos 8 

#  usage:
Please use an account with root privileges to execute the command.
```
git clone --recurse-submodules https://github.com/intel-sandbox/wielabmanager.git
cd wielabmanager/init_k8
PRC_PROXY="http://child-prc.intel.com:913" && bash install.sh --ver=1.23.3 --cri=docker --net=calico --role=master 
```
Note:that the **PRC** proxy mode is used by default

Command line supported arguments

--ver ==> Kubernetes Version

--cri ==> containerd / cri-o / docker

--net ==> calico / flannel / weavenet

--role ==> master / worker

# ubuntu
If you want to query the installable version of kubeadm on ubuntu, you can use the following command on a machine that has been successfully installed.

```
apt-cache madison kubeadm
apt-cache madison docker-ce
```
# centos
List and sort the versions available in your repo. This example sorts results by version number, highest to lowest, and is truncated:
```
yum list docker-ce --showduplicates | sort -r
yum list --showduplicates kubeadm --disableexcludes=kubernetes
```
