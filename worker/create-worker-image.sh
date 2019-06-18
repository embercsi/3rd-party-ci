#!/bin/env bash
# This script uses guestfish to build the worker qcow2 image used by Ember-CSI
# 3rd party CI jobs.
# Requires libvirtd, kvm, etc. to be installed
#   yum install -y qemu-kvm libvirt libguestfs-tools virt-install
#   systemctl enable --now libvirtd
# In the future we may use CentOS Composer or Kickstart to get a tailor-made
# image.
set -e

IMAGE_LOCATION=$(realpath ${IMAGE_LOCATION:-../images})
CENTOS_IMAGE=$IMAGE_LOCATION/centos.qcow2
WORKER_IMAGE=$IMAGE_LOCATION/worker.qcow2
WORKER_STEP_IMAGE=$IMAGE_LOCATION/worker-step.qcow2

CENTOS_IMAGE_URL=https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2c

echo "Downloading Centos Base image from $CENTOS_IMAGE_URL"
mkdir -p $IMAGE_LOCATION

# Donwload Centos image if it's newer than the one we have
if test -e "$CENTOS_IMAGE"
then zflag="-z $CENTOS_IMAGE"
else zflag=
fi
curl -R $zflag -o "$CENTOS_IMAGE" "$CENTOS_IMAGE_URL"

# First step is to build the Python packages
echo "Compiling Python libraries into wheel"
qemu-img create -f qcow2 -o backing_file=$CENTOS_IMAGE $WORKER_STEP_IMAGE
chmod 0666 $WORKER_STEP_IMAGE

# If we have trouble installing from EPEL because the mirrors have corrupted
# DBs we can add these 2 lines to both guestfish scripts to work around it:
# sh "sed -i 's/metalink/#metalink/g' /etc/yum.repos.d/epel.repo"
# sh "sed -i 's/#baseurl/baseurl/g' /etc/yum.repos.d/epel.repo"
guestfish --rw --selinux --network -i -a $WORKER_STEP_IMAGE <<__EOF__
echo Enabling epel and compiler packages
sh "yum install -y epel-release gcc openssl-devel"
echo Installing Python3 and its development package
sh "yum install -y python36 python36-devel python36-pip"
echo Installing wheel
sh "pip3 install wheel"
echo Generating wheel files for buildbot-worker
sh "pip3 wheel --no-cache-dir --wheel-dir=/tmp/dist buildbot-worker"
echo Downloading wheel files to local directory $IMAGE_LOCATION
tar-out /tmp/dist $IMAGE_LOCATION/wheel.tar.gz compress:gzip
__EOF__

rm $WORKER_STEP_IMAGE

# Second step is to create the actual worker image
echo -e "\n\nCreating buildbot worker image"
qemu-img create -f qcow2 -o backing_file=$CENTOS_IMAGE $WORKER_STEP_IMAGE
chmod 0666 $WORKER_STEP_IMAGE

# If we need to resize the image
# qemu-img resize $WORKER_IMAGE 20G

# Changes to /etc/yum.repos.d/epel.repo are because the mirrors are giving
# trouble
# TODO(geguileo): Use non-root user/directory
# Changes to /etc/yum.repos.d/epel.repo are because the mirrors are giving
# trouble
guestfish --rw --selinux --network -i -a $WORKER_STEP_IMAGE <<__EOF__
echo Enabling epel and installing git
sh "yum install -y epel-release git"
echo Installing Python3, docker, iscsid, and multipathd
sh "yum install -y python36 python36-pip docker iscsi-initiator-utils device-mapper-multipath"
sh "mpathconf --enable --with_multipathd y --user_friendly_names n --find_multipaths y"
sh "systemctl enable multipathd"
sh "systemctl enable iscsid"
sh "systemctl enable docker"
sh "echo -e '\nnetwork: {config: disabled}' >> /etc/cloud/cloud.cfg"
echo Installing buildbot-worker from local wheel
mkdir /tmp/dist
echo Uploading wheel files from $IMAGE_LOCATION
tar-in $IMAGE_LOCATION/wheel.tar.gz /tmp/dist compress:gzip
sh "pip3 install wheel"
sh "pip3 install --use-wheel --no-index --no-cache-dir --find-links=/tmp/dist buildbot-worker"
mkdir /root/buildbot
upload buildbot.tac /root/buildbot/buildbot.tac
upload buildbot.service /etc/systemd/system/buildbot.service
sh "systemctl enable buildbot.service"
echo Cleaning up
sh "yum clean all && rm -rf /var/cache/yum && rm -rf /tmp/*"
echo Setting permissive SELinux
sh "/bin/sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config"
copy-in ./root/ /
__EOF__

echo "Flattening and reducing image size"
virt-sparsify --compress $WORKER_STEP_IMAGE $WORKER_IMAGE

echo "Cleaning up temporary files"
rm $WORKER_STEP_IMAGE
rm $IMAGE_LOCATION/wheel.tar.gz

echo "Image $WORKER_IMAGE is ready"
