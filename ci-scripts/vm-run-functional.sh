#!/bin/bash
# Parameters come via env variables:
#     EMBER_IMAGE
#     BACKEND_NAME
#     CENTOS_VERSION
#     JOB_ID
set -e
set -x
echo "Running Ember-CSI functional tests on CentOS ${CENTOS_VERSION} on backend ${BACKEND_NAME} for job ${JOB_ID} with container ${EMBER_IMAGE}"

config_path=`backend-config-path.sh ${BACKEND_NAME}`
echo "Backend configuration is located at $config_path"

SCRIPT_DIR=$(dirname `realpath $0`)
# This is the script we want vagrant to run
ln -s ./run-functional.sh $SCRIPT_DIR/run.sh

export EMBER_VAGRANT_IMAGE="ember-csi/ci-centos${CENTOS_VERSION}-base"
export EMBER_VAGRANT_MEMORY=4096
export EMBER_VAGRANT_CPUS=2
export EMBER_VAGRANT_CONFIG_DIR=$config_path
export EMBER_VAGRANT_WORKER="functional${CENTOS_VERSION}-${BACKEND_NAME}-${JOB_ID}"

# This needs to be called before we set env vars or vagrant won't find the box
# version to delete
${SCRIPT_DIR}/update-box.sh $EMBER_VAGRANT_IMAGE

BASE_DIR=`realpath $SCRIPT_DIR/../`
mkdir $BASE_DIR/artifacts

echo "Running $WORKER VM"

export VAGRANT_FORCE_COLOR=true
export VAGRANT_CWD=$BASE_DIR
export VAGRANT_VAGRANTFILE=Vagrantfile.template

# The vagrant template uses the same env variables this script does
if vagrant up; then
    echo "Successful run"
else
    result=$?
    echo "Failed run"
fi

echo "Generated artifacts: `ls $BASE_DIR/artifacts`"
vagrant destroy -f

exit $result
