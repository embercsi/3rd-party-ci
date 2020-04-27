#!/bin/bash
set -e

vagrant cloud auth login --username "$VAGRANT_USERNAME" --token "$VAGRANT_TOKEN"

if [[ -z "$1" ]]; then
    version=`vagrant cloud box show ember-csi/ci-centos7-base | grep current_version | awk '{print $2}'`
    echo -e "Mising version number for the image. Current version is $version"
    exit -1
fi

short_description="Ember-CSI CI job box"
version_description=`git rev-parse HEAD`

for box in `\ls -v boxes/*.box`; do
    echo -e "\nUploading $box"
    filename=`basename "$box"`
    boxname="${filename%.*}"
    vagrant cloud publish ember-csi/$boxname $1 libvirt $box --short-description="$short_description" --version-description="$version_description" --force --release
done
