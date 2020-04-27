#!/bin/bash
set -e

echo "Checking newer VM image for $1"
if vagrant box update --box ${1} --force; then
    echo "Checking if we can remove older boxes"
    prunable="`vagrant box prune --dry-run --name $1 | grep 'Would remove' | cut -d ' ' -f 5`"
    if [[ -n "$prunable" ]]; then
        for version in "${prunable/\n/ }"; do
            echo "Removing version $version"
            vagrant box remove --force --box-version="${version}" "${1}"

            # Vagrant doesn't remove libvirt images, so we do it ourselves
            # we accept failure, since the image may not exist in libvirt if
            # we haven't run any VM with it yet.
            virsh_img_name="${1/'/'/-VAGRANTSLASH-}_vagrant_box_image_${version}.img"
            sudo virsh vol-delete --pool default $virsh_img_name || true
        done
    fi
else
    echo "WARNING: Failed to check for updated box!!"
fi
