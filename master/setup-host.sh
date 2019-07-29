#!/bin/env bash
set -e

DEFAULT_FILE='config.py'
REQUIRED_VARIABLES="SMEE_ID DRIVER_NAME_1 GH_TOKEN GH_EMBER_SECRET DRIVER_CONFIG_1"

die() { echo "$*" 1>&2 ; exit 1; }
get_var() { if [ -z "$1" ]; then echo "$2"; else echo "$1"; fi }


CONFIG_FILE=$(get_var $1 $DEFAULT_FILE)

if [ ! -e "$CONFIG_FILE" ]; then
    if [ -z "$1" ]; then
        die "Error: Config file not provided and default file ($DEFAULT_FILE) doesn't exit"
    else
        die "Error: File $CONFIG_FILE doesn't exist"
    fi
fi

. "$CONFIG_FILE"

# Ensure required paramters are present
for variable in $REQUIRED_VARIABLES; do
  [ -z "${!variable}" ] && die "Missing $variable"
done

# Set default values for optional parameters
CI_DIR=$(realpath $(get_var $CI_DIR '/buildbot'))
NUM_WORKERS=$(get_var $NUM_WORKERS 1)
NUM_DRIVERS=$(get_var $NUM_DRIVERS 1)
WORKER_NAME=$(get_var $WORKER_NAME 'libvirt')
WORKER_PASSWORD=$(get_var $WORKER_PASSWORD 'password')
WEB_PORT=$(get_var $WEB_PORT 8010)

# If workers need to have access to network outside of this host then
# BRIDGE_INTERFACE and/or BRIDGE_NAME parameters must be set.
[ ! -z BRIDGE_INTERFACE ] && BRIDGE_NAME=$(get_var $BRIDGE_NAME 'ember_ci_bridge')

# Set default web address.  Configured parameter, IP from bridge or localhost.
if [ -z "$WEB_ADDR" ]; then
    if [ -z "$BRIDGE_INTERFACE" ]; then
        WEB_ADDR='localhost'
    else
        WEB_ADDR=$(ip addr show $BRIDGE_INTERFACE | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
    fi
fi

# Set hardcoded variables
BUILDBOT_DB_URL="sqlite:///$CI_DIR/database.sqlite"
BUILDBOT_WORKER_PORT=9989
WORKER_IMAGE=$CI_DIR/worker.qcow2
WORKER_IMAGE_URL='https://www.dropbox.com/s/ilq8nuk6k9sp5me/worker.qcow2?dl=0'
CLOUD_INIT_DIR=$CI_DIR/cloud_init
METADATA_FILE=$CLOUD_INIT_DIR/meta-data
USERDATA_FILE=$CLOUD_INIT_DIR/user-data
SSH_KEY=~/.ssh/id_rsa.pub

echo "Installing packages"
yum install -y epel-release gcc openssl-devel git
yum install -y python36 python36-devel python36-pip

echo "Setting up KVM and Libvirt"
yum install -y qemu-kvm libvirt libguestfs-tools virt-install libvirt-devel
pip3 install libvirt-python

systemctl enable --now libvirtd

echo "Downloading worker image"
mkdir -p $(dirname $WORKER_IMAGE)

if test -e "$WORKER_IMAGE"
then zflag="-z $WORKER_IMAGE"
else zflag=
fi
curl -R $zflag -Lo $WORKER_IMAGE $WORKER_IMAGE_URL

if [ ! -z "$BRIDGE_INTERFACE" ]; then
    echo "Setting up Worker VMs' bridge to $BRIDGE_INTERFACE"
    echo "BRIDGE=$BRIDGE_NAME" >> /etc/sysconfig/network-scripts/ifcfg-$VM_BRIDGE
    echo -e DEVICE="$BRIDGE_NAME"\\nBOOTPROTO="dhcp"\\nIPV6INIT="yes"\\nIPV6_AUTOCONF="yes"\\nONBOOT="yes"\\nTYPE="Bridge"\\nDELAY="0" > /etc/sysconfig/network-scripts/ifcfg-$BRIDGE_NAME
    systemctl restart network
fi

[ ! -z "$BRIDGE_NAME" ] && bridge_param="--network bridge:$BRIDGE_NAME"

get_param () {
  value=${!1}
  [ -e "$value" ] && value=$(realpath "$value")
  echo "$value"
}

cd $(dirname $CONFIG_FILE)
DRIVERS='[\n'
for i in `seq 1 $NUM_DRIVERS`; do
    DRIVERS+="{'name': '''$(get_param "DRIVER_NAME_$i")''', 'pre': '''$(get_param "PRE_RUN_$i")''', 'config': '''$(get_param "DRIVER_CONFIG_$i")''', 'post': '''$(get_param "POST_RUN_$i")'''},\n"
done
DRIVERS+=']'
cd -

mkdir -p $CLOUD_INIT_DIR

VMS_XMLS='[\n'
for i in `seq 0 $(expr $NUM_WORKERS - 1)`; do
  name=${WORKER_NAME}$i
  cloud_init_iso=$CI_DIR/$name.iso

  echo "Generating VM's cloud-init for $name"
  METADATA="instance-id: $name\nlocal-hostname: $name"
  if [ -e "$SSH_KEY" ]; then
      echo "Injecting public ssh to worker from $(realpath '$SSH_KEY')"
      METADATA="$METADATA\npublic-keys:\n  - $(cat $SSH_KEY)"
  fi
  echo -e "$METADATA" > $METADATA_FILE

  USERDATA="#cloud-config

write_files:
  - path: /root/buildbot/config.py
    content: |
      PORT = '$BUILDBOT_WORKER_PORT'
      PASSWORD = '$WORKER_PASSWORD'
      WORKER_NAME = '$name'
  - path: /etc/iscsi/initiatorname.iscsi
    content: InitiatorName=iqn.1994-05.com.redhat:$name
runcmd:
  - systemctl restart iscsid
"

  if [ ! -e $SSH_KEY ]; then
      echo 'Enabling password access to worker'
      USERDATA="$USERDATA\npassword: $WORKER_PASSWORD\nchpasswd: { expire: False }\nssh_pwauth: True"
  fi

  echo -e "$USERDATA" > $USERDATA_FILE

  (cd $CLOUD_INIT_DIR && genisoimage -o $cloud_init_iso -V cidata -r -J meta-data user-data)

  echo "Generating VM's XML for $name"

  qemu-img create -f qcow2 -o backing_file=$WORKER_IMAGE $WORKER_IMAGE.$name
  VM_XML=$(virt-install \
    --name $name \
    --description "Buildbot libvirt worker" \
    --os-type=Linux \
    --os-variant=centos7.0 \
    --ram=1024 \
    --vcpus=2 \
    --disk path=$WORKER_IMAGE.$name,bus=virtio \
    --disk path=$cloud_init_iso,device=cdrom \
    --boot hd \
    --graphics none \
    --print-xml)
  rm $WORKER_IMAGE.$name
  [ -z "$VM_XML" ] && die "Error generating VM's XML"
  VMS_XMLS+="'''$VM_XML''',\n"
done
VMS_XMLS+=']'

echo "Installing additional packages for buildbot"
# txrequests for GitHubStatusPush
# ansi2html to convert logs to html
# GitPython to upload logs to github
pip3 install GitPython txrequests ansi2html

echo "Installing buildbot from pypi"
pip3 install 'buildbot[bundle]' txrequests

# Set buildbot master configuration
echo "Configuring buildbot"
mkdir -p $CI_DIR
cp master.cfg $CI_DIR
cp buildbot.tac $CI_DIR//buildbot.tac
echo -e \
"BUILDBOT_WEB_URL = 'http://$WEB_ADDR'
BUILDBOT_WEB_PORT = '$WEB_PORT'
BUILDBOT_DB_URL = '$BUILDBOT_DB_URL'
BUILDBOT_WORKER_PORT = '$BUILDBOT_WORKER_PORT'
IMAGE_LOCATION = '$WORKER_IMAGE'
NUM_WORKERS=$NUM_WORKERS
WORKER_NAME='$WORKER_NAME'
WORKER_PASSWORD = '$WORKER_PASSWORD'
GH_TOKEN = '$GH_TOKEN'
GH_USER = '$GH_USER'
GH_EMBER_SECRET = '$GH_EMBER_SECRET'
DRIVERS = $DRIVERS
WORKERS_XML = $VMS_XMLS" > $CI_DIR/params.py

echo "Enabling buildbot service"
cp buildbot.service.template /etc/systemd/system/buildbot.service
sed -i s#{{WORKING_DIRECTORY}}#$CI_DIR# /etc/systemd/system/buildbot.service
/usr/local/bin/buildbot upgrade-master $CI_DIR
systemctl enable --now buildbot.service

echo "Installing the smee.io python client"
pip3 install pysmee

echo "Enable listeting to Ember-CSI GitHub changes"
cp smee.service.template /etc/systemd/system/smee.service
sed -i s/{{SMEE_ID}}/$SMEE_ID/ /etc/systemd/system/smee.service
sed -i s/{{ADDRESS}}/$WEB_ADDR/ /etc/systemd/system/smee.service
sed -i s/{{PORT}}/$WEB_PORT/ /etc/systemd/system/smee.service
systemctl enable --now smee.service
