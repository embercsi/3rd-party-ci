#!/bin/env bash
set -e

SCRIPT_DIR=$(dirname `realpath $0`)

if [[ -z "$1" ]]; then
    echo "Missing argument, backend name" > /dev/stderr
    exit 1
fi

USER_SCRIPTS_DIR=$(realpath $SCRIPT_DIR/../${1}-files)
echo  $USER_SCRIPTS_DIR
