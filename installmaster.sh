
#!/bin/bash

sudo hostnamectl set-hostname master

# hosts file
sudo tee /etc/hosts<<EOF
192.168.20.15 master
192.168.20.23 worker1
127.0.0.1 localhost
EOF

sudo apt update -y



# 2) Install kubelet, kubeadm and kubectl - chú ý UBUNTU 22.04
# Once the servers are rebooted, add Kubernetes repository for Ubuntu 22.04 to all the servers.
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Then install required packages.
sudo apt update
sudo apt install wget curl vim git -y

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Confirm installation by checking the version of kubectl.
kubectl version --client && kubeadm version

# 3) Disable Swap Space
# Disable all swaps from /proc/swaps.
sudo swapoff -a
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab

# Enable kernel modules and configure sysctl.

# Configure persistent loading of modules
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Load at runtime
sudo modprobe overlay
sudo modprobe br_netfilter

# Ensure sysctl params are set
sudo tee /etc/sysctl.d/k8s.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload configs
sudo sysctl --system

# Install required packages
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd and start service
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5) Initialize control plane (run on first master node)
# Login to the server to be used as master and make sure that the br_netfilter module is loaded:

lsmod | grep br_netfilter


# We now want to initialize the machine that will run the control plane components which includes etcd (the cluster database) and the API Server.
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket /run/containerd/containerd.sock \
  --apiserver-advertise-address=192.168.20.15 --ignore-preflight-errors=all

# Configure kubectl using commands in the output:
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Cài CNI Flanel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

Đang hiển thị 6054938872935824619.