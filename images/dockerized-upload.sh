#!/bin/bash
docker run -it --rm -v `realpath ../`:/ember --workdir=/ember/images -e VAGRANT_LOG=error --entrypoint=./upload.sh -e VAGRANT_USERNAME="$VAGRANT_USERNAME" -e VAGRANT_TOKEN="$VAGRANT_TOKEN" embercsi/vagrant $1
