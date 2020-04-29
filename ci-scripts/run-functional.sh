#!/bin/bash
# This script is run inside the VM when we run vagrant up and receives the
# following parameters:
#      container_image
#      job_name
#      job_id
#      backend_name
set -e
set -x

SCRIPT_DIR=$(dirname `realpath $0`)

# Set env vars for user backend scripts
export HOST_IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
export JOB_NAME=${2}
export JOB_ID=${3}
export BACKEND_NAME=${4}

echo "Functional tests for ${1}"

cd /ember-config

if [[ -f ./pre-run ]]; then
   echo "Pre run steps"
  ./pre-run
fi

echo "Sourcing backend configuration "
source ./config

X_CSI_SPEC_VERSION=${X_CSI_SPEC_VERSION:-"v1.1"}
X_CSI_PERSISTENCE_CONFIG='{"storage":"memory"}'
X_CSI_EMBER_CONFIG='{"project_id":"io.ember-csi","user_id":"io.ember-csi","root_helper":"sudo","disable_logs":false,"debug":true,"request_multipath":false,"state_path":"/tmp"}'

echo "Downloading ${1}"
docker pull ${1}

echo "Starting Ember-CSI container"
# Run the container in the background writing the output to file.
  ## -v /tmp/:/tmp/ \
  ## -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
echo -e "X_CSI_SYSTEM_FILES=$CSI_SYSTEM_FILES\nX_CSI_SPEC_VERSION=$X_CSI_SPEC_VERSION\nX_CSI_EMBER_CONFIG=$X_CSI_EMBER_CONFIG\nX_CSI_PERSISTENCE_CONFIG=$X_CSI_PERSISTENCE_CONFIG\nIMAGE=${1}" | tee /ember-ci/artifacts/docker-env-vars

if [[ -n $CSI_SYSTEM_FILES ]]; then
    system_files_destination="/tmp/`basename $CSI_SYSTEM_FILES`"
    extra_args="-v \"/ember-config/$CSI_SYSTEM_FILES:$system_files_destination:ro" -e \"X_CSI_SYSTEM_FILES=${system_files_destination}" "
fi

docker run --rm --name ember -t --privileged --net=host --ipc=host $extra_args -e X_CSI_SPEC_VERSION=$X_CSI_SPEC_VERSION -e CSI_MODE=all -e X_CSI_BACKEND_CONFIG=$DRIVER_CONFIG -e X_CSI_EMBER_CONFIG=$X_CSI_EMBER_CONFIG -e X_CSI_PERSISTENCE_CONFIG=$X_CSI_PERSISTENCE_CONFIG -v /etc/iscsi:/etc/iscsi -v /dev:/dev -v /etc/lvm:/etc/lvm -v /var/lock/lvm:/var/lock/lvm -v /etc/multipath:/etc/multipath -v /etc/multipath.conf:/etc/multipath.conf -v /lib/modules:/lib/modules:ro -v /etc/localtime:/etc/localtime:ro -v /run/udev:/run/udev:ro -v /run/lvm:/run/lvm:ro -v /var/lib/iscsi:/var/lib/iscsi ${1} > /ember-ci/artifacts/ember-csi.logs &

# Wait until ember is running with a 30 seconds timeout
test_result=1
set +e
for i in {1..30}; do
    if grep 'Now serving on' /ember-ci/artifacts/ember-csi.logs; then
        echo "Running csi-sanity test suite"
        # --ginkgo.failFast --test.parallel 1
        date
        /home/vagrant/csi-sanity/csi-sanity-${X_CSI_SPEC_VERSION} --test.v --csi.endpoint=127.0.0.1:50051 --test.timeout 0 --ginkgo.v --ginkgo.progress 2>&1 | tee /ember-ci/artifacts/ci-sanity.logs
        # We could also have also done before the csi-sanity call: "set -o pipefail" to propagate the pipe status
        test_result=${PIPESTATUS[0]}
        date
        break
    fi
    sleep 1
done

docker stop ember

if [[ -f ./post-run ]]; then
  echo "Post run steps"
  ./post-run $test_result
fi

exit $test_result
