#!/bin/bash
set -e
echo "Downloading csi-sanity versions"

function do_links {
    chmod +x $1
    for link_name in $2; do
      ln -s $1 $link_name
    done
}

mkdir /home/vagrant/csi-sanity
cd /home/vagrant/csi-sanity

curl -LO https://github.com/embercsi/ember-csi/raw/master/tools/csi-sanity-v0.2.0
do_links csi-sanity-v0.2.0 "csi-sanity-v0.2"

curl -LO https://github.com/embercsi/ember-csi/raw/master/tools/csi-sanity-v0.3.5
do_links csi-sanity-v0.3.5 "csi-sanity-v0.3 csi-sanity-v0.3.0"

curl -LO https://github.com/embercsi/ember-csi/raw/master/tools/csi-sanity-v2.2.0
do_links csi-sanity-v2.2.0 "csi-sanity-v1 csi-sanity-v1.0 csi-sanity-v1.0.0 csi-sanity-v1.1 csi-sanity-v1.1.0"
