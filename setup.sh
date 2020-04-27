#!/bin/bash
# Setup script for Ember-CSI 3rd-party CI systems
#
# Requirements:
#  - Centos 7
#  - Passwordless dudo
#
# Invocation:
#    setup.sh runner_name registration_token [backends]
# Examples:
#  $ setup.sh Kaminario ABNHOFIUN7L7IQFYQRSUKXK6UGAF4
#  $ setup.sh 3PAR ABNHOFIUN7L7IQFYQRSUKXK6UGAF4 3PAR_iSCSI,3PAR_FC
#
# TODO:
#  - Test the script and confirm that no reboot is necessary for the runner to
#    run containers with the provided user
#  - Support setting up multipler runners
#  - Support restoring from saved config file
set -e

RUNNER_NAME=$1
TOKEN=$2
RUNNER_BACKENDS=${3:-$RUNNER_NAME}

VAGRANT_HOME=`pwd`/.vagrant.d
SERVICE_NAME="actions.runner.embercsi.$RUNNER_NAME"
# VAGRANT_DEFAULT_PROVIDER=libvirt
# VAGRANT_FORCE_COLOR=true
# VAGRANT_CWD
# VAGRANT_VAGRANTFILE


echo "Installing docker-ce"
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum -y install docker-ce
sudo usermod -aG docker $(whoami)
sudo systemctl enable docker


echo "Installing QEMU and libvirt"
sudo yum -y install qemu-kvm libvirt
sudo systemctl enable --now libvirtd
sudo usermod --append --groups libvirt `whoami`


echo "Checking nested virtualization"
if [[ "N" == `cat /sys/module/kvm_intel/parameters/nested` ]]; then
    echo "Enabling nested virtualization"
    if [[ ! -f /etc/modprobe.d/kvm-nested.conf ]]; then
        echo "Creating nested config"
        echo -e "options kvm-intel nested=1\noptions kvm-intel enable_shadow_vmcs=1\noptions kvm-intel enable_apicv=1\noptions kvm-intel ept=1" | sudo tee /etc/modprobe.d/kvm-nested.conf
    fi
    echo "Restarting kvm_init module"
    sudo modprobe -r kvm_intel || true
    sudo modprobe -a kvm_intel
    if [[ "N" == `cat /sys/module/kvm_intel/parameters/nested` ]]; then
        echo "Failed to enable nested virtualization" > /dev/stderr
        exit 1
    fi
fi


echo "Installing Vagrant "
# Check if we are running inside a Vagrant VM and set the default network accordingly
if [[ ! -f user-files/vagrant-network.sh ]]; then
    if /sbin/ip -o -4 addr list eth0 | grep '192.168.121.'; then
        vagrant_network='192.168.122.0/24'
    else
        vagrant_network='192.168.121.0/24'
    fi

    echo -e "#!/bin/bash\necho -n $vagrant_network" > ci-scripts/vagrant-network.sh
    chmod +x user-files/vagrant-network.sh
fi

sudo yum -y install gcc libvirt-devel https://releases.hashicorp.com/vagrant/2.2.7/vagrant_2.2.7_x86_64.rpm
vagrant plugin install vagrant-libvirt
mkdir $VAGRANT_HOME


echo "Installing runner on `pwd`/actions-runner"
mkdir actions-runner
cd actions-runner
curl -o action-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.169.1/actions-runner-linux-x64-2.169.1.tar.gz
tar xzf action-runner.tar.gz
rm action-runner.tar.gz
sudo ./bin/installdependencies.sh

echo "Configuring runner $RUNNER_NAME for backends $RUNNER_BACKENDS"
./config.sh --url https://github.com/embercsi --token $TOKEN --unattended --name $RUNNER_NAME --labels $RUNNER_BACKENDS

cd ..

# Create the templates for the backend configuration
for backend in $(echo $RUNNER_BACKENDS | sed "s/,/ /g"); do
  USER_SCRIPTS_DIR=`pwd`/${backend}-files
  mkdir $USER_SCRIPTS_DIR
  cp -rn ../user-files/. $USER_SCRIPTS_DIR
done
# Add the CI scripts path to the runner's job PATH so the CI can use them
sed -i "s#:/#:$(realpath `pwd`/../ci-scripts):/#" .path

sudo actions-runner/svc.sh install
sudo systemctl start $SERVICE_NAME
# bash -c "sudo ./svc.sh start"


echo "Backing up configuration"
CFG_BACKUP_FILE="$RUNNER_NAME_ember-csi_config.tar.gz"
tar czf ../$CFG_BACKUP_FILE .credentials .credentials_rsaparams .env .path .runner .service

echo -e "Done.\nRunner's info:\n\tService: ${SERVICE_NAME}.service\n\tLogs: sudo journalctl -fu $SERVICE_NAME\n\tBacked up config: $(realpath `pwd`/../$CFG_BACKUP_FILE)"

echo -e "Please edit files in ./{${RUNNER_BACKENDS},} to add your configuration and pre and post steps"
