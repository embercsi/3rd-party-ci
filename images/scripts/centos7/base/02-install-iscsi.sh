#!/bin/bash
echo "Installing iSCSI"
sudo yum install -y iscsi-initiator-utils
sudo systemctl enable iscsid
