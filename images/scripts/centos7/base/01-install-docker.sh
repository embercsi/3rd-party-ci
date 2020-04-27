#!/bin/bash
echo "Installing docker-ce"
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum -y install docker-ce
sudo usermod -aG docker $(whoami)
sudo systemctl enable docker
