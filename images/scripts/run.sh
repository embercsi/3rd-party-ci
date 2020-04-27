#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )/scripts"

for f in `\ls -v *.sh`; do
    echo Running $f
    chmod +x "${f}"
    ./"${f}"
done

sudo yum clean all
sudo rm -rf /var/cache/yum

# TODO: Clean pip cache (ie: yum, pip)
