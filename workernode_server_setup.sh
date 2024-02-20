#!/bin/bash
## This script is used to setup a Ubuntu 22.04.4 LTS Server from a fresh install for k8s as a master/control-plane node

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
sudo ufw allow 10250/tcp # k8s Kubelet API
sudo ufw allow 30000-32767/tcp # k8s NodePort Services

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
# Install kubelet and kubeadm (kubeadm is only needed to join this worker node to the cluster)
sudo apt-get install -y kubelet kubeadm
# Enable kubelet to start on boot
sudo systemctl enable kubelet

# Remove the iptables rules that were added by the k8s installation
sudo rm -rf ~/.iptables-backup.txt

# Echo a colorful success message to the user and explain the next steps
echo $'\nThe server setup has been successful! The server is now ready to be used as a k8s control-plane node.'
echo -e "\033[1;35m\nRun \`\033[1;33mkubeadm token create --print-join-command\033[1;35m\` on the master/control-plane node to output the kubeadm join command.\033[0m"
echo -e "\033[1;35mThen, copy that join command which looks something like this:\033[1;35m"
echo -e "\033[0;36m\n kubeadm join <ip_address>:6443 --token <string_of_random_characters> --discovery-token-ca-cert-hash sha256:<long_string_of_random_characters>\033[0m"
echo -e "\033[1;35m\n...And run the join command on THIS machine to join the cluster as a worker node.\n\033[1;35m"