#!/bin/bash
set -ex
if [[ ! -f packer ]]; then
    curl -o packer.zip https://releases.hashicorp.com/packer/1.5.5/packer_1.5.5_linux_amd64.zip
    unzip packer.zip
    rm packer.zip
fi

BOX_NAME="boxes/ci-centos${1}-${2}.box"

echo "Building vagrant box $BOX_NAME"
./packer build -var "centos=${1}" -var "contents=${2}" template.json
mv output/package.box $BOX_NAME
rm -rf output
