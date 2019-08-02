#!/bin/env bash
DRIVER_CONFIG='{"name":"ceph","driver":"RBD","rbd_user":"admin","rbd_pool":"rbd","rbd_ceph_conf":"/etc/ceph/ceph.conf","rbd_keyring_conf":"/etc/ceph/ceph.client.admin.keyring"}'

# Add the ceph config and credentials
tar cvf /tmp/files.tar /etc/ceph
CSI_SYSTEM_FILES='/tmp/files.tar'
