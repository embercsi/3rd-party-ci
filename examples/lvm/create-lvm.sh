#!/bin/env bash
set -e

# Accept loop devices for the LVM ember-volumes VG and reject anything else
sed -i "s/# global_filter =.*/filter = [ \"a|loop|\", \"r|.*\\/|\" ]\n\tglobal_filter = [ \"a|loop|\", \"r|.*\\/|\" ]/" /etc/lvm/lvm.conf

# Workaround for lvcreate hanging inside contatiner
# https://serverfault.com/questions/802766/calling-lvcreate-from-inside-the-container-hangs
sed -i "s/udev_sync = 1/udev_sync = 0/" /etc/lvm/lvm.conf
sed -i "s/udev_rules = 1/udev_rules = 0/" /etc/lvm/lvm.conf

# Create 10G thin file
truncate -s 10G /root/ember-volumes

# Create loopback device
lodevice=`losetup --show -f /root/ember-volumes`

# Create a Volume Group called ember-volumes
vgcreate ember-volumes $lodevice

# Ensure LVM knows about the new VG
vgscan --cache
