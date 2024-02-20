#!/bin/bash
## This script is used to setup a Ubuntu 22.04 server from a fresh install for k8s as a master/control-plane node

# TODO: Add a check to see if the script is being run as root
# TODO: Add a check to see if the script is being run on a supported version of Ubuntu (22.04.4 LTS Server)
# TODO: Add a check to see if the script is being run on a supported architecture (amd64, arm64, armhf)
# TODO: Add a check to see if the script is being run on a supported kernel version (5.15.0-94-generic)
# TODO: Add a check to see if the system has at least 8GB of RAM
# TODO: Add a check to see if the system has at least 4 CPU cores
# TODO: Add a check to see if the system already has Docker running, and if so, ask the user if they want to proceed with stopping it and removing it in order to install the latest version of Docker
# TODO: Add a check to see if the system already has k8s installed, and if so, ask the user if they want to proceed with removing it in order to install the specified version of k8s
# TODO: Add a check to see if the system already has iptables rules that conflict with the ones that will be added by the k8s installation, and if so, ask the user if they want to proceed with removing them
# TODO: Add a check to see if the system already has a swap file, and if so, ask the user if they want to proceed with disabling it since it's necessary for the k8s installation

# Update and upgrade the system
sudo apt update -y && sudo apt upgrade -y

# Configure firewall rules
sudo ufw allow 6443/tcp # k8s API server
sudo ufw allow 8443/tcp # k8s API server
sudo ufw allow 2379:2380/tcp # etcd server client API
sudo ufw allow 10250/tcp # k8s Kubelet API
sudo ufw allow 10259/tcp # kube-scheduler
sudo ufw allow 10257/tcp # kube-controller-manager
sudo ufw allow 179/tcp # BGP (calico)
sudo ufw allow 5473/tcp # calico
sudo ufw allow 4789 # calico
sudo ufw allow 443 # HTTPS
sudo ufw allow 80 # HTTP

# Make a backup copy of the current iptables rules in case something goes wrong
sudo iptables-save > ~/.iptables-backup.txt

# Uninstall potentially conflicting packages of older versions of Docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
# Install Docker
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Remove the existing containerd configuration file installed by Docker (if it exists)
sudo rm -rf "/etc/containerd/config.toml"
# Replace with the default containerd configuration file
sudo su
containerd config default > "/etc/containerd/config.toml"
exit

# Use sed to find and replace the strings in the config.toml file
CONTAINERD_CONFIG_FILE="/etc/containerd/config.toml"
if [ -f "$CONTAINERD_CONFIG_FILE" ]; then
    sudo sed -i 's|SystemdCgroup = false|SystemdCgroup = true|g' "$CONTAINERD_CONFIG_FILE" # Enable SystemdCgroup
    sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.9"|g' "$CONTAINERD_CONFIG_FILE" # Use the version of the pause image that is compatible with k8s
else
    echo "Error: $CONTAINERD_CONFIG_FILE does not exist."
fi

# Enable containerd to start on boot
sudo systemctl enable containerd
# Restart containerd
sudo systemctl restart containerd

# Disable swap - works on Ubuntu 22.04.4 LTS Server (not tested on other versions)
sudo sed -i 's|^[^#]*/swap.img*|#&|' /etc/fstab # Comments out the swap line in /etc/fstab (if not already commented out) to prevent swap from being enabled on boot
sudo swapoff -a # Disables swap for the current session

# Prepare the system for k8s installation
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
# Get the k8s gpg key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# Update the system with the new repository
sudo apt-get update
# Install kubectl and kubelet and kubeadm (kubeadm is only needed to join this worker node to the cluster)
sudo apt-get install -y kubectl kubelet kubeadm
# Enable kubelet to start on boot
sudo systemctl enable kubelet

# Configure crictl.yaml - add the runtime-endpoint and image-endpoint to the file if they don't already exist
CRICCTL_CONFIG_FILE="/etc/crictl.yaml"
if [ -f "$CRICCTL_CONFIG_FILE" ]; then
    if ! grep -qxF "runtime-endpoint: unix:///run/containerd/containerd.sock" "$CRICCTL_CONFIG_FILE"; then
      echo "runtime-endpoint: unix:///run/containerd/containerd.sock" >> "$CRICCTL_CONFIG_FILE"
    fi
    if ! grep -qxF "image-endpoint: unix:///run/containerd/containerd.sock" "$CRICCTL_CONFIG_FILE"; then
      echo "image-endpoint: unix:///run/containerd/containerd.sock" >> "$CRICCTL_CONFIG_FILE"
    fi
else
    sudo touch "$CRICCTL_CONFIG_FILE"
    sudo echo "runtime-endpoint: unix:///run/containerd/containerd.sock" >> "$CRICCTL_CONFIG_FILE"
    sudo echo "image-endpoint: unix:///run/containerd/containerd.sock" >> "$CRICCTL_CONFIG_FILE"
fi

# Initialize the k8s cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Install calicoctl kubectl plugin
cd /usr/local/bin/
sudo curl -L https://github.com/projectcalico/calico/releases/download/v3.27.2/calicoctl-linux-amd64 -o kubectl-calico
sudo chmod +x kubectl-calico
cd ~
kubectl plugin list # Verify that the kubectl-calico plugin is installed

# Remove taint from the control-plane node (optional) - only recommended for small clusters that have less than 5 nodes.
# For clusters with 5 or more nodes, keep the taint to reduce the risk of the control-plane node being overwhelmed by workloads.
sudo kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# This is the same command but it's used for older versions of k8s
sudo kubectl taint nodes --all node-role.kubernetes.io/master- # May return an error when run on new versions of k8s, but that's okay. Just ignore it.

# Remove the iptables rules that were added by the k8s installation
sudo rm -rf ~/.iptables-backup.txt

# Echo a colorful success message to the user and print the kubeadm join command for joining worker nodes to the cluster
echo $'\nThe server setup has been successful! The server is now ready to be used as a k8s control-plane node.'
echo -e "\033[1;35m\nRun the following command on the worker node to join it to the cluster:\n\033[1;35m"
KUBEADM_JOIN_CMD=$(kubeadm token create --print-join-command)
echo -e "\033[0;36m$KUBEADM_JOIN_CMD\n\033[0;36m"