# Kube-Platform
Vanila Kubernetes Platform

## Prepare ALL Servers for Kubernetes (K8s)
OS ```centos 7``` to be ready before hand to start kubernetes deployment using kubeadm


### Step #1
Stopping and disabling firewalld by running the commands on all servers:
```
systemctl stop firewalld
systemctl disable firewalld
```

### Step #2
Next, let’s disable swap. Kubeadm will check to make sure that swap is disabled when we run it, 
so lets turn swap off and disable it for future reboots.

```
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
```

### Step #3
Now we’ll need to disable SELinux if we have that enabled on our servers. I’m leaving it on, but setting it to Permissive mode.

```
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

### Step #4
Next, we’ll add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 
To do this we’ll create a file in the /etc/yum.repos.d directory. The code below will do that for you.

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
```
###  Step #5
Install some of the tools we’ll need on our servers including kubeadm, kubectl, kubelet, and docker.

```yum install -y git curl wget docker```

#### Docker log setup
Installing docker in CentOS 7, which force docker to run log output to journald. The default behavior is to write these logs to json.log files. So, need to remove ```--log-driver=journald``` by modifying ```/etc/sysconfig/docker``` file in ```OPTION``` section.

Modify ```/etc/sysconfig/docker``` file as follows.

```
OPTIONS='--selinux-enabled --signature-verification=false'
#OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false'
```

##### Step #5.a To know version details

```curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more```

##### Step #5.b Installation with speceifc version (1.11.5)
```yum install -y kubelet-1.11.5 kubeadm-1.11.5 kubectl-1.11.5 kubernetes-cni-0.6.0 --disableexcludes=kubernetes```

##### Note: If you face any problem (getting error during installation) check ```Kubernetes CNI``` version

#### Installation with latest version
```yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes```

### Step #6
After installing docker and our kubernetes tools, we’ll need to enable the services so that they persist across reboots, 
and start the services so we can use them right away.

```
systemctl enable docker; systemctl start docker
systemctl enable kubelet; systemctl start kubelet
```

### Step #7
Before we run our kubeadm setup we’ll need to enable iptables filtering so proxying works correctly. 
To do this run the following to ensure filtering is enabled and persists across reboots.

```
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
systemctl restart docker
```

## Setup Kubernetes Cluster on Master Node

### Step #1
Setup Kubernetes Cluster on Master Node
We’re about ready to initialize our kubernetes cluster but I wanted to take a second to mention that we’ll be using Flannel as the network plugin to enable our pods to communicate with one another. You’re free to use other network plugins such as Calico or Cillium but this post focuses on the Flannel plugin specifically.

Let’s run kubeadm init on our master node with the –pod-network switch needed for Flannel to work properly.

```kubeadm init --pod-network-cidr=10.244.0.0/16```

### Step #2
Setup environment

```
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes
```
### Step #3
Deploying network components Flannel

```
wget https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
kubectl create -f kube-flannel.yml
```

### Step #4
Deploying Dashboard

```
wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl create -f kubernetes-dashboard.yaml
```

## Node Setup

After the initialization is complete you should have a working kubernetes master node setup. 
Below is sample, you have to take output of ```Step #8```

```kubeadm join 10.128.0.35:6443 --token 1cwfqy.t8955yqboh8jiina --discovery-token-ca-cert-hash sha256:3a4b397a3453932f41374ab48b24397c72b281db696c71a6ec530ac1243d5a29```
