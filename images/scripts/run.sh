#!/bin/bash
set -e

if [[ -z "$SCRIPTS_LOCATION" ]]; then
    echo "Scripts location must be set in SCRIPTS_LOCATION env var"
    return 1
fi

current_dir=`pwd`

cd $SCRIPTS_LOCATION

for f in `\ls -v *.sh`; do
    echo Running $f
    chmod +x "${f}"
    ./"${f}"
done

sudo yum clean all
sudo rm -rf /var/cache/yum

# TODO: Clean pip cache (ie: yum, pip)

cd $current_dir
