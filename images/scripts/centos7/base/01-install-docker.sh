#!/bin/bash
set -e
echo "Installing docker-ce"
sudo curl https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
sudo yum -y install docker-ce
sudo usermod -aG docker $(whoami)
sudo systemctl enable docker
