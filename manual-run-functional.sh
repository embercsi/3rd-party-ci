#!/bin/bash
# Example: SSH_ON_ERROR=1 CSI_SPEC_VERSION=v0.3 EMBER_IMAGE=docker.io/embercsi/ci_images:129-4ffa67e941dae2476c1beaae91200a875fc763ca-7 ./manual-run-functional.sh
set -e

export BACKEND_NAME=${BACKEND_NAME:-lvm}
export CENTOS_VERSION=${CENTOS_VERSION:-7}
export CSI_SPEC_VERSION=${CSI_SPEC_VERSION:-v1.1}
export EMBER_IMAGE=${EMBER_IMAGE:-docker.io/embercsi/ember-csi:master-${CENTOS_VERSION}}
export JOB_NAME=${JOB_NAME:-"3rdparty/${BACKEND_NAME}/functional-centos${CENTOS_VERSION}-csi_${CSI_SPEC_VERSION}"}
export JOB_ID=manual
# We can set SSH_ON_ERROR env var to explore the VM on failure
export SSH_ON_ERROR=${SSH_ON_ERROR:-""}
export DEBUG=1

SCRIPT_DIR="$(dirname `realpath $0`)"
export PATH=$PATH:$SCRIPT_DIR/${BACKEND_NAME}-files

mkdir -p manual-run
cd manual-run
if [[ ! -d 3rd-party-ci ]]; then
    git clone --depth=1 --branch=gh-actions https://github.com/embercsi/3rd-party-ci.git
    cd 3rd-party-ci
else
    cd 3rd-party-ci
    git remote update
    git reset --hard @{u}
fi

./ci-scripts/vm-run-functional.sh
